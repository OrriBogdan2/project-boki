extends RefCounted
## --camp-pace-check: bot squads level at the spec's pace (docs/EARLY_CAMPS_DROP sections 2.5, 6.2,
## 6.8; scripts/match/bot_camps.gd). Seeded headless matches of 10 bot trios on the 2x map, to 12:00,
## print one table (squad, its ring, level at each mark, XP by source from XpRules' tally) and assert:
##   - every XP point is in the tally (nothing from time or damage)
##   - no two bot squads pinged one region, at most one took the Crown
##   - bot squads average level 3.5 to 4.5 at 2:30, and nobody is level 6 before 2:30 in 80% of seeds
##   - at least 85% of the XP earned by 2:30 is from camp monsters
##   - the median squad still in is level 5.5 or more at 5:15 and 7 or more at 8:00 (mean over seeds)
##   - the top squad is at most 2 levels over the median at 4:00 and 3 at 8:00, in 80% of seeds
##   - squadmates are within 1 level of each other at 4:00 in 80% of squads
## --pace-seeds=3,5,9 runs only those seeds (default 1 to 20). Never touches the save.

const SEEDS := 20
const END_S := 720.0
const MARKS: Array[float] = [120.0, 150.0, 240.0, 315.0, 480.0, 600.0]
const AT_230 := 1        # index of 2:30 in MARKS
const AT_400 := 2
const AT_515 := 3
const AT_800 := 4
const SHARE := 0.8       # seeds (or squads) a per-seed assert must hold in

var bad := 0
var lines: Array[String] = []

func ok(cond: bool, what: String) -> void:
	print("PACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var seeds: Array = range(1, SEEDS + 1)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pace-seeds="): seeds = Array(a.substr(13).split(",")).map(func(x): return int(x))
	var runs: Array = []
	for sd in seeds:
		runs.append(await _match(main, sd))
	for l in lines: print(l)
	_judge(runs)
	print("PACE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## One seeded match: {regions: bot squads' regions, crowns: how many were the Crown, lv: {team: {nid:
## level at each mark}}, alive: {team: squad still in at each mark}, camp150 and all150: camp and all
## XP by 2:30, untallied: the widest gap between a Hunter's XP and its tally, l6_early}.
func _match(main: Node, sd: int) -> Dictionary:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 10, "squad": 3, "tier": 0, "seed": sd, "autoplay": true})
	m.set_process(false)
	var r := {"seed": sd, "regions": [], "crowns": 0, "lv": {}, "alive": {}, "camp150": 0.0, "all150": 0.0,
		"l6_early": false}
	var planned := false
	var mark := 0
	var t0 := Time.get_ticks_msec()
	while m.time < END_S and not m.over:
		m.step(Match.DT)
		if not planned and m.skydrop and not m.skydrop.planning:
			planned = true
			for t in m.skydrop.leads:
				var l: Hunter = m.skydrop.leader(int(t))
				if l and l.ctrl == "bot" and l.ai.has(BotCamps.REGION):
					r["regions"].append(int(l.ai[BotCamps.REGION]))
			r["crowns"] = r["regions"].filter(func(g): return BotCamps.ring(m, g) == "crown").size()
		if m.time < MARKS[AT_230] and m.hunters.any(func(h): return h.lvl >= 6):
			r["l6_early"] = true
		while mark < MARKS.size() and m.time >= MARKS[mark]:
			_mark(m, r, mark)
			mark += 1
	for h in m.hunters:
		# (at the cap the tally keeps counting what gain_xp no longer adds)
		var gap := h.xp - XpRules.xp_total(h) if h.lvl >= Hunter.XP_TO.size() else absf(h.xp - XpRules.xp_total(h))
		r["untallied"] = maxf(float(r.get("untallied", 0.0)), gap)
	_table(m, r)
	print("PACE seed %d: %.0f s of match in %.0f s" % [sd, m.time, (Time.get_ticks_msec() - t0) / 1000.0])
	m.queue_free()
	await main.get_tree().process_frame
	return r

func _mark(m: Match, r: Dictionary, i: int) -> void:
	for h in m.hunters:
		(r["lv"].get_or_add(h.team, {}) as Dictionary).get_or_add(h.nid, []).append(h.lvl)
		if not (r["alive"] as Dictionary).has(h.team): r["alive"][h.team] = []
	for t in r["alive"]:
		r["alive"][t].append(m.hunters.any(func(h): return h.team == t and not h.out and not h.extracted))
	if i == AT_230:
		for h in m.hunters:
			r["camp150"] += float(XpRules.tally(h).get("camp", {}).get("xp", 0.0))
			r["all150"] += XpRules.xp_total(h)

