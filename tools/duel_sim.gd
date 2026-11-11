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
	o["autoplay"] = true
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	CombatBus.hit_landed.connect(_on_hit)
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE) if out_path != "" else null
	var rows: Array = []
	var t_wall := Time.get_ticks_msec()
	var steps := 0
	for a in roster:
		for b in roster:
			for i in n:
				var r := _fight(String(a), String(b), diff, hash([a, b, i]))
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

## One fight: the player (on autopilot) as a, the sparring bot as b, both at the same difficulty.
func _fight(a: String, b: String, diff: String, sd: int) -> Dictionary:
	seed(sd)
	m.rng.seed = sd
	var P := m.player
	P.lvl = 1      # (knocks gave the last fight's winner XP: levels add health, power and ranks)
	P.xp = 0.0
	P.remove_meta("growth_lvl")
	P.reclass(Arch.weight(a), a)
	m.duel.arch = b
	m.duel.diff = diff
	m.duel.spawn_bot()        # a fresh bot, and both back to their marks at full health
	var B := m.duel.bot
	var mind: Dictionary = Data.BOT_DIFF[diff].duplicate()
	mind["dmg"] = 1.0         # (the game scales only a bot's damage, never the player's: the kits at face value)
	for h in [P, B]:
		_drop_boki(h)
		for s in Hunter.SLOTS: h.slot_lv[s] = 1
		h.skill_pts = 0
		h.ai = m.bot_brain.new_mind(m.rng, float(mind["skill"]), mind)
		h.hp = h.max_hp
		h.armor = h.max_armor
		prev_cd[h] = _cds(h)
	if OS.has_environment("SWAPT"): P.teleport(m.duel.bot_at); B.teleport(m.duel.home_at)
	fight = {P: {}, B: {}, "cast": {P: "other", B: "other"}}
	var t := 0.0
	var steps := 0
	while t < FIGHT_S and not P.downed and not B.downed:
		m.step(DT)
		t += DT
		steps += 1
		for h in [P, B]:
			_watch_casts(h)
	var win := "a" if B.downed else ("b" if P.downed else "draw")
	return {"a": a, "b": b, "seed": sd, "win": win, "t": snappedf(t, 0.01), "steps": steps,
		"hp": [P.max_hp + P.max_armor, B.max_hp + B.max_armor], "dmg_a": fight[P], "dmg_b": fight[B]}

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
	var wins := {}; var games := {}; var ttk := {}; var share := {}; var cell := {}; var draws := 0
	for a in roster:
		wins[a] = 0.0; games[a] = 0; ttk[a] = []; share[a] = {}
	for r in rows:
		var a := String(r["a"]); var b := String(r["b"])
		var key := "%s|%s" % [a, b]
		cell[key] = float(cell.get(key, 0.0)) + (1.0 if r["win"] == "a" else (0.5 if r["win"] == "draw" else 0.0))
		if r["win"] == "draw": draws += 1
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
	print("DUELSIM %d fights, %s bots, %d per pairing, %d draws" % [rows.size(), diff, n, draws])
	var head := "DUELSIM row-vs-col   "
	for b in roster: head += " %5s" % String(b).substr(0, 5)
	print(head)
	for a in roster:
		var line := "DUELSIM %-12s" % a
		for b in roster:
			line += " %5.2f" % (float(cell.get("%s|%s" % [a, b], 0.0)) / n)
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
