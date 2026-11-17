extends RefCounted
## --extract-check, moved out of main.gd (AGENTS.md section 2); registered in tools/check_registry.gd.

var main: Node

## Headless check of the uplink outposts (the Heart has --heart-check): charge one (a rival in the
## yard stalls it, more of your squad charge it faster, it completes, the lift opens), and an empty
## yard drains it until it fizzles and cools down.
func run(main_node: Node) -> void:
	main = main_node
	var ok := true
	var fresh := func(sq: int) -> Match:
		var mm := Match.new()
		main.add_child(mm)
		mm.start({"teams": 2, "squad": sq, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
		mm.set_process(false)
		for h in mm.hunters:
			h.ctrl = "idle"; h.inp["move"] = Vector2.ZERO
			h.max_hp = 5000.0; h.hp = 5000.0
		for mb in mm.mobs: mb.queue_free()
		mm.mobs.clear()
		return mm
	var run := func(mm: Match, sec: float, every := Callable()):
		var t := 0.0
		while t < sec and not mm.over:
			if every.is_valid(): every.call()
			mm.step(Match.DT); t += Match.DT
	# keeps the test quiet: wave monsters cleared, and the idle hunters held where they were put
	# (biome hazards like gusts would otherwise shove them around)
	var calm := func(mm: Match):
		for mb in mm.mobs:
			if not mb.dead: mb.dead = true; mb.visible = false
		for h in mm.hunters:
			if h.has_meta("pin") and not h.extracted and not h.out:
				h.teleport(h.get_meta("pin")); h.vel = Vector3.ZERO
	var done := func(mm: Match):
		mm.over = true       # the end-of-match timer must not take us to the results screen
		mm.queue_free()
	# ---- 1. the uplink
	var m: Match = fresh.call(2)
	if m.exits.of_kind("outpost").is_empty():
		print("EXCHECK FAIL no uplink outpost on the map"); main.get_tree().quit(); return
	var P: Hunter = m.player
	var R: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	var o: Dictionary = m.exits.uplink_x()
	m.time = float(o["open_at"]) + 1.0
	P.teleport(o["pos"] + Vector3(0.6, 0, 0.6))
	run.call(m, 2.0, func(): P.inp["interact"] = true)
	P.inp["interact"] = false
	P.set_meta("pin", o["pos"] + Vector3(0.6, 0, 0.6))
	print("EXCHECK uplink: state=%s team=%d" % [o["state"], int(o["team"])])
	if o["state"] != "charging": ok = false; print("EXCHECK FAIL uplink didn't start")
	run.call(m, 8.0, calm.bind(m))
	var p1 := float(o["prog"])
	R.teleport(o["pos"] + Vector3(-1.6, 0, 1.0))
	R.set_meta("pin", R.pos)
	run.call(m, 1.0, calm.bind(m))
	var pa := float(o["prog"])
	run.call(m, 3.0, calm.bind(m))
	var pb := float(o["prog"])
	print("EXCHECK uplink: %d%% after 8s; rival in the yard: contested=%s %d%% -> %d%% over 3s (paused)" % [int(p1 * 100), o["contested"], int(pa * 100), int(pb * 100)])
	if p1 <= 0.1 or not o["contested"] or absf(pb - pa) > 0.001: ok = false; print("EXCHECK FAIL contest")
	R.remove_meta("pin")
	R.teleport(m.world.random_ground())
	var t0 := m.time
	while o["state"] == "charging" and m.time - t0 < 60.0:
		run.call(m, 0.5, calm.bind(m))
	print("EXCHECK uplink: state=%s after %.0fs more, waves=%d prog=%.2f contested=%s player in yard=%s (%.1fm) downed=%s" % [o["state"], m.time - t0, int(o["waves"]), float(o["prog"]), o["contested"], m.exits.in_yard(o, P), P.flat_dist(o["pos"]), P.downed])
	for h in m.hunters: print("   ", h.pname, " team ", h.team, " ", h.flat_dist(o["pos"]), " in yard ", m.exits.in_yard(o, h))
	if o["state"] != "open" or int(o["waves"]) < 2: ok = false; print("EXCHECK FAIL uplink never completed (or no waves)")
	P.remove_meta("pin")
	P.teleport(o["pos"] + Vector3(0.4, 0, 0.3))
	run.call(m, 0.3)
	print("EXCHECK uplink: player extracted=%s how=%s where=%s" % [P.extracted, m.result.get("how", ""), m.result.get("where", "")])
	if not P.extracted or m.result.get("how", "") != "uplink": ok = false; print("EXCHECK FAIL lift")
	done.call(m)
	await main.get_tree().process_frame
	# ---- 1b. one of the squad charges the uplink; more of you in the yard charge it faster (and a
	# rival still stalls it however many of you there are). Squadmate bots come and hold the yard.
	m = fresh.call(3)
	P = m.player
	var crew: Array = m.hunters.filter(func(x): return x.team == P.team)
	R = m.hunters.filter(func(x): return x.team != P.team)[0]
	o = m.exits.uplink_x()
	m.time = float(o["open_at"]) + 1.0
	for i in crew.size():
		var h: Hunter = crew[i]
		h.teleport(m.world.random_ground()); h.set_meta("pin", h.pos)
	P.teleport(o["pos"] + Vector3(0.6, 0, 0.6)); P.set_meta("pin", P.pos)
	run.call(m, 2.0, func(): P.inp["interact"] = true)
	P.inp["interact"] = false
	var rates: Array = []
	for n in [1, 2, 3]:
		for i in n:
			var h: Hunter = crew[i]
			var at: Vector3 = o["pos"] + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.2
			h.teleport(at); h.set_meta("pin", at)
		run.call(m, 0.2, calm.bind(m))
		var q0 := float(o["prog"])
		run.call(m, 2.0, calm.bind(m))
		rates.append((float(o["prog"]) - q0) / 2.0 * m.exits.uplink_time(o))
	var crew_ok: bool = absf(float(rates[0]) - 1.0) < 0.05 and absf(float(rates[1]) - 1.5) < 0.05 and absf(float(rates[2]) - 1.8) < 0.05
	print("EXCHECK uplink crew: charge rate x%.2f with one, x%.2f with two, x%.2f with three in the yard (crew %d)" % [rates[0], rates[1], rates[2], int(o.get("crew", 0))])
	if not crew_ok: ok = false; print("EXCHECK FAIL uplink crew rates")
	R.teleport(o["pos"] + Vector3(-1.6, 0, 1.0)); R.set_meta("pin", R.pos)
	run.call(m, 0.2, calm.bind(m))
	var qc0 := float(o["prog"])
	run.call(m, 2.0, calm.bind(m))
	print("EXCHECK uplink crew: three of you and one rival in the yard: contested=%s %d%% -> %d%%" % [o["contested"], int(qc0 * 100), int(float(o["prog"]) * 100)])
	if not o["contested"] or absf(float(o["prog"]) - qc0) > 0.001: ok = false; print("EXCHECK FAIL contest with a crew")
	R.remove_meta("pin"); R.teleport(m.world.random_ground())
	# a squadmate bot elsewhere goes to hold the yard, at its own spot
	var YB: Hunter = crew[2]
	YB.remove_meta("pin"); YB.teleport(m.world.random_ground()); YB.ctrl = "bot"
	var bgx: Array = m.exits.bot_goal(YB, false)
	print("EXCHECK uplink crew: a squadmate bot heads for %s (%s, %.1fm from the mast)" % [str(bgx.slice(1)), str(bgx[0]) if not bgx.is_empty() else "-", (bgx[0] as Vector3).distance_to(o["pos"]) if not bgx.is_empty() else -1.0])
	if bgx.is_empty() or String(bgx[1]) != "yard" or not m.exits.in_yard(o, crew[0]) or (bgx[0] as Vector3).distance_to(o["pos"]) > Exits.OUTPOST_R - 0.5: ok = false; print("EXCHECK FAIL bot yard")
	# ... and it walks there and holds it (the uplink charging the while)
	for h in m.hunters:
		if h != YB: h.remove_meta("pin"); h.teleport(m.world.random_ground()); h.set_meta("pin", h.pos)
	YB.teleport(o["pos"] + Vector3(9.0, 0, 0) if not m.world.is_void(o["pos"].x + 9.0, o["pos"].z) else o["pos"] + Vector3(0, 0, 9.0))
	var yb_in := 0.0
	var tyb := 0.0
	seed(2024)      # the bot's random choices should not depend on how many rolls the map and loot took
	while tyb < 16.0:
		run.call(m, 0.25, calm.bind(m)); tyb += 0.25
		if m.exits.in_yard(o, YB): yb_in += 0.25
	print("EXCHECK uplink crew: the bot held the yard %.1fs of the last 16s (%.1fm from the mast)" % [yb_in, YB.flat_dist(o["pos"])])
	if yb_in < 8.0 or not m.exits.in_yard(o, YB): ok = false; print("EXCHECK FAIL bot didn't hold the yard")
	YB.ctrl = "idle"; YB.inp["move"] = Vector2.ZERO
	# ---- 1c. nobody in the yard: the charge drains (shown on the HUD and over the yard); at nothing
	# the uplink flickers, shuts off, and after a cooldown can be started again
	# (everyone else idle and well clear of the yard: a squadmate or rival anywhere near it would keep
	# it from draining)
	for h in m.hunters:
		if h == P: continue
		h.ctrl = "idle"; h.inp["move"] = Vector2.ZERO
		var far := m.world.random_ground()
		for k in 200:
			if far.distance_to(o["pos"]) > 25.0: break
			far = m.world.random_ground()
		h.remove_meta("pin"); h.teleport(far); h.set_meta("pin", far)
	P.remove_meta("pin"); P.teleport(o["pos"] + Vector3(6.0, 0, 0) if not m.world.is_void(o["pos"].x + 6.0, o["pos"].z) else o["pos"] + Vector3(0, 0, 6.0)); P.set_meta("pin", P.pos)
	o["prog"] = 0.5
	run.call(m, 0.2, calm.bind(m))
	var d0 := float(o["prog"])
	run.call(m, 3.0, calm.bind(m))
	var d1 := float(o["prog"])
	var ust: Dictionary = m.exits.status_for(P)
	var drain_rate := (d0 - d1) / 3.0 * Exits.UPLINK_DECAY_T
	print("EXCHECK uplink decay: nobody in the yard: %d%% -> %d%% in 3s (x%.2f of a full drain in %ds); '%s'" % [int(d0 * 100), int(d1 * 100), drain_rate, int(Exits.UPLINK_DECAY_T), String(ust.get("text", ""))])
	if not o.get("draining", false) or absf(drain_rate - 1.0) > 0.05 or not String(ust.get("text", "")).contains("draining"): ok = false; print("EXCHECK FAIL uplink decay")
	# back in the yard it charges again
	P.teleport(o["pos"] + Vector3(0.6, 0, 0.6)); P.set_meta("pin", P.pos)
	run.call(m, 1.0, calm.bind(m))
	var d2 := float(o["prog"])
	if o.get("draining", false) or d2 <= d1: ok = false; print("EXCHECK FAIL back in the yard it didn't charge")
	# out again until it runs dry
	P.teleport(o["pos"] + Vector3(6.0, 0, 0) if not m.world.is_void(o["pos"].x + 6.0, o["pos"].z) else o["pos"] + Vector3(0, 0, 6.0)); P.set_meta("pin", P.pos)
	var seen_fizz := false
	var tf := 0.0
	while tf < Exits.UPLINK_DECAY_T + Exits.FIZZLE_T + 2.0 and String(o["state"]) != "spent":
		run.call(m, 0.25, calm.bind(m)); tf += 0.25
		if String(o["state"]) == "fizzling": seen_fizz = true
	print("EXCHECK uplink decay: ran dry after %.1fs: flickered %s, now %s (team %d, prog %.2f, crew %d, contested %s, draining %s, match over %s)" % [tf, seen_fizz, o["state"], int(o["team"]), float(o["prog"]), int(o.get("crew", 0)), o.get("contested", false), o.get("draining", false), m.over])
	if not seen_fizz or String(o["state"]) != "spent" or int(o["team"]) != -1: ok = false; print("EXCHECK FAIL uplink fizzle")
	run.call(m, Exits.FIZZLE_CD + 0.5, calm.bind(m))
	print("EXCHECK uplink decay: after the cooldown it's %s, startable %s" % [o["state"], m.exits.startable(o)])
	if String(o["state"]) != "idle" or not m.exits.startable(o): ok = false; print("EXCHECK FAIL uplink not startable again")
	done.call(m)
	await main.get_tree().process_frame
	# ---- 3d. the Uplink quest seat (tools/uplink_seat_check.gd)
	if not await load("res://tools/uplink_seat_check.gd").new().check(main, fresh, run, done): ok = false
	print("EXCHECK ", "PASS" if ok else "FAIL")
	main.get_tree().quit()
