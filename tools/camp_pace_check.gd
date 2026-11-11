extends RefCounted
## --camp-pace-check: the level pace of bot squads that play camps (scripts/match/bot_camps.gd,
## docs/decisions/0048-camps-and-xp.md). Ten bot trios on the 2x map over five seeds, one of them
## scripted never to fight (it deals no damage), run to 5:15 of match time. Prints one table (squad,
## its camp ring, level at 1:30, 2:30, 4:00, 5:15, XP by source) and asserts the pace: squads average
## level 3.5 to 4.5 at 2:30; no Hunter is level 6 before 2:30 in at least 4 of 5 seeds; the median
## squad still alive is level 5.5 or more at 5:15; the top squad is at most 2 levels over the median
## at 4:00; at least 60% of the XP earned by 2:30 is camp clears; the squad that never fights is level 2
## or less at 5:15; no two bot squads ping one region (bar the surplus when squads outnumber regions).
## A squad's level is the mean of its members' levels. --pace-seeds=5,11 runs only those seeds (the
## seed-count line then reads against five). Never touches the save.

const SEEDS := [5, 11, 23, 42, 77]
const TEAMS := 10
const MARKS := [90.0, 150.0, 240.0, 315.0]
const EARLY_S := 150.0

var bad := 0
var _src := {"camp": 0.0, "knock": 0.0, "other": 0.0}      # XP earned by 2:30, by source (all seeds)

