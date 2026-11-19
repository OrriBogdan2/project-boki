extends RefCounted
## --camp-pace-check: how fast bot squads level on the early camps (EARLY_CAMPS_DROP 6, bot_camps.gd).
## Five seeded headless matches on the 2x map, 10 bot trios, no god mode. One table per seed: each squad's
## mean level at 1:30, 2:30, 4:00 and 5:15 (- once it is out) and the XP its Hunters earned by 2:30 and by 5:15
## per source (camp clears / knocks / other: strays and lairs). Squad 9 of every match never fights (its Hunters
## stand where they land), the pace a squad that skips the camps would have. Asserts: bot squads average level
## 3.5-4.5 at 2:30; no Hunter is level 6 by 2:30 in at least 4 of 5 seeds; the median squad still alive is level
## 5.5+ at 5:15; the best squad is at most 2 levels over the median at 4:00; camp clears are 60%+ of the XP by
## 2:30; the idle squad is level 2 or less at 5:15; no two bot squads ping one region while a free one the
## ship's run lets a squad reach is left.
## Options: --seed=N (one seed only), --feed (also print the match feed). Never touches the save.
## (Main holds this object in a meta: it awaits frames.)

const SEEDS := [11, 12, 13, 14, 15]
const MARKS := [90.0, 150.0, 240.0, 315.0]
const IDLE_TEAM := 9
const SPAN := 5.0          # seconds past the last mark the match runs on
const FRAME_EVERY := 120   # steps between frames (freed nodes only go between frames)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CAMPPACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var seeds: Array = SEEDS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): seeds = [int(a.substr(7))]
	var runs: Array = []
	for sd in seeds:
		runs.append(await _play(main, int(sd)))
	_judge(runs)
	print("CAMPPACE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## One match: {seed, lv: {mark: {team: mean level}}, alive: {mark: [teams]}, top150: highest Hunter level at 2:30,
## xp: {mark: {source: xp}}, shared: regions pinged by two bot squads, free: camp regions nobody pinged}.
func _play(main: Node, sd: int) -> Dictionary:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 10, "squad": 3, "tier": 0, "seed": sd, "autoplay": true, "plan_t": 0.5, "length": 1e9,
		"sim_keep": true})
	m.set_process(false)
	var out := {"seed": sd, "lv": {}, "alive": {}, "top150": 0, "xp": {}, "shared": 0, "free": 0, "landed": -1.0}
	var src := {"camp": 0.0, "knock": 0.0, "other": 0.0}
	var last_xp := {}
	var last_alive := m.camps.alive()
	var last_knocks := 0
	var marks := MARKS.duplicate()
	var n := 0
	var t0 := Time.get_ticks_msec()
	while not marks.is_empty() and not m.over:
		_idle(m)
		m.step(Match.DT)
		n += 1
		if n % FRAME_EVERY == 0: await main.get_tree().process_frame
		if n % 600 == 0: print("CAMPPACE   ... seed %d t=%.0f s, %d ms" % [sd, m.time, Time.get_ticks_msec() - t0])
		if out["landed"] < 0.0 and m.hunters.all(func(h): return not h.riding and not h.dropping):
			out["landed"] = m.time
			_regions(m, out)
		var camp_now: int = m.camps.alive()
		var knocks := 0
		for h in m.hunters: knocks += h.knocks
		for h in m.hunters:
			var d: float = h.xp - float(last_xp.get(h, h.xp))
			last_xp[h] = h.xp
			if d <= 0.0: continue
			var kind := "other"
			if camp_now < last_alive: kind = "camp"
			elif knocks > last_knocks: kind = "knock"
			src[kind] += d
		last_alive = camp_now
		last_knocks = knocks
		if m.time >= float(marks[0]):
			var t: float = marks.pop_front()
			out["lv"][t] = _levels(m)
			out["alive"][t] = _alive(m)
			out["xp"][t] = src.duplicate()
			if t == 150.0:
				for h in m.hunters: out["top150"] = maxi(out["top150"], h.lvl)
	_table(out)
	if "--feed" in OS.get_cmdline_user_args():
		for line in m.feed_all: print("CAMPPACE   feed ", line)
	m.queue_free()
	await main.get_tree().process_frame
	return out

## The idle squad stands still once on the ground.
func _idle(m: Match) -> void:
	for h in m.hunters:
		if h.team == IDLE_TEAM and not h.riding and not h.dropping:
			h.ctrl = "idle"       # (no bot tick: it just stands)
			h.inp["move"] = Vector2.ZERO
			h.inp["fire"] = false