func _table(m: Match, r: Dictionary) -> void:
	lines.append("PACE seed %d  squad ring    2:00 2:30 4:00 5:15 8:00 10:00   camp/mob/boss/knock XP" % r["seed"])
	for t in r["lv"]:
		var cols: Array[String] = []
		for i in MARKS.size():
			cols.append("%4.1f" % _squad_lv(r, t, i))
		var src: Array[String] = []
		for s in XpRules.SOURCES:
			var x := 0.0
			for h in m.hunters:
				if h.team == t: x += float(XpRules.tally(h).get(s, {}).get("xp", 0.0))
			src.append("%d" % x)
		var lead: Hunter = m.skydrop.leader(int(t)) if m.skydrop else null
		var reg: int = int(lead.ai.get(BotCamps.REGION, -1)) if lead else -1
		var ring := BotCamps.ring(m, reg) if reg >= 0 else "-"
		lines.append("PACE   %5d %-6s  %s   %s" % [t, ring, " ".join(cols), "/".join(src)])

## A squad's mean level at mark i.
func _squad_lv(r: Dictionary, t: int, i: int) -> float:
	var s := 0.0
	var per: Dictionary = r["lv"][t]
	for nid in per:
		s += float(per[nid][i])
	return s / maxf(1.0, per.size())

func _spread(r: Dictionary, t: int, i: int) -> int:
	var lv: Array = (r["lv"][t] as Dictionary).values().map(func(a): return int(a[i]))
	return lv.max() - lv.min()

## The median and top mean level of the squads still in at mark i.
func _median_top(r: Dictionary, i: int) -> Array:
	var lv: Array = []
	for t in r["lv"]:
		if r["alive"][t][i]: lv.append(_squad_lv(r, t, i))
	if lv.is_empty():
		return [0.0, 0.0]
	lv.sort()
	var mid: float = lv[lv.size() / 2] if lv.size() % 2 == 1 else (lv[lv.size() / 2 - 1] + lv[lv.size() / 2]) / 2.0
	return [mid, lv.back()]

func _judge(runs: Array) -> void:
	var n := float(runs.size())
	var worst_tally := 0.0
	var dup := 0
	var crown := 0
	var sum230 := 0.0
	var squads := 0
	var calm := 0
	var camp := 0.0
	var all := 0.0
	var med515 := 0.0
	var med800 := 0.0
	var top_ok := 0
	var tight := 0
	for r in runs:
		worst_tally = maxf(worst_tally, float(r["untallied"]))
		var regs: Array = r["regions"]
		for reg in regs:
			if regs.count(reg) > 1: dup += 1
		crown = maxi(crown, int(r["crowns"]))
		calm += 0 if r["l6_early"] else 1
		camp += float(r["camp150"])
		all += float(r["all150"])
		for t in r["lv"]:
			sum230 += _squad_lv(r, t, AT_230)
			squads += 1
			tight += 1 if _spread(r, t, AT_400) <= 1 else 0
		var m4 := _median_top(r, AT_400)
		var m8 := _median_top(r, AT_800)
		med515 += float(_median_top(r, AT_515)[0])
		med800 += float(m8[0])
		top_ok += 1 if m4[1] - m4[0] <= 2.0 and m8[1] - m8[0] <= 3.0 else 0
		print("PACE seed %d: median/top %.1f/%.1f at 4:00, %.1f/%.1f at 8:00; regions %s" % [r["seed"], m4[0], m4[1],
			m8[0], m8[1], str(regs)])
	var avg230 := sum230 / maxf(1.0, squads)
	ok(worst_tally < 0.5, "every XP point is in XpRules' tally (worst gap %.1f)" % worst_tally)
	ok(dup == 0, "no two bot squads pinged one region (%d doubled)" % dup)
	ok(crown <= 1, "at most one bot squad a match took the Crown (%d)" % crown)
	ok(avg230 >= 3.5 and avg230 <= 4.5, "bot squads average level %.2f at 2:30 (3.5 to 4.5)" % avg230)
	ok(calm >= SHARE * n, "nobody is level 6 before 2:30 in %d of %d seeds" % [calm, n])
	var share := 100.0 * camp / maxf(1.0, all)
	ok(all > 0.0 and share >= 85.0, "%.0f%% of the XP by 2:30 is camp monsters (85%%)" % share)
	ok(med515 / n >= 5.5, "the median squad still in is level %.2f at 5:15 (5.5)" % (med515 / n))
	ok(med800 / n >= 7.0, "the median squad still in is level %.2f at 8:00 (7)" % (med800 / n))
	ok(top_ok >= SHARE * n, "the top squad is within 2 of the median at 4:00 and 3 at 8:00 in %d of %d seeds"
		% [top_ok, n])
	ok(tight >= SHARE * squads, "squadmates within 1 level at 4:00 in %d of %d squads" % [tight, squads])