func ok(cond: bool, what: String) -> void:
	print("PACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var lv := {"150": [], "240": [], "315": [], "gap": [], "pace_ok": 0, "six": 0, "never": [], "pings": []}
	print("PACE seed team ring    L1:30 L2:30 L4:00 L5:15  XP camp knock other (whole run)")
	var seeds: Array = SEEDS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pace-seeds="):
			seeds = Array(a.substr(13).split(",")).map(func(x): return int(x))
	for s in seeds:
		await _seed(main, int(s), lv)
	_verdict(lv)
	print("PACE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## The mean level of a squad's members, the ones who are out too (they keep what they earned).
func _squad_level(m: Match, team: int) -> float:
	var sum := 0.0
	var n := 0
	for h in m.hunters:
		if h.team == team:
			sum += h.lvl
			n += 1
	return sum / n if n > 0 else 0.0

func _squad_in(m: Match, team: int) -> bool:
	return m.hunters.any(func(h): return h.team == team and not h.out)

func _levels(m: Match, teams: Array, still_in: bool) -> Array:
	var in_teams := teams.filter(func(t): return not still_in or _squad_in(m, int(t)))
	return in_teams.map(func(t): return _squad_level(m, int(t)))

func _median(a: Array) -> float:
	var s := a.duplicate()
	s.sort()
	return float(s[s.size() / 2]) if not s.is_empty() else 0.0

func _camp_deaths(m: Match) -> int:
	var n := 0
	for c in m.camps.camps:
		for mb in c["mobs"]:
			if is_instance_valid(mb) and mb.dead:
				n += 1
	return n

## One match to 5:15. Returns its squad rows into lv.
func _seed(main: Node, seed_v: int, lv: Dictionary) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": TEAMS, "squad": 3, "tier": 0, "seed": seed_v, "autoplay": true, "sim_keep": true})
	m.set_process(false)
	var teams: Array = []
	for h in m.hunters:
		if not teams.has(h.team):
			teams.append(h.team)
	var idle: int = teams[-1]
	var active: Array = teams.filter(func(t): return t != idle)
	var rows := {}
	for t in teams:
		rows[t] = {"lvl": [], "camp": 0.0, "knock": 0.0, "other": 0.0, "region": -1}
	var last_xp := {}
	var last_dead := 0
	var last_down := 0
	var marks: Array = MARKS.duplicate()
	var steps := 0
	var pinged := false
	var six_early := false
	while m.time < float(MARKS[-1]) and not m.over:
		m.step(Match.DT)
		steps += 1
		if steps % 120 == 0:
			await main.get_tree().process_frame
		if not pinged and m.skydrop != null and not m.skydrop.planning:
			pinged = true
			_note_pings(m, lv, rows)
			for h in m.hunters.filter(func(x): return x.team == idle):
				h.ctrl = "idle"
				m.kins.erase(h.kin)
				m.kins.erase(h.kin2)
		var dead_camp := -1
		var downs := -1
		for h in m.hunters:
			if h.team == idle:
				h.hp = h.max_hp
			var gain: float = h.xp - float(last_xp.get(h, 0.0))
			last_xp[h] = h.xp
			if gain <= 0.0:
				continue
			if dead_camp < 0:
				dead_camp = _camp_deaths(m)
				downs = m.hunters.filter(func(x): return x.downed or x.out).size()
			var src := "other"
			if dead_camp > last_dead:
				src = "camp"
			elif downs > last_down:
				src = "knock"
			rows[h.team][src] += gain
			if m.time < EARLY_S:
				_src[src] += gain
		if dead_camp >= 0:
			last_dead = dead_camp
			last_down = downs
		if m.time < EARLY_S and not six_early:
			six_early = m.hunters.any(func(h): return h.lvl >= 6)
		if not marks.is_empty() and m.time >= float(marks[0]):
			var at: float = marks.pop_front()
			for t in teams:
				var tag := "" if _squad_in(m, int(t)) else "x"
				rows[t]["lvl"].append("%.1f%s" % [_squad_level(m, int(t)), tag])
			_note_mark(m, lv, at, active)
	_print_rows(seed_v, m, teams, rows)
	lv["six"] += 0 if six_early else 1
	var idle_max := 0
	for h in m.hunters:
		if h.team == idle:
			idle_max = maxi(idle_max, h.lvl)
	lv["never"].append(idle_max)
	m.free()

func _note_mark(m: Match, lv: Dictionary, at: float, active: Array) -> void:
	var levels := _levels(m, active, at != 150.0)
	if at == 150.0:
		lv["150"].append_array(levels)
	elif at == 240.0 and not levels.is_empty():
		lv["gap"].append(float(levels.max()) - _median(levels))
	elif at == 315.0:
		lv["315"].append_array(levels)

## Which region each squad's leader pinged, as the planning phase ends.
func _note_pings(m: Match, lv: Dictionary, rows: Dictionary) -> void:
	var by_region := {}
	for p in m.pings:
		var by = p.get("by")
		if by is Hunter and by.ctrl == "bot" and m.skydrop.is_lead(by):
			var region := m.biomes.hot.region_at(p["pos"])
			by_region[region] = by_region.get(region, []) + [by.team]
			rows[by.team]["region"] = region
	var regions := {}
	for c in m.camps.camps:
		if c["region"] >= 0:
			regions[c["region"]] = true
	var shared := 0
	var crown := 0
	for region in by_region:
		shared += (by_region[region] as Array).size() - 1
		if BotCamps.ring(m, region) == "crown":
			crown += (by_region[region] as Array).size()
	lv["pings"].append({"squads": by_region.values().reduce(func(a, b): return a + b.size(), 0), "shared": shared,
		"regions": regions.size(), "crown": crown})

func _print_rows(seed_v: int, m: Match, teams: Array, rows: Dictionary) -> void:
	for t in teams:
		var r: Dictionary = rows[t]
		var ring := BotCamps.ring(m, int(r["region"])) if int(r["region"]) >= 0 else "-"
		var lvls: Array = (r["lvl"] as Array).map(func(l): return "%5s" % l)
		var xp := [int(r["camp"]), int(r["knock"]), int(r["other"])]
		print("PACE %4d %4d %-7s %s  %5d %5d %5d" % [seed_v, t, ring, "  ".join(lvls), xp[0], xp[1], xp[2]])

func _verdict(lv: Dictionary) -> void:
	var l150: Array = lv["150"]
	var mean := 0.0
	for l in l150:
		mean += l
	mean /= maxf(1.0, l150.size())
	ok(mean >= 3.5 and mean <= 4.5, "bot squads average level %.2f at 2:30 (3.5 to 4.5)" % mean)
	ok(int(lv["six"]) >= 4, "no Hunter is level 6 before 2:30 in %d of 5 seeds (4 needed)" % int(lv["six"]))
	var med := _median(lv["315"])
	ok(med >= 5.5, "the median squad still alive is level %.1f at 5:15 (5.5 or more)" % med)
	var worst_gap := 0.0
	for g in lv["gap"]:
		worst_gap = maxf(worst_gap, g)
	ok(worst_gap <= 2.0, "at 4:00 the top squad is %.1f over the median at worst (2 allowed)" % worst_gap)
	var all := float(_src["camp"]) + float(_src["knock"]) + float(_src["other"])
	var share := float(_src["camp"]) / maxf(1.0, all)
	ok(share >= 0.6, "camp clears are %d%% of the XP earned by 2:30 (60%% needed)" % int(share * 100.0))
	var never_ok: bool = (lv["never"] as Array).all(func(l): return l <= 2)
	var top_idle := int((lv["never"] as Array).max())
	ok(never_ok, "the squad that never fights is level %d at 5:15 at most (2 allowed)" % top_idle)
	var doubled := 0
	var crowns_ok := true
	var extra := 0
	for p in lv["pings"]:
		doubled += int(p["shared"]) - maxi(0, int(p["squads"]) - int(p["regions"]))
		crowns_ok = crowns_ok and int(p["crown"]) <= 1
		extra += maxi(0, int(p["squads"]) - int(p["regions"]))
	var shared_what := "(%d forced, %d more), one Crown" % [extra, doubled]
	ok(doubled <= 0 and crowns_ok, "no region shared while one is free " + shared_what)