func _levels(m: Match) -> Dictionary:
	var sum := {}
	var cnt := {}
	for h in m.hunters:
		sum[h.team] = sum.get(h.team, 0) + h.lvl
		cnt[h.team] = cnt.get(h.team, 0) + 1
	var out := {}
	for t in sum: out[t] = float(sum[t]) / float(cnt[t])
	return out

func _alive(m: Match) -> Array:
	var out := {}
	for h in m.hunters:
		if not h.out and not h.extracted: out[h.team] = true
	return out.keys()

## The regions the bot squads pinged: two squads in one while a region they could reach was left over.
func _regions(m: Match, out: Dictionary) -> void:
	var per := {}
	for t in m.skydrop.picks:
		per[m.skydrop.picks[t]] = per.get(m.skydrop.picks[t], 0) + 1
	var camp_regions := {}
	for c in m.camps.list():
		if BotCamps.reachable(m, m.hunters[0], c["pos"]): camp_regions[c["region"]] = true
	out["free"] = camp_regions.keys().filter(func(r): return not per.has(r)).size()
	for r in per:
		if per[r] > 1: out["shared"] += per[r] - 1

func _table(o: Dictionary) -> void:
	print("CAMPPACE seed %d, landed at %.0f s; regions without a squad %d, squads doubling up %d" % [
		o["seed"], o["landed"], o["free"], o["shared"]])
	print("CAMPPACE  squad   1:30   2:30   4:00   5:15")
	for t in range(10):
		var cells := ""
		for mk in MARKS:
			var alive: bool = (o["alive"][mk] as Array).has(t)
			cells += "  %4.1f%s" % [o["lv"][mk].get(t, 0.0), " " if alive else "-"]
		print("CAMPPACE  %s%d%s" % ["idle " if t == IDLE_TEAM else "     ", t, cells])
	for mk in [150.0, 315.0]:
		var s: Dictionary = o["xp"][mk]
		print("CAMPPACE  XP by %d:%02d  camp %d  knock %d  other %d" % [
			int(mk) / 60, int(mk) % 60, s["camp"], s["knock"], s["other"]])

func _median(a: Array) -> float:
	a.sort()
	if a.is_empty(): return 0.0
	var k: int = a.size() / 2
	return float(a[k]) if a.size() % 2 == 1 else (float(a[k - 1]) + float(a[k])) * 0.5

func _judge(runs: Array) -> void:
	var n := runs.size()
	var all150: Array = []
	var med315: Array = []
	var gap_ok := 0
	var six_ok := 0
	var camp_xp := 0.0
	var all_xp := 0.0
	var idle_ok := true
	var no_share := true
	for o in runs:
		var bots: Array = []
		for t in o["lv"][150.0]:
			if t != IDLE_TEAM: all150.append(o["lv"][150.0][t])
		for t in o["lv"][315.0]:
			if t != IDLE_TEAM and (o["alive"][315.0] as Array).has(t): bots.append(o["lv"][315.0][t])
		med315.append(_median(bots))
		var l240: Array = []
		for t in o["lv"][240.0]:
			if t != IDLE_TEAM: l240.append(o["lv"][240.0][t])
		var med240 := _median(l240.duplicate())
		l240.sort()
		if l240.back() - med240 <= 2.0: gap_ok += 1
		if o["top150"] < 6: six_ok += 1
		camp_xp += o["xp"][150.0]["camp"]
		all_xp += o["xp"][150.0]["camp"] + o["xp"][150.0]["knock"] + o["xp"][150.0]["other"]
		if o["lv"][315.0].get(IDLE_TEAM, 0.0) > 2.0: idle_ok = false
		if o["shared"] > 0 and o["free"] > 0: no_share = false
	var mean150 := 0.0
	for v in all150: mean150 += float(v)
	mean150 /= maxf(1.0, all150.size())
	var med := 0.0
	for v in med315: med += float(v)
	med /= maxf(1.0, med315.size())
	var need := ceili(n * 0.8)
	ok(mean150 >= 3.5 and mean150 <= 4.5, "bot squads average level %.2f at 2:30 (3.5-4.5)" % mean150)
	ok(six_ok >= need, "no Hunter level 6 by 2:30 in %d of %d seeds (%d needed)" % [six_ok, n, need])
	ok(med >= 5.5, "the median squad still alive is level %.2f at 5:15 (5.5+)" % med)
	ok(gap_ok >= need, "the best squad is within 2 levels of the median at 4:00 in %d of %d seeds" % [gap_ok, n])
	ok(all_xp > 0.0 and camp_xp / all_xp >= 0.6, "camp clears are %.0f%% of the XP by 2:30 (60%%+)" % (
		100.0 * camp_xp / maxf(1.0, all_xp)))
	ok(idle_ok, "the squad that never fights is level 2 or less at 5:15")
	ok(no_share, "no two bot squads ping one region while a camp region is free")
