extends RefCounted
## --truce-check, moved out of main.gd (AGENTS.md section 2); registered in tools/check_registry.gd.

var main: Node

## Headless check of truces: a weak bot squad offers one to a strong squad (by its own weighing),
## the strong squad answers; with a truce in place neither targets the other; an attack breaks it,
## is announced and marks the betrayer; truce partners share an uplink's yard without contesting it.
func run(main_node: Node) -> void:
	main = main_node
	var ok := true
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.time = 120.0
	var A: Array = m.hunters.filter(func(x): return x.team == 0)
	var B: Array = m.hunters.filter(func(x): return x.team == 1)
	# open flat ground for the stand-off
	var home: Vector3 = A[0].pos
	for k in 3000:
		var g := m.world.random_ground()
		var roomy := true
		for dx in range(-8, 9):
			for dz in range(-4, 5):
				if m.world.is_void(g.x + dx, g.z + dz) or m.world.is_block(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - g.y) > 0.3: roomy = false
		if roomy:
			home = g; break
	var spots := {}
	for i in A.size(): spots[A[i]] = home + Vector3(-3.5, 0, -1.0 + 2.0 * i)
	for i in B.size(): spots[B[i]] = home + Vector3(3.5, 0, -1.0 + 2.0 * i)
	for h in m.hunters:
		h.ctrl = "bot"
		h.teleport(spots[h])
	# squad A is hurt and bare; squad B is fresh with good armor
	for h in A:
		h.hp = h.max_hp * 0.2; h.armor = 0.0
	for h in B:
		h.armor_tier = 3; h.armor = h.max_armor
	var hold := func():
		for h in m.hunters:
			if not h.out and not h.extracted:
				h.teleport(spots[h]); h.vel = Vector3.ZERO; h.inv_t = 5.0
				if h.downed: m.revive_hunter(h, null)
				if h.team == 0: h.hp = minf(h.hp, h.max_hp * 0.2); h.armor = 0.0; h.tonics = 0     # squad A stays hurt
	var run := func(sec: float):
		var t := 0.0
		while t < sec:
			hold.call(); m.step(Match.DT); t += Match.DT
	var cross := func() -> int:
		var n := 0
		for h in m.hunters:
			var tg = h.ai.get("tgt")
			if tg is Hunter and (tg as Hunter).team != h.team: n += 1
		return n
	var T: Truce = m.truce
	print("TCHECK strength A=%.1f B=%.1f  peace score A->B=%.2f  B would accept from A=%.2f  A would accept from B=%.2f" % [T.strength(0), T.strength(1), T._peace_score(0, 1, {1: 7.0}), T.would_accept(1, 0), T.would_accept(0, 1)])
	if T.would_accept(1, 0) >= T.would_accept(0, 1): ok = false; print("TCHECK FAIL the stronger squad should be less keen")
	run.call(2.0)
	var before: int = cross.call()
	print("TCHECK before any truce: %d hunters targeting the other squad" % before)
	if before == 0: ok = false; print("TCHECK FAIL they never squared up")
	# the weak squad should raise the flag by itself within a while
	var t0 := m.time
	while not T.events.any(func(e): return String(e).begins_with("offer 0->1")) and m.time - t0 < 40.0:
		run.call(0.25)
	var offered: bool = T.events.any(func(e): return String(e).begins_with("offer 0->1"))
	print("TCHECK weak squad offered a truce: %s after %.1fs" % [offered, m.time - t0])
	if not offered: ok = false; print("TCHECK FAIL no offer")
	run.call(3.5)
	var answered := "accepted" if T.allied(0, 1) else ("faked" if T.events.has("fake 1") else ("refused" if T.events.any(func(e): return String(e).begins_with("refused")) else "no answer"))
	print("TCHECK strong squad answered: %s  (events %s)" % [answered, str(T.events)])
	if answered == "no answer": ok = false; print("TCHECK FAIL no answer")
	if not T.allied(0, 1):
		print("TCHECK (making the truce by hand for the rest of the check)")
		for h in m.hunters: h.ctrl = "idle"      # (a swing under way would land on the new partner and break the truce)
		run.call(1.0)
		for h in m.hunters: h.ctrl = "bot"
		T.make(0, 1)
	for h in m.hunters: h.ai.erase("betray_at"); h.ai.erase("betray")
	run.call(3.0)
	var during: int = cross.call()
	print("TCHECK during the truce: %d hunters targeting the other squad" % during)
	if during != 0: ok = false; print("TCHECK FAIL truce partners still targeted")
	# an attack breaks it
	var traitor: Hunter = B[0]; var victim: Hunter = A[0]
	victim.inv_t = 0.0
	victim.hurt(20.0, traitor, {"src": "shot"})
	var announced: bool = m.feed_all.any(func(f): return String(f).contains("broke the truce"))
	run.call(0.6)
	var hits_back: int = A.filter(func(x): return x.ai.get("tgt") == traitor).size()
	print("TCHECK attack: truce holds=%s announced=%s betrayer marked=%s revealed %.0fs, victims targeting the betrayer=%d" % [T.allied(0, 1), announced, T.is_marked(traitor), traitor.reveal_t, hits_back])
	if T.allied(0, 1) or not announced or not T.is_marked(traitor) or hits_back == 0: ok = false; print("TCHECK FAIL breaking")
	# sharing an uplink
	T.marked.clear()     # (the pact after the clock jump to the uplink's opening: it lasts TRUCE_T from there)
	T.make(0, 1)
	var o: Dictionary = m.exits.uplink_x()
	m.time = maxf(m.time, float(o["open_at"]) + 1.0)
	m.exits.act(o, "start", A[0])
	spots[A[0]] = o["pos"] + Vector3(1.0, 0, 0.8)
	spots[B[0]] = o["pos"] + Vector3(-1.2, 0, -0.9)
	spots[A[1]] = o["pos"] + Vector3(30, 0, 30); spots[B[1]] = o["pos"] + Vector3(30, 0, 30)
	for h in [A[1], B[1]]: spots[h] = m.world.free_spot_near(spots[h], [], 1.0, 0.5, 20.0)
	var p0 := float(o["prog"])
	run.call(3.0)
	var p1 := float(o["prog"])
	print("TCHECK uplink with a truce partner in the yard: contested=%s %d%% -> %d%%" % [o["contested"], int(p0 * 100), int(p1 * 100)])
	if o["contested"] or p1 <= p0: ok = false; print("TCHECK FAIL partner contested the uplink")
	T.end("0:1", "")
	run.call(1.0)
	var p2 := float(o["prog"])
	run.call(2.0)
	print("TCHECK without the truce: contested=%s %d%% -> %d%%" % [o["contested"], int(p2 * 100), int(float(o["prog"]) * 100)])
	if not o["contested"]: ok = false; print("TCHECK FAIL rival didn't contest")
	# the other way round: now squad B is the beaten one, and an offer to it (as a player would
	# make from the emote wheel) gets accepted by its own weighing
	T.marked.clear(); T._cool.clear()
	spots[A[0]] = home + Vector3(-3.5, 0, -1.0); spots[A[1]] = home + Vector3(-3.5, 0, 1.0)
	spots[B[0]] = home + Vector3(3.5, 0, -1.0); spots[B[1]] = home + Vector3(3.5, 0, 1.0)
	for h in A: h.hp = h.max_hp; h.armor = h.max_armor; h.armor_tier = 3; h.tonics = 3
	for h in B: h.hp = h.max_hp * 0.15; h.armor = 0.0; h.armor_tier = 0; h.tonics = 0; h.ai.erase("betray")
	m.player.team = 0
	var hold2 := func():
		for h in m.hunters:
			h.teleport(spots[h]); h.vel = Vector3.ZERO; h.inv_t = 5.0
			if h.team == 1: h.hp = minf(h.hp, h.max_hp * 0.15); h.armor = 0.0
	var tt := 0.0
	while tt < 1.0: hold2.call(); m.step(Match.DT); tt += Match.DT
	print("TCHECK reversed: B would accept from A=%.2f" % T.would_accept(1, 0))
	# acceptance is a weighed roll (95% here), so like a player the offer is made again after a refusal
	tt = 0.0
	for _try in 3:
		T._cool.clear()
		T.emote(A[0], "truce")
		var offer_t := tt
		while tt - offer_t < 3.5 and not T.allied(0, 1): hold2.call(); m.step(Match.DT); tt += Match.DT
		if T.allied(0, 1): break
	print("TCHECK reversed: the beaten squad accepted=%s after %.1fs (events %s)" % [T.allied(0, 1), tt, str(T.events.slice(-3))])
	if not T.allied(0, 1) and not T.events.has("fake 1"): ok = false; print("TCHECK FAIL beaten squad refused")
	if not TruceCalmCheck.run(m, home): ok = false
	m.over = true
	print("TCHECK ", "PASS" if ok else "FAIL")
	main.get_tree().quit()
