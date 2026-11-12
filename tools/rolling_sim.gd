extends RefCounted
## --rolling-sim: a whole 30-minute rolling session, headless, with bots (scripts/match/rolling.gd).
## Your hunter (on autopilot) drops with the first wave; the session runs on to 30:00 whatever
## happens to you. Prints a line a minute (who's out there, levels, bounties, the Blight), then each
## wave (when, how many, how many got out, died, or were still out at the end), extractions and deaths
## by minute, levels and XP rates, and what it cost to run. Options: --seed=N, --squad=N,
## --join-wave=N (start later; the earlier waves are then simulated), --sim-minutes=N (stop early).
## Fails (exit 1) if a wave doesn't launch on time, anyone drops in after the cut-off, or anyone is
## still out there after 30:00. (Main holds this object in a meta: it awaits frames, see the loop.)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ROLLSIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node, opts: Dictionary) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var o := {"rolling": true, "join_wave": int(opts.get("join_wave", 0)), "squad": int(opts.get("squad", 3)), "tier": int(opts.get("tier", 0)),
		"seed": int(opts.get("seed", 5)), "autoplay": true, "plan_t": 0.5, "sim_keep": true}
	var stop_min := 1e9
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sim-minutes="): stop_min = float(a.substr(14))
	var m := Match.new()
	main.add_child(m)
	var tb := Time.get_ticks_msec()
	m.start(o)
	m.set_process(false)
	var R: Rolling = m.rolling
	print("ROLLSIM seed %d squad %d raid %s, built in %d ms: %d waves at %s; you join wave %d (%s); map %d tiles, %d islands" % [m.seed_val, R.size, m.raid, Time.get_ticks_msec() - tb,
		R.waves.size(), str(R.waves.map(func(w): return Rolling.fmt(float(w["t"])))), R.join_i, Rolling.fmt(R.t0), m.world.w, m.world.islands.size()])
	for h in m.hunters:
		h.set_meta("lvl_join", h.lvl)
	var t_wall := Time.get_ticks_msec()
	var next_log := floorf(m.sess_time() / 60.0) * 60.0 + 60.0
	var launched_at := {}
	var pops: Array = []
	var minute_ms: Array = []
	var last_ms := Time.get_ticks_msec()
	var max_hunters_alive := 0
	var gaps := {}          # wave -> minute since landing (0, 2, 4 ...) -> [level - median] (the catch-up curve)
	var n_step := 0
	while m.time < m.length + 1.0 and m.sess_time() < stop_min * 60.0:
		m.step(Match.DT)
		n_step += 1
		if n_step % 120 == 0:
			# let a frame go by now and then: nodes freed with queue_free (effects, drops, the dead)
			# only really go between frames, and a whole session without one runs out of memory
			await main.get_tree().process_frame
		for w in R.waves:
			if int(w["i"]) > R.join_i and String(w["state"]) != "planned" and not launched_at.has(int(w["i"])):
				launched_at[int(w["i"])] = m.sess_time()
		for h in m.hunters:
			if not h.has_meta("left_sess") and (h.extracted or h.out):
				h.set_meta("left_sess", m.sess_time())
				h.set_meta("left_how", "extracted" if h.extracted else "out")
		if m.sess_time() >= next_log:
			next_log += 60.0
			var on := 0; var air := 0; var lv: Array = []
			for h in m.hunters:
				if h.out or h.extracted: continue
				if h.riding or h.dropping: air += 1
				else:
					on += 1; lv.append(h.lvl)
			pops.append(on + air)
			for h in m.hunters:
				if h.out or h.extracted or h.riding or h.dropping or not h.has_meta("land_sess"): continue
				var k := int((m.sess_time() - float(h.get_meta("land_sess"))) / 60.0)
				if k > 10 or k % 2 == 1: continue
				var wi := int(h.get_meta("wave", R.join_i))
				if not gaps.has(wi): gaps[wi] = {}
				if not (gaps[wi] as Dictionary).has(k): gaps[wi][k] = []
				(gaps[wi][k] as Array).append(float(h.lvl) - R.median)
			max_hunters_alive = maxi(max_hunters_alive, on + air)
			lv.sort()
			var bn := m.hunters.filter(func(h): return h.has_meta("bounty") and not h.out and not h.extracted).size()
			var now := Time.get_ticks_msec()
			minute_ms.append(now - last_ms)
			last_ms = now
			print("  %s  out there %2d (+%d in the air)  levels %s  median %.1f  bounties %d  extracted %d  out %d  mobs %d  blight %d  (%d ms)" % [Rolling.fmt(m.sess_time()), on, air,
				("%d-%d" % [lv[0], lv[-1]]) if not lv.is_empty() else "-", R.median, bn, m.hunters.filter(func(h): return h.extracted).size(),
				m.hunters.filter(func(h): return h.out and not h.extracted).size(), m.mobs.filter(func(x): return not x.dead).size(),
				m.blight.alive().size() if m.blight else 0, minute_ms[-1]])
	var wall := Time.get_ticks_msec() - t_wall
	var full := m.sess_time() >= Rolling.SESSION - 1.0
	# ---- per wave
	print("ROLLSIM waves:")
	var on_time := true
	for w in R.waves:
		var hs: Array = m.hunters.filter(func(h): return int(h.get_meta("wave", R.join_i)) == int(w["i"]) and not (h.has_meta("landed_t") and float(h.get_meta("landed_t")) < 0.0))
		var ex := hs.filter(func(h): return h.extracted).size()
		var dd := hs.filter(func(h): return h.out and not h.extracted and float(h.get_meta("left_sess", Rolling.SESSION)) < Rolling.SESSION - 2.0).size()
		var lost := hs.filter(func(h): return h.out and not h.extracted and h.has_meta("left_sess") and float(h.get_meta("left_sess")) >= Rolling.SESSION - 2.0).size()
		var la := float(launched_at.get(int(w["i"]), float(w["t"])))
		var late := la - float(w["t"])
		if int(w["i"]) > R.join_i and (late < -0.01 or late > 0.1) and launched_at.has(int(w["i"])): on_time = false
		var stay := 0.0; var ns := 0
		for h in hs:
			if h.has_meta("left_sess") and h.has_meta("land_sess"):
				stay += float(h.get_meta("left_sess")) - float(h.get_meta("land_sess")); ns += 1
		print("  wave %2d at %s%s: %d squads, %2d hunters, %2d landed, %2d extracted, %2d died, %2d lost at 30:00, mean stay %s" % [int(w["i"]), Rolling.fmt(float(w["t"])),
			(" (launched +%.2fs)" % late) if launched_at.has(int(w["i"])) else (" (you)" if int(w["i"]) == R.join_i else " (before you)"), int(w["n"]), hs.size(),
			hs.filter(func(h): return h.has_meta("land_sess")).size(), ex, dd, lost, Rolling.fmt(stay / maxf(1.0, ns))])
	# ---- by minute
	var ext_by := {}; var out_by := {}
	for h in m.hunters:
		if not h.has_meta("left_sess"): continue
		var mi := int(float(h.get_meta("left_sess")) / 60.0)
		if h.extracted: ext_by[mi] = int(ext_by.get(mi, 0)) + 1
		else: out_by[mi] = int(out_by.get(mi, 0)) + 1
	var mins := range(0, 31)
	print("ROLLSIM extracts by minute: %s" % " ".join(mins.map(func(i): return str(ext_by.get(i, 0)))))
	print("ROLLSIM deaths by minute:   %s" % " ".join(mins.map(func(i): return str(out_by.get(i, 0)))))
	var why := {}
	for h in m.hunters:
		if h.out and not h.extracted and h.has_meta("left_sess"):
			var k := String(h.get_meta("died_why", "?"))
			why[k] = int(why.get(k, 0)) + 1
	print("ROLLSIM how they went out: %s" % str(why))
	# ---- levels and XP
	var xp_rates: Array = []
	var land_lv: Dictionary = {}
	for h in m.hunters:
		if h.has_meta("land_sess") and h.has_meta("xp_land"):
			var t1 := float(h.get_meta("left_sess", m.sess_time()))
			var mins_on := (t1 - float(h.get_meta("land_sess"))) / 60.0
			if mins_on > 2.0 and h.ctrl == "bot":
				xp_rates.append((h.xp - float(h.get_meta("xp_land"))) / mins_on)
			var bucket := int(float(h.get_meta("land_sess")) / 240.0)
			if not land_lv.has(bucket): land_lv[bucket] = []
			(land_lv[bucket] as Array).append(int(h.get_meta("lvl_land", 1)))
	xp_rates.sort()
	var med_xp := float(xp_rates[xp_rates.size() / 2]) if not xp_rates.is_empty() else 0.0
	print("ROLLSIM bot XP per minute on the map: median %.0f (n=%d; Rolling.XP_PER_MIN for earlier arrivals is %.0f)" % [med_xp, xp_rates.size(), Rolling.XP_PER_MIN])
	print("ROLLSIM landing level by 4-minute block: %s" % str(land_lv.keys().map(func(k): return "%s: %s" % [Rolling.fmt(k * 240.0), str((land_lv[k] as Array).reduce(func(a, b): return maxi(a, b), 0))])))
	print("ROLLSIM catch-up curve (mean level minus lobby median, by minutes since landing 0/2/4/6/8/10):")
	var late_gap: Array = []
	var wkeys: Array = gaps.keys(); wkeys.sort()
	for wi in wkeys:
		var row: Array = []
		for k in [0, 2, 4, 6, 8, 10]:
			var a: Array = (gaps[wi] as Dictionary).get(k, [])
			row.append(("%+.1f" % (a.reduce(func(x, y): return x + y, 0.0) / a.size())) if not a.is_empty() else "  - ")
			if not a.is_empty() and k == 6 and float(R.waves[wi]["t"]) >= 600.0:
				late_gap.append(a.reduce(func(x, y): return x + y, 0.0) / a.size())
		print("  wave %2d (%s): %s" % [wi, Rolling.fmt(float(R.waves[wi]["t"])), "  ".join(row)])
	# joined part-way: your wave against the squads that were already out there
	var pre: Array = m.hunters.filter(func(h): return h.has_meta("landed_t") and float(h.get_meta("landed_t")) < 0.0)
	if not pre.is_empty():
		print("ROLLSIM earlier arrivals: %d, levels at your join %s" % [pre.size(), str(pre.map(func(h): return int(h.get_meta("lvl_join", h.lvl))))])
	if not late_gap.is_empty():
		print("ROLLSIM waves from 10:00 on, 6 min after landing: mean gap to the median %+.2f levels" % (late_gap.reduce(func(x, y): return x + y, 0.0) / late_gap.size()))
	var S: Dictionary = R.stats
	print("ROLLSIM totals: %d hunters over the session (%d before you joined), %d landed, %d extracted, %d out; on the map at once %s (max %d)" % [S["joined"] + int(S["prepop"]), int(S["prepop"]), int(S["landed"]),
		m.hunters.filter(func(h): return h.extracted).size(), m.hunters.filter(func(h): return h.out and not h.extracted).size(),
		_band(pops), max_hunters_alive])
	print("ROLLSIM bounties posted %d, claimed %d; catch-up XP %.0f of %.0f (%.1f%%); level-gap knock XP %.0f; camps back %d; meteor showers %d" % [int(S["bounties_posted"]), int(S["bounties_claimed"]),
		float(S["catchup_xp"]), float(S["xp_all"]), 100.0 * float(S["catchup_xp"]) / maxf(1.0, float(S["xp_all"])), float(S["gap_knock_xp"]), int(S["camp_respawns"]), int(S["meteors"])])
	if m.blight:
		print("ROLLSIM the Blight: spawned %d, knocks %d, outs %d" % [m.blight.spawned, int(m.kstat.get("bl_knock", 0)), int(m.kstat.get("bl_out", 0))])
	var you: Hunter = m.player
	print("ROLLSIM you: %s at %s, level %d, %d knocks, %d gems" % [String(you.get_meta("left_how", "still out")), Rolling.fmt(float(you.get_meta("left_sess", m.sess_time()))), you.lvl, you.knocks, you.gems])
	minute_ms.sort()
	print("ROLLSIM cost: %d s of session in %d s (%.2fx real time); a minute of session took %d-%d ms (median %d)" % [int(m.sess_time() - R.t0), wall / 1000, (m.sess_time() - R.t0) / maxf(0.001, wall / 1000.0),
		minute_ms[0] if not minute_ms.is_empty() else 0, minute_ms[-1] if not minute_ms.is_empty() else 0, minute_ms[minute_ms.size() / 2] if not minute_ms.is_empty() else 0])
	for e in R.events:
		print("   | %s %s" % [Rolling.fmt(float(e[0])), e[1]])
	# ---- what must hold
	ok(on_time, "every wave set off on schedule")
	var late_join := m.hunters.filter(func(h): return h.has_meta("land_sess") and float(h.get_meta("land_sess")) > Rolling.SESSION - Rolling.CUTOFF + 60.0)
	ok(late_join.is_empty(), "nobody dropped in during the last %d minutes" % int(Rolling.CUTOFF / 60.0))
	if full:
		ok(launched_at.size() == R.waves.size() - 1 - R.join_i, "all %d waves after yours launched" % (R.waves.size() - 1 - R.join_i))
		ok(m.hunters.all(func(h): return h.out or h.extracted), "at 30:00 nobody is still out there")
	print("ROLLSIM DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _band(a: Array) -> String:
	if a.is_empty():
		return "-"
	var s: Array = a.duplicate(); s.sort()
	var tail: Array = s.slice(int(s.size() * 0.2))     # (past the opening few minutes)
	return "%d-%d (median %d)" % [int(tail[0]), int(s[-1]), int(s[s.size() / 2])]
