extends RefCounted
## --bot-watch [--watch-t=<s>] [--seed=<n>] [--bot-diff=<d>]: a full expedition (10 squads of 3, every
## hunter a bot) run headless, watching what the bots do the way a good player would judge them. Prints a
## line for every hunter that goes down (how long it fought on under 30% health, whether it backed off,
## what it still had on its belt, how far its squad was) and a summary: belt use in and out of fights,
## squad focus fire, spread, and how many got out. Evidence for docs/BOTS_HUMAN_1111.md; asserts nothing.
## Never touches the save.

const LOW := 0.3                 # health fraction a good player stops trading at
const SAMPLE := 0.5              # s between focus and spread samples
const FIGHT_ITEMS := ["tonic", "medkit", "smoke", "shield_cell", "stim"]

var seen := {}                   # hunter -> its record

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var secs := 720.0
	var o := {"teams": 10, "squad": 3, "autoplay": true, "seed": 11, "bot_diff": "medium"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--watch-t="): secs = float(arg.substr(10))
		if arg.begins_with("--seed="): o["seed"] = int(arg.substr(7))
		if arg.begins_with("--bot-diff="): o["bot_diff"] = arg.substr(11)
	var m := Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	for h in m.hunters:
		seen[h] = {"low_fight": 0.0, "low_back": 0.0, "last_low": -99.0, "belt": _belt(h), "was_down": false}
	var tot := {"downs": 0, "low_downs": 0, "unused_downs": 0, "alone_downs": 0, "use_fight": 0, "use_calm": 0,
		"focus_same": 0, "focus_n": 0, "spread": 0.0, "spread_n": 0}
	var since := 0.0
	print("BOTWATCH seed %d diff %s" % [m.seed_val, m.bot_diff])
	while not m.over and m.time < secs:
		m.step(Match.DT)
		since += Match.DT
		for h in m.hunters:
			_watch(m, h, tot)
		if since >= SAMPLE:
			since = 0.0
			_squads(m, tot)
	var got := m.hunters.filter(func(x): return x.extracted).size()
	var left := m.hunters.filter(func(x): return not x.out and not x.extracted).size()
	print("BOTWATCH summary t=%d downs=%d fought_low=%d (%.0f%%) unused_belt=%d alone=%d" % [m.time, tot["downs"],
		tot["low_downs"], 100.0 * tot["low_downs"] / maxf(1, tot["downs"]), tot["unused_downs"], tot["alone_downs"]])
	print(("BOTWATCH belt uses in fights=%d calm=%d | focus same target %.0f%% of %d | squad spread %.1f m"
		+ " | out=%d extracted=%d still in=%d") % [
		tot["use_fight"], tot["use_calm"], 100.0 * tot["focus_same"] / maxf(1, tot["focus_n"]), tot["focus_n"],
		tot["spread"] / maxf(1, tot["spread_n"]), m.hunters.filter(func(x): return x.out).size(), got, left])
	main.get_tree().quit(0)

func _watch(m: Match, h: Hunter, tot: Dictionary) -> void:
	var r: Dictionary = seen[h]
	if h.out or h.extracted or h.riding or h.dropping:
		return
	var tgt = h.ai.get("tgt")
	var fighting: bool = tgt is Hunter and is_instance_valid(tgt) and not (tgt as Hunter).downed
	if not h.downed and fighting and h.hp < h.max_hp * LOW:
		r["low_fight"] = float(r["low_fight"]) + Match.DT
		r["last_low"] = m.time
		var mv: Vector2 = h.inp.get("move", Vector2.ZERO)
		if mv.dot(h.dir_to(tgt)) < -0.3:
			r["low_back"] = float(r["low_back"]) + Match.DT
	var now := _belt(h)
	for id in now:
		var used := int((r["belt"] as Dictionary).get(id, 0)) - int(now[id])
		if used > 0:
			tot["use_fight" if fighting else "use_calm"] += used
	r["belt"] = now
	if h.downed and not r["was_down"]:
		_down(m, h, r, tot)
	r["was_down"] = h.downed
	if not h.downed and m.time - float(r["last_low"]) > 10.0:
		r["low_fight"] = 0.0
		r["low_back"] = 0.0

func _down(m: Match, h: Hunter, r: Dictionary, tot: Dictionary) -> void:
	tot["downs"] += 1
	var lf := float(r["low_fight"])
	if lf > 1.5: tot["low_downs"] += 1
	var unused := []
	for id in FIGHT_ITEMS:
		if int((r["belt"] as Dictionary).get(id, 0)) > 0:
			unused.append("%s x%d" % [id, r["belt"][id]])
	if not unused.is_empty() and lf > 1.5: tot["unused_downs"] += 1
	var mate := 1e9
	for o in m.hunters:
		if o != h and o.team == h.team and not o.out and not o.downed:
			mate = minf(mate, h.flat_dist(o))
	if mate > 25.0: tot["alone_downs"] += 1
	var by = h.last_hit_by
	var who := (by as Hunter).pname if by is Hunter and is_instance_valid(by) else "a monster/Blight"
	var near := "%dm" % mate if mate < 1e8 else "none"
	print(("[t=%5.1f] DOWN %s (squad %d) fought under %d%% for %.1fs, backing off %.0f%%"
		+ " | unused: %s | nearest mate %s | by %s") % [
		m.time, h.pname, h.team, int(LOW * 100), lf, 100.0 * float(r["low_back"]) / maxf(0.01, lf),
		", ".join(unused) if not unused.is_empty() else "-", near, who])
	r["low_fight"] = 0.0
	r["low_back"] = 0.0

## Squad samples: do squadmates in a fight shoot the same rival, and how spread out is a squad.
func _squads(m: Match, tot: Dictionary) -> void:
	var by_team := {}
	for h in m.hunters:
		if h.out or h.extracted or h.downed or h.riding or h.dropping:
			continue
		if not by_team.has(h.team): by_team[h.team] = []
		by_team[h.team].append(h)
	for t in by_team:
		var hs: Array = by_team[t]
		var tg := hs.map(func(x): return x.ai.get("tgt")).filter(func(x): return x is Hunter)
		if tg.size() >= 2:
			tot["focus_n"] += 1
			if tg.all(func(x): return x == tg[0]): tot["focus_same"] += 1
		if hs.size() >= 2:
			var c := Vector3.ZERO
			for h in hs: c += h.pos
			c /= float(hs.size())
			var far := 0.0
			for h in hs: far = maxf(far, h.flat_dist(c))
			tot["spread"] += far
			tot["spread_n"] += 1

func _belt(h: Hunter) -> Dictionary:
	var d := {}
	for s in h.belt:
		if not (s as Dictionary).is_empty():
			d[String(s["id"])] = int(s["n"])
	return d
