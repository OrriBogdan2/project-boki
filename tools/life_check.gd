extends RefCounted
## --life-check: the down / death / revive rules, step by step, with idle hunters placed by hand.

func run(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	var mine: Array = m.hunters.filter(func(x): return x.team == 0)
	var foe: Hunter = m.hunters.filter(func(x): return x.team != 0)[0]
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var A: Hunter = mine[0]; var B: Hunter = mine[1]; var C: Hunter = mine[2]
	var home: Vector3 = A.pos
	# the test steps up to 8m in every direction, so start from open ground (spawns can be small landings)
	for k in 2000:
		var g := m.world.random_ground()
		var roomy := true
		for dx in range(-10, 11, 2):
			for dz in range(-6, 7, 2):
				if m.world.is_void(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - m.world.ground_at(g.x, g.z)) > 0.3: roomy = false
		if roomy:
			home = g; break
	var far := home + Vector3(0, 0, 0)
	var spot := func(h: Hunter, at: Vector3): h.teleport(at); h.vel = Vector3.ZERO
	var run := func(sec: float):
		var t := 0.0
		while t < sec:
			m.step(Match.DT); t += Match.DT
	# park everyone else far apart
	for h in m.hunters:
		if h.team != 0 and h != foe: spot.call(h, m.world.random_ground())
	var away := m.world.random_ground()
	for k in 200:
		if away.distance_to(home) > 40.0: break
		away = m.world.random_ground()
	spot.call(foe, away)
	# 1. ally revive
	spot.call(B, home + Vector3(2, 0, 0)); spot.call(C, home + Vector3(2, 0, 0.5)); spot.call(A, home)
	m.knock(B, foe, {})
	var t0 := m.time
	while B.downed and m.time - t0 < 10.0: run.call(Match.DT)
	print("LCHECK ally revive: back=%s after %.1fs hp %.0f%%" % [not B.downed, m.time - t0, B.hp / B.max_hp * 100.0])
	# 2. bleed out alone (with the kin knocked out, so it can't pull them up)
	for kk in [B.kin, B.kin2]:
		if kk: kk.dead = true
	spot.call(C, home + Vector3(-8, 0, 0)); spot.call(A, home + Vector3(-8, 0, 1))
	B.gems = 20
	m.knock(B, foe, {})
	t0 = m.time
	print("LCHECK  knocked: downed=%s hp=%s" % [B.downed, B.down_hp])
	while not B.out and m.time - t0 < 30.0:
		run.call(Match.DT)
		if int((m.time - t0) * 60.0) % 120 == 0: print("LCHECK   t=%.1f downed=%s down_hp=%.1f revive=%.2f out=%s" % [m.time - t0, B.downed, B.down_hp, B.revive, B.out])
	var bx := Life.box_of(m, B)
	print("LCHECK bleed: dead=%s after %.1fs box=%s gems in box=%d" % [B.out, m.time - t0, not bx.is_empty(), int(bx.get("gems", -1))])
	# 3. box revive: --box-revive-check (tools/box_revive_check.gd) times the channel; here it just brings B back
	Life.box_revive(m, bx, C)
	print("LCHECK box revive: back=%s hp %.0f%% gems %d" % [not B.out, B.hp / B.max_hp * 100.0, B.gems])
	# 4. stomp drain
	for kk in [B.kin, B.kin2]:
		if kk: kk.dead = true
	spot.call(C, home + Vector3(-8, 0, 0))
	spot.call(foe, B.pos)
	m.knock(B, foe, {})
	t0 = m.time
	run.call(Match.DT); run.call(Match.DT)
	var pinned: bool = B.get_meta("stomped", false)
	var stood: bool = foe.get_meta("standing_on", null) == B
	while not B.out and m.time - t0 < 30.0: run.call(Match.DT)
	print("LCHECK stomp: dead=%s after %.1fs (expect ~%.1fs at %.1fx) pinned=%s stomper flagged=%s slow=%.2f" % [B.out, m.time - t0, Life.R["bleed_out"] / Life.R["stomp_mult"], Life.R["stomp_mult"], pinned, stood, Life.R["stomp_slow"]])
	spot.call(foe, m.world.random_ground())
	# 5. beacon
	var bc: Dictionary = m.beacons[0]
	spot.call(C, bc["pos"])
	t0 = m.time
	while B.out and m.time - t0 < 12.0: run.call(Match.DT)
	print("LCHECK beacon: back=%s after %.1fs hp %.0f%% sick %.1fs used=%s" % [not B.out, m.time - t0, B.hp / B.max_hp * 100.0, B.sick_t, bc["used"]])
	# 6. execute
	for kk in [B.kin, B.kin2]:
		if kk: kk.dead = true
	spot.call(C, home + Vector3(-8, 0, 0)); spot.call(B, home + Vector3(6, 0, 0))
	m.knock(B, foe, {})
	spot.call(foe, B.pos + Vector3(0.5, 0, 0)); foe.inp["interact"] = true
	t0 = m.time
	while not B.out and m.time - t0 < 10.0:
		foe.inp["interact"] = true
		run.call(Match.DT)
	print("LCHECK execute: dead=%s after %.1fs (stomp drains too)" % [B.out, m.time - t0])
	# 6b. a committed stomp can't be cancelled by its owner, but a knockback breaks it
	var W2: Hunter = C
	for kk in [W2.kin, W2.kin2]:
		if kk: kk.dead = true
	spot.call(W2, home + Vector3(2, 0, 3))
	m.knock(W2, foe, {})
	spot.call(foe, W2.pos + Vector3(0.5, 0, 0))
	t0 = m.time
	while foe.stomp.is_empty() and m.time - t0 < 2.0:
		foe.inp["interact"] = true
		run.call(Match.DT)
	var committed := not foe.stomp.is_empty()
	for i in 30:
		foe.inp["interact"] = false      # letting go does nothing once committed
		foe.inp["move"] = Vector2(1, 0)
		run.call(Match.DT)
	var still := not foe.stomp.is_empty()
	foe.kb_t = m.time
	run.call(Match.DT)
	print("LCHECK stomp lock: committed=%s still after letting go=%s broken by knock=%s wisp alive=%s" % [committed, still, foe.stomp.is_empty(), not W2.out])
	print("LCHECK beacons=%d boxes=%d" % [m.beacons.size(), m.boxes.size()])
	# 7. Hollow rules: the Boki on you drops dazed beside the box and guards it; an enemy looting the box takes none of it
	m.tier = 2
	m.T = Data.TIERS[2]
	var rec := Save.new_kin("zapple")
	A.kin = null; A.kin2 = null
	m.give_kin(A, rec)
	spot.call(A, home); spot.call(B, home + Vector3(-8, 0, 0)); spot.call(C, home + Vector3(-8, 0, 1))
	m.eliminate(A, foe, "knocked out")
	var ab := Life.box_of(m, A)
	print("LCHECK hollow: kin guarding=%s" % KinLoss.guarding(A.kin))
	spot.call(foe, ab["pos"])
	t0 = m.time
	while not ab["empty"] and m.time - t0 < 4.0:
		foe.inp["interact"] = true
		run.call(Match.DT)
	print("LCHECK hollow loot: foe caught=%d guard still dazed=%s" % [foe.caught.size(), KinLoss.guarding(A.kin)])
	# 8. Meadow: kin stay safe (hidden) on death and come back on revive
	m.tier = 0
	m.T = Data.TIERS[0]
	spot.call(foe, m.world.random_ground())
	var B2: Hunter = B
	B2.kin = null; B2.kin2 = null
	m.give_kin(B2, Save.new_kin("zapple"))
	spot.call(B2, home + Vector3(-6, 0, 0))
	m.eliminate(B2, foe, "knocked out")
	print("LCHECK meadow: kin state=%s lost=%d" % [B2.kin.state, m.player_lost.size()])
	# 9. the deathbox loot window: a box with a rare glove and some gems; take one by hand, smart loot the rest
	var lb: Dictionary = {}
	for b0 in m.boxes:
		if not b0.get("empty", true):
			lb = b0
	if not lb.is_empty():
		var gid: String = String(Gear.ALL.keys()[0]) if not Gear.ALL.is_empty() else ""
		if gid != "": (lb["gear"] as Array).append({"id": gid, "rar": 3})
		lb["gems"] = int(lb.get("gems", 0)) + 15
		var looter: Hunter = C
		looter.gear = Gear.empty_slots(); looter.refresh_gear()
		var its: Array = Life.box_items(m, looter, lb)
		var g0 := looter.gems
		var first: Dictionary = its[0]
		Life.take_item(m, looter, lb, first)
		var got := Life.smart_loot(m, looter, lb)
		print("LCHECK loot window: items=%d took first=%s smart=%d gems +%d gear=%s left=%d empty=%s" % [its.size(), first["name"], got, looter.gems - g0, str(looter.gear), Life.box_items(m, looter, lb).size(), lb["empty"]])
	main.get_tree().quit()
