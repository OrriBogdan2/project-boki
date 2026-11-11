extends RefCounted
## --duel-sim: headless bot-vs-bot duels for balance (docs/BALANCE_1111.md). Every pairing of the 12
## launch Hunters (both sides, mirrors too) fights `--sim-n=N` times in the Duel room, both bots on the
## same difficulty (`--sim-diff=`, default hard), each fight with fresh kits (rank 1 everywhere, full
## health, no Boki) and its own seed. A fight ends on the first knock or after FIGHT_S (a draw).
## Prints the win-rate matrix, each Hunter's win rate, time to kill and damage share by ability, and
## writes one JSON line per fight to `--sim-out=<file>` when given. `--sim-arch=a,b` limits the roster.
## Damage by ability: hits tagged primary/shot/melee are LMB, ult/ultimate tags R, dash/dodge tags the
## dash; any other hit goes to the slot whose cooldown last started (rmb, e, r, x), else "other".
## Fails (exit 1) if a Hunter never lands damage or more than a third of all fights time out.

const DT := 1.0 / 60.0
const FIGHT_S := 60.0          # s: a fight with no knock by then is a draw
const LAUNCH := 12             # the launch roster: the first 12 of Arch.ORDER (Gil is newer)
const LMB_TAGS := ["primary", "shot", "melee"]
const ULT_TAGS := ["ult", "ultimate"]
const DASH_TAGS := ["dash", "dodge"]

var bad := 0
var m: Match
var fight := {}                # the running fight: side -> {dmg by slot}, the last cast slot per side
var prev_cd := {}              # hunter -> {slot: cd, "ch": rmb charges} last step

func ok(cond: bool, what: String) -> void:
	print("DUELSIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	var n := 4
	var diff := "hard"
	var out_path := ""
	var roster: Array = Arch.ids().slice(0, LAUNCH)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sim-n="): n = int(a.substr(8))
		if a.begins_with("--sim-diff="): diff = a.substr(11)
		if a.begins_with("--sim-out="): out_path = a.substr(10)
		if a.begins_with("--sim-arch="): roster = Array(a.substr(11).split(","))
	Save.no_write = true
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["classes"] = ClassUnlock.legacy()
	Save.d = d
	var o := Match.duel_opts()
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	m.truce = null       # (two bot squads may agree a truce and stop fighting: a human has to accept one)
	CombatBus.hit_landed.connect(_on_hit)
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE) if out_path != "" else null
	var rows: Array = []
	var t_wall := Time.get_ticks_msec()
	var steps := 0
	for a in roster:
		for b in roster:
			for i in n:
				var r := _fight(String(a), String(b), diff, hash([a, b, i]), i % 2 == 1)
				steps += int(r["steps"])
				rows.append(r)
				if f: f.store_line(JSON.stringify(r))
				if steps > 6000:
					steps = 0
					await main.get_tree().process_frame      # freed nodes only go between frames
	if f: f.close()
	CombatBus.hit_landed.disconnect(_on_hit)
	_report(rows, roster, diff, n)
	print("DUELSIM %d fights in %d s" % [rows.size(), (Time.get_ticks_msec() - t_wall) / 1000])
	main.get_tree().quit(1 if bad > 0 else 0)

## One fight: a fresh bot as a (made here) against the Duel room's sparring bot as b (also fresh), both
## made the same way and at the same difficulty. The player sits out (an idle local hunter, set out
## of the match): reusing it as a fighter kept its facing, armour tier and statuses between fights.
func _fight(a: String, b: String, diff: String, sd: int, swap: bool) -> Dictionary:
	seed(sd)
	m.rng.seed = sd
	m.duel.arch = b
	m.duel.diff = diff
	m.duel.spawn_bot()
	var B := m.duel.bot
	var A := m.make_hunter(m.next_id("sim"), 2, Arch.weight(a), "Sim %s" % a, "bot", m.bot_kin_record(), m.duel.home_at,
		{"arch": a, "weapon": Arch.signature(a), "perk": ""}, {})
	m.player.out = true
	m.player.teleport(m.duel.home_at + Vector3(0, -50, 0))
	var mind: Dictionary = Data.BOT_DIFF[diff].duplicate()
	mind["dmg"] = 1.0         # (the game scales only a bot's damage, never the player's: the kits at face value)
	for h in [A, B]:
		_drop_boki(h)
		h.unlock_all()
		h.belt = UtilityBelt.empty()      # no tonics or armour kits on either side
		h.refresh_gear()
		h.ai = m.bot_brain.new_mind(m.rng, float(mind["skill"]), mind)
		h.hp = h.max_hp
		h.armor = h.max_armor
		h.inv_t = 0.6
		prev_cd[h] = _cds(h)
	A.teleport(m.duel.bot_at if swap else m.duel.home_at)
	B.teleport(m.duel.home_at if swap else m.duel.bot_at)
	for pair in [[A, B], [B, A]]:
		var h: Hunter = pair[0]
		var to: Vector3 = pair[1].pos
		h.face = atan2(-(to.x - h.pos.x), -(to.z - h.pos.z))     # both start facing each other
		h.inp["aim"] = to
	fight = {A: {}, B: {}, "cast": {A: "other", B: "other"}}
	var t := 0.0
	var steps := 0
	while t < FIGHT_S and not A.downed and not B.downed:
		m.step(DT)
		t += DT
		steps += 1
		for h in [A, B]:
			h.reveal_t = maxf(h.reveal_t, 0.3)      # (as the Duel room does: both always know where the other is)
			_watch_casts(h)
	var win := "a" if B.downed else ("b" if A.downed else "draw")
	var row := {"a": a, "b": b, "seed": sd, "swap": swap, "win": win, "t": snappedf(t, 0.01), "steps": steps,
		"hp": [A.max_hp, B.max_hp], "dmg_a": fight[A], "dmg_b": fight[B]}
	m.hunters.erase(A)
	prev_cd.erase(A)
	A.queue_free()
	return row

