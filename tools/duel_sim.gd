extends RefCounted
## --duel-sim: headless bot-vs-bot duels in the duel room for every pair of Hunters (12x12, mirrors
## included), both on the same mind (one difficulty, damage scale 1.0, no Boki, no gloves) at the level
## the ultimate opens. Each round is a fresh match from full health and ready cooldowns and ends at the
## first knock or the time cap. A mirror runs once per seed (its swapped side is the same round).
## Writes one JSON line per round to --duel-sim-out (default user://duel_sim.jsonl); the tables come
## from tools/duel_sim_report.py (docs/BALANCE_1111.md). Never touches the save.
##   --duel-sim-n=<rounds per side per pair>  --duel-sim-diff=<easy|medium|hard|expert>
##   --duel-sim-t=<s cap per round>  --duel-sim-only=<arch>[,<arch>] (pairs that include one of them)

const CAP_S := 60.0              # s: a round with no knock by then is a draw
const SEED0 := 7100              # first seed; round i of a pair uses SEED0 + i
const SKIP := ["gil"]            # not in the 12-Hunter launch roster (DECISIONS, owner Nov 4)

var _out: FileAccess
var _hits: Array = []            # this round's hits: [side, bucket, damage]
var _m: Match

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var n := 4
	var diff := "hard"
	var cap := CAP_S
	var only: Array = []
	var path := "user://duel_sim.jsonl"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--duel-sim-n="): n = int(a.substr(13))
		if a.begins_with("--duel-sim-diff="): diff = a.substr(16)
		if a.begins_with("--duel-sim-t="): cap = float(a.substr(13))
		if a.begins_with("--duel-sim-only="): only = Array(a.substr(16).split(","))
		if a.begins_with("--duel-sim-out="): path = a.substr(15)
	_out = FileAccess.open(path, FileAccess.WRITE)
	var ids := Arch.ids().filter(func(x): return not x in SKIP)
	var rounds := 0
	for i in ids.size():
		for j in range(i, ids.size()):
			var a := String(ids[i])
			var b := String(ids[j])
			if not only.is_empty() and not (a in only or b in only):
				continue
			for r in n:
				_round(main, a, b, SEED0 + r, diff, cap)
				rounds += 1
				if a != b:
					_round(main, b, a, SEED0 + r, diff, cap)
					rounds += 1
		print("DUELSIM %s done (%d rounds so far)" % [ids[i], rounds])
	_out.close()
	print("DUELSIM done: %d rounds -> %s" % [rounds, ProjectSettings.globalize_path(path)])
	main.get_tree().quit(0)

## One round: `a` stands on the player's mark, `b` on the bot's; both are bots on the same mind.
func _round(main: Node, a: String, b: String, sd: int, diff: String, cap: float) -> void:
	seed(hash([a, b, sd]))          # (kit bots roll the global randf: a round replays exactly)
	var o := Match.duel_opts()
	o.merge({"autoplay": true, "seed": sd, "arch": a, "cls": Arch.weight(a)}, true)
	var m := Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	m.duel.arch = b
	m.duel.diff = diff
	m.duel.spawn_bot()
	var mind := (Data.BOT_DIFF[diff] as Dictionary).duplicate()
	mind["dmg"] = 1.0         # raw kit numbers (the duel bot's own scale would only hit one side)
	var fighters: Array = [m.player, m.duel.bot]
	for h in fighters:
		h.ai = m.bot_brain.new_mind(m.rng, float(mind["skill"]), mind)
		h.gain_xp(float(Hunter.XP_TO[Hunter.ULT_AT[0] - 1]))      # (both grow the same; the bot spends its points)
		_drop_kin(m, h)
		h.gear = Gear.empty_slots()
		h.refresh_gear()
	_drop_rack(m)
	_m = m
	_hits.clear()
	var cb_hit := func(by, t, d, tags): _on_hit(fighters, by, t, float(d), tags)
	CombatBus.hit_landed.connect(cb_hit)
	var burn := [0.0, 0.0]          # burn ticks take health directly (Ent), outside CombatBus: summed here
	while m.time < cap and not (m.player.downed or m.duel.bot.downed):
		for side in 2:
			var f: Hunter = fighters[1 - side]
			if f.burn_t > 0.0 and f.burn_by == fighters[side]:
				burn[side] += f.burn_dps * minf(Match.DT, f.burn_t)
		m.step(Match.DT)
	CombatBus.hit_landed.disconnect(cb_hit)
	for side in 2:
		if burn[side] > 0.0: _hits.append([side, "burn", snappedf(burn[side], 0.1), snappedf(m.time, 0.01)])
	var win := -1
	if m.duel.bot.downed and not m.player.downed: win = 0
	elif m.player.downed and not m.duel.bot.downed: win = 1
	var row := {"a": a, "b": b, "seed": sd, "diff": diff, "win": win, "t": snappedf(m.time, 0.01),
		"hp": [snappedf(m.player.hp, 0.1), snappedf(m.duel.bot.hp, 0.1)], "hits": _hits.duplicate()}
	_out.store_line(JSON.stringify(row))
	m.duel.teardown()
	m.queue_free()
	await_free(main)

## Frees the round's match before the next one starts (one match in the tree at a time).
func await_free(main: Node) -> void:
	for c in main.get_children():
		if c is Match and c.is_queued_for_deletion():
			main.remove_child(c)
			c.free()

## The duel room hands both fighters a Boki; a kit duel leaves it out.
func _drop_kin(m: Match, h: Hunter) -> void:
	if h.kin == null:
		return
	m.kins.erase(h.kin)
	m.bubbles = m.bubbles.filter(func(bb): return bb["ent"] != h.kin)
	h.kin.queue_free()
	h.kin = null

## The room's glove rack: bots would pick gloves up mid-duel (a kit duel has none).
func _drop_rack(m: Match) -> void:
	for p in m.wpicks.filter(func(w): return String(w.get("gear", "")) != ""):
		(p["node"] as Node).queue_free()
		m.wpicks.erase(p)

## A hit by one fighter on the other: its tags joined (the report maps them to slots).
func _on_hit(fighters: Array, by, t, d: float, tags: Array) -> void:
	var side := fighters.find(by)
	if side < 0 or t != fighters[1 - side] or d <= 0.0:
		return
	var key := "+".join(tags.map(func(x): return String(x)))
	_hits.append([side, key, snappedf(d, 0.1), snappedf(_m.time, 0.01)])
