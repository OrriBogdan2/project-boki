extends RefCounted
## --level-pace-sim: one headless expedition, 30 hunters by default (squads of 3, every hunter a bot,
## yours on autopilot; the match runs on after yours is done) to measure how fast run levels come
## (docs/LEVEL_PACE.md). For levels 2, 4, 6 and the max it prints the median match second it was
## first reached (over those who got there, and over everyone: "never" if under half did), then
## where the XP came from: each step's gain is split into the trickle, knocks, and the rest
## (damage and lair bosses).
## Options: --seed=N, --hunters=N. Report only; it never fails.

const MARKS := [2, 4, 6]

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var sd := 5
	var n := 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): sd = int(a.substr(7))
		if a.begins_with("--hunters="): n = int(a.substr(10))
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": ceili(n / 3.0), "squad": 3, "total": n, "tier": 1, "seed": sd,
		"autoplay": true, "plan_t": 0.5, "sim_keep": true})
	m.set_process(false)
	printerr("LEVELPACE seed %d: match built, %d hunters" % [sd, m.hunters.size()])
	var top := Hunter.XP_TO.size()
	var marks: Array = MARKS + [top]
	var reached := {}          # hunter -> {level: match seconds}
	var last := {}             # hunter -> [xp, knocks] at the previous step
	var src := {"trickle": 0.0, "knocks": 0.0, "damage and bosses": 0.0}
	var n_step := 0
	var next_log := 60.0
	var t_wall := Time.get_ticks_msec()
	while not m.over and m.time < m.length + 1.0 and m.hunters.any(func(h): return not (h.out or h.extracted)):
		m.step(Match.DT)
		n_step += 1
		if n_step % 120 == 0:
			await main.get_tree().process_frame      # lets queue_free'd nodes go (see rolling_sim)
		if m.time >= next_log:
			next_log += 60.0
			var lv: Array = m.hunters.map(func(h): return h.lvl)
			lv.sort()
			var wall_s := (Time.get_ticks_msec() - t_wall) / 1000
			printerr("LEVELPACE %3.0f s: median level %d (%d s wall)" % [m.time, lv[lv.size() / 2], wall_s])
		for h in m.hunters:
			var r: Dictionary = reached.get(h, {})
			for l in marks:
				if h.lvl >= l and not r.has(l): r[l] = m.time
			reached[h] = r
			var was: Array = last.get(h, [0.0, 0])
			var d: float = h.xp - float(was[0])
			if d > 0.0:
				var tr := Match.DT * LevelGrowth.xp("trickle_per_s") if not (h.downed or h.dropping or h.out) else 0.0
				var kn := float(h.knocks - int(was[1])) * LevelGrowth.xp("knock")
				src["trickle"] += minf(tr, d)
				src["knocks"] += minf(kn, d - minf(tr, d))
				src["damage and bosses"] += maxf(0.0, d - tr - kn)
			last[h] = [h.xp, h.knocks]
	var nh := m.hunters.size()
	print("LEVELPACE seed %d: %d hunters, match %.0f s, ended at %.0f s" % [sd, nh, m.length, m.time])
	for l in marks:
		var ts: Array = []
		for h in m.hunters:
			if (reached[h] as Dictionary).has(l): ts.append(float(reached[h][l]))
		ts.sort()
		var med := "%.0f s" % float(ts[ts.size() / 2]) if not ts.is_empty() else "-"
		var all_med := "%.0f s" % float(ts[nh / 2]) if ts.size() > nh / 2 else "never"
		print("LEVELPACE level %2d: median %s (of %d/%d who got there), over everyone %s" % [
			l, med, ts.size(), nh, all_med])
	var xp: float = m.hunters.reduce(func(a, h): return a + h.xp, 0.0)
	var parts: Array = src.keys().map(func(k): return "%s %.0f" % [k, float(src[k]) / nh])
	print("LEVELPACE XP per hunter %.0f: %s" % [xp / nh, ", ".join(parts)])
	main.get_tree().quit(0)