## Kits only: the Boki goes (its random species, level and owner bonuses would tilt the pairing).
func _drop_boki(h: Hunter) -> void:
	if h.kin:
		m.kins.erase(h.kin)
		h.kin.queue_free()
		h.kin = null
	h.apply_kin_bonus()

func _cds(h: Hunter) -> Dictionary:
	var c: Dictionary = h.ak.cd.duplicate() if h.ak else {}
	c["ch"] = h.ak.ch_rmb if h.ak else 0.0
	return c

## A slot whose cooldown jumped up (or an RMB charge spent) this step was just cast.
func _watch_casts(h: Hunter) -> void:
	var now := _cds(h)
	var was: Dictionary = prev_cd[h]
	for s in now:
		if s == "ch":
			if float(now[s]) < float(was.get(s, 0.0)) - 0.5: fight["cast"][h] = "rmb"
		elif float(now[s]) > float(was.get(s, 0.0)) + 0.2:
			fight["cast"][h] = s
	prev_cd[h] = now

func _on_hit(by, target, amount: float, tags: Array) -> void:
	if fight.is_empty():
		return
	if not fight.has(by) or not fight.has(target) or by == target:
		return
	var slot := _slot(by, tags)
	var dm: Dictionary = fight[by]
	dm[slot] = snappedf(float(dm.get(slot, 0.0)) + amount, 0.1)

func _slot(h: Hunter, tags: Array) -> String:
	for t in tags:
		if t in LMB_TAGS: return "lmb"
		if t in ULT_TAGS: return "r"
		if t in DASH_TAGS: return "dash"
	return String(fight["cast"][h])

# ---- the report
func _report(rows: Array, roster: Array, diff: String, n: int) -> void:
	var wins := {}; var games := {}; var ttk := {}; var share := {}; var cell := {}; var draws := 0; var a_won := 0
	for a in roster:
		wins[a] = 0.0; games[a] = 0; ttk[a] = []; share[a] = {}
	for r in rows:
		var a := String(r["a"]); var b := String(r["b"])
		var key := "%s|%s" % [a, b]
		cell[key] = float(cell.get(key, 0.0)) + (1.0 if r["win"] == "a" else (0.5 if r["win"] == "draw" else 0.0))
		if r["win"] == "draw": draws += 1
		if r["win"] == "a": a_won += 1
		for side in [[a, "a", r["dmg_a"]], [b, "b", r["dmg_b"]]]:
			var h := String(side[0])
			games[h] = int(games[h]) + 1
			if r["win"] == side[1]:
				wins[h] = float(wins[h]) + 1.0
				ttk[h].append(float(r["t"]))
			elif r["win"] == "draw":
				wins[h] = float(wins[h]) + 0.5
			for s in side[2]:
				share[h][s] = float(share[h].get(s, 0.0)) + float(side[2][s])
	print("DUELSIM %d fights, %s bots, %d per pairing, %d draws; side bias: the player's side won %d%% of decided fights" % [rows.size(), diff, n, draws,
		roundi(100.0 * a_won / maxi(rows.size() - draws, 1))])
	# row beats column, both ways round (a|b and b|a): the side bias cancels
	var head := "DUELSIM row-vs-col   "
	for b in roster: head += " %5s" % String(b).substr(0, 5)
	print(head)
	for a in roster:
		var line := "DUELSIM %-12s" % a
		for b in roster:
			line += " %5.2f" % ((float(cell.get("%s|%s" % [a, b], 0.0)) + n - float(cell.get("%s|%s" % [b, a], 0.0))) / (2.0 * n))
		print(line)
	for a in roster:
		var tot := 0.0
		for s in share[a]: tot += float(share[a][s])
		var parts: Array = []
		for s in share[a]:
			parts.append("%s %d%%" % [s, roundi(100.0 * float(share[a][s]) / maxf(tot, 1.0))])
		var tk: Array = ttk[a]
		tk.sort()
		var med: float = tk[tk.size() / 2] if not tk.is_empty() else -1.0
		print("DUELSIM %-12s win %.2f  ttk median %.1f s  dmg %s" % [a, float(wins[a]) / maxi(int(games[a]), 1), med, ", ".join(parts)])
		ok(tot > 0.0, "%s lands damage" % a)
	ok(draws * 3 <= rows.size(), "at most a third of fights time out (%d of %d)" % [draws, rows.size()])
