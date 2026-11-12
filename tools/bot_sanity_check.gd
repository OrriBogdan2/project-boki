extends RefCounted
## --bot-sanity-check, moved out of main.gd (AGENTS.md section 2); registered in tools/check_registry.gd.

var main: Node

## Bots shouldn't look broken: over a few seeded matches, every bot is watched for spinning (its
## facing swinging back and forth), jump and dash spam, and hanging in the air (which shows its hit ring
## under it: blue on an ally). Any 5 s window over the limits is flagged, with what the bot was doing.
func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var seeds := [3, 5, 9]
	var dur := 150.0
	var verbose := "--sanity-verbose" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sanity-seeds="): seeds = Array(a.substr(15).split(",")).map(func(x): return int(x))
		if a.begins_with("--sanity-t="): dur = float(a.substr(11))
	const WIN := 5.0
	const MAX_TURN := 9.0 * PI      # facing travel in a window (a full fight's strafing is ~3 pi)
	const MAX_FLIPS := 14           # big reversals of facing in a window
	const MAX_JUMPS := 6
	const MAX_DASHES := 6
	const MAX_RING := 0.6           # share of a window spent in the air over land, ring showing
	var bad := 0
	var worst := {}
	for sd in seeds:
		var m := Match.new()
		main.add_child(m)
		m.start({"teams": 3, "squad": 3, "tier": 0, "seed": sd, "autoplay": true})
		m.set_process(false)
		var st := {}
		for h in m.hunters:
			st[h.nid] = {"face": h.face, "dface": 0.0, "turn": 0.0, "flips": 0, "jumps": 0, "dashes": 0, "ring": 0.0, "t": 0.0, "vy": 0.0, "roll": 0.0, "air": 0.0}
		var flagged := 0
		var watch := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--sanity-watch="): watch = a.substr(15)
		while m.time < dur and not m.over:
			m.step(Match.DT)
			if watch != "":
				var wn := watch.split("@")
				var w0 := float(wn[1]) if wn.size() > 1 else 0.0
				if m.time > w0 and m.time < w0 + 6.0 and int(m.time * 60.0) % 6 == 0:
					for h in m.hunters:
						if h.pname == wn[0]:
							var c: Dictionary = h.ai.get("cross", {})
							print("WATCH t=%.2f pos=%s vel=%s face=%.2f aim=%s move=%s gr=%s goal=%s kind=%s cross=%s go=%s wp=%s stuck=%.2f detour=%.2f" % [m.time, str(h.pos.snapped(Vector3(0.01,0.01,0.01))), str(h.vel.snapped(Vector3(0.1,0.1,0.1))), h.face, str((h.inp["aim"] as Vector3).snapped(Vector3(0.1,0.1,0.1))), str(h.inp["move"]), h.grounded, str(h.ai.get("goal")), str(h.ai.get("goal_kind")), ("%d>%d take %s land %s" % [c["from"], c["to"], str(c["take"]), str(c["land"])]) if not c.is_empty() else "-", str(h.ai.get("cross_go")), str((h.ai.get("wp", {}) as Dictionary).get("path", []).slice(0, 2)), float(h.ai.get("stuck", 0)), float(h.ai.get("detour_t", 0.0))])
			for h in m.hunters:
				if h.out or h.extracted or h.riding or h.dropping or h.downed:
					continue
				var s: Dictionary = st[h.nid]
				var df := wrapf(h.face - float(s["face"]), -PI, PI)
				s["turn"] = float(s["turn"]) + absf(df)
				if absf(df) > 0.08 and signf(df) != signf(float(s["dface"])) and absf(float(s["dface"])) > 0.08:
					s["flips"] = int(s["flips"]) + 1
				if absf(df) > 0.02: s["dface"] = df
				s["face"] = h.face
				if h.vel.y - float(s["vy"]) > 6.0 and h.pad.is_empty() and h.vel.y > 5.0:
					s["jumps"] = int(s["jumps"]) + 1
				s["vy"] = h.vel.y
				if h.roll_t > float(s["roll"]) + 0.05:
					s["dashes"] = int(s["dashes"]) + 1
				s["roll"] = h.roll_t
				# (a ledge rise is a climb up a wall, not hanging in the air: it doesn't count)
				if h.hit_marker() == "ring" and not h.gliding and h.lfloat.is_empty():
					s["ring"] = float(s["ring"]) + Match.DT
				s["t"] = float(s["t"]) + Match.DT
				if float(s["t"]) >= WIN:
					var why: Array = []
					if float(s["turn"]) > MAX_TURN: why.append("spin %.0f rad" % float(s["turn"]))
					if int(s["flips"]) > MAX_FLIPS: why.append("%d facing flips" % int(s["flips"]))
					if int(s["jumps"]) > MAX_JUMPS: why.append("%d jumps" % int(s["jumps"]))
					if int(s["dashes"]) > MAX_DASHES: why.append("%d dashes" % int(s["dashes"]))
					if float(s["ring"]) > MAX_RING * WIN: why.append("ring up %.1fs" % float(s["ring"]))
					for k in ["turn", "flips", "jumps", "dashes", "ring"]:
						var v := float(s[k])
						if v > float(worst.get(k, 0.0)): worst[k] = v
					if not why.is_empty() or verbose:
						if not why.is_empty(): flagged += 1
						var a: Dictionary = h.ai
						print("SANITY %s seed %d t=%.0f %s (%s): %s | goal=%s tgt=%s cross=%s gl=%s gr=%s pos=%s turn=%.1f flips=%d jumps=%d dashes=%d ring=%.1f" % ["FLAG" if not why.is_empty() else "    ", sd, m.time, h.pname, h.ctrl, ", ".join(why),
							str(a.get("goal_kind", "")), str(a.get("tgt")).get_slice(":", 0), str(a.has("cross")), h.gliding, h.grounded, str(h.pos.snapped(Vector3(0.1, 0.1, 0.1))),
							float(s["turn"]), int(s["flips"]), int(s["jumps"]), int(s["dashes"]), float(s["ring"])])
					s["turn"] = 0.0; s["flips"] = 0; s["jumps"] = 0; s["dashes"] = 0; s["ring"] = 0.0; s["t"] = 0.0
		print("SANITY seed %d: %d flagged windows over %.0fs" % [sd, flagged, m.time])
		bad += flagged
		m.queue_free()
		await main.get_tree().process_frame
	print("SANITY worst window: turn %.1f rad, flips %d, jumps %d, dashes %d, ring %.1fs" % [float(worst.get("turn", 0)), int(worst.get("flips", 0)), int(worst.get("jumps", 0)), int(worst.get("dashes", 0)), float(worst.get("ring", 0))])
	print("SANITY done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
