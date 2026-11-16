extends RefCounted
## --drop-check, moved out of main.gd (AGENTS.md section 2); registered in tools/check_registry.gd.

var main: Node

## The drop: the planning phase, map pings, the squad launching one rocket, passing the lead, jumping
## out, and the randomised spawns (different between seeds, rare kin only where rolled).
func run(main_node: Node) -> void:
	main = main_node
	var ok := true
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 3, "tier": 0, "seed": 4101})
	m.set_process(false)
	var P: Hunter = m.player
	var D: DropSquad = m.skydrop
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	print("DCHECK planning=%s plan_t=%.1f riding=%s leader=%s map open=%s" % [D.planning, D.plan_t, P.riding, D.leader(P.team).pname, m.hud.map_open()])
	if not D.planning or absf(D.plan_t - DropSquad.PLAN_T) > 0.01 or not P.riding or D.leader(P.team) != P or not m.hud.map_open():
		ok = false; print("DCHECK FAIL planning phase did not start right")
	# a ping placed on the map (the same path a click takes)
	var target: Vector3 = m.world.spawns[0]
	var sp: SpawnPlan = m.spawn_plan
	if sp and not sp.active_of("vault").is_empty(): target = sp.active_of("vault")[0]["pos"]
	m.hud.full_map.ping_at(target)
	var mine := m.my_ping()
	print("DCHECK map ping at %s -> %s (squad pings %d)" % [str(target.snapped(Vector3(0.1, 0.1, 0.1))), str(mine.get("pos", Vector3.INF)), m.pings.filter(func(q): return q.has("by")).size()])
	if mine.is_empty() or Vector2(mine["pos"].x - target.x, mine["pos"].z - target.z).length() > 0.6: ok = false; print("DCHECK FAIL map ping")
	var steps := 0
	var t0 := m.time
	while D.planning and steps < 2000:
		m.step(Match.DT); steps += 1
	var bot_pings := m.pings.filter(func(q): return q.has("by") and (q["by"] as Hunter).ctrl == "bot").size()
	var acks := m.truce.shown.filter(func(e): return e["id"] == "omw").size() if m.truce else 0
	print("DCHECK planning lasted %.2fs, match clock %.2f -> %.2f, bot pings %d, bot replies %d, events %s" % [steps * Match.DT, t0, m.time, bot_pings, acks, str(D.events)])
	if absf(steps * Match.DT - DropSquad.PLAN_T) > 0.1 or m.time != t0: ok = false; print("DCHECK FAIL planning length / clock")
	if bot_pings < 1: ok = false; print("DCHECK FAIL bots never pinged")
	# a follower can't jump by themselves while the leader is aboard
	var f0: Hunter = mates[0]
	m.ship_jump(f0)
	if not f0.riding: ok = false; print("DCHECK FAIL a follower jumped without the leader")
	# ride to the middle of the map, then the leader jumps
	var mid := Vector3(m.world.w * 0.5, 0, m.world.h * 0.5)
	while Vector2(m.ship_pos().x - mid.x, m.ship_pos().z - mid.z).length() > 26.0 and m.time < 60.0 and P.riding:
		m.step(Match.DT)
	m.ship_jump(P)
	var aboard := mates.filter(func(x): return x.rocket != null and x.rocket == P.rocket)
	print("DCHECK leader launched at t=%.1f: %d of %d squadmates in the rocket" % [m.time, aboard.size(), mates.size()])
	if P.rocket == null or aboard.size() != mates.size(): ok = false; print("DCHECK FAIL the squad didn't launch together")
	for i in 30: m.step(Match.DT)
	# pass the lead: the next squadmate steers the rocket
	var passed := D.pass_lead(P)
	var L2: Hunter = D.leader(P.team)
	print("DCHECK pass lead=%s: leader now %s" % [passed, L2.pname])
	if not passed or L2 == P or not aboard.has(L2): ok = false; print("DCHECK FAIL pass lead")
	# jump out: you free-fall and steer yourself
	var det := D.detach(P)
	var want := Vector2(-1, 0)
	var t := 0.0
	while t < 0.7 and P.dropping:
		P.inp["move"] = want
		m.step(Match.DT); t += Match.DT
	var v1 := Vector2(P.vel.x, P.vel.z)
	print("DCHECK detach=%s: rocket=%s dropping=%s, velocity %s (steering %s)" % [det, P.rocket, P.dropping, str(v1.snapped(Vector2(0.1, 0.1))), str(want)])
	if not det or P.rocket != null or not P.dropping or v1.normalized().dot(want) < 0.7: ok = false; print("DCHECK FAIL detach")
	# everyone lands
	t = 0.0
	while t < 20.0 and m.hunters.any(func(x): return x.dropping or x.riding):
		m.step(Match.DT); t += Match.DT
	print("DCHECK landed after %.1fs more; squad on ground %s" % [t, str(m.hunters.filter(func(x): return x.team == P.team).map(func(x): return [x.pname, x.grounded, x.pos.snapped(Vector3(1, 1, 1))]))])
	if m.hunters.any(func(x): return x.dropping or x.riding): ok = false; print("DCHECK FAIL someone never landed")
	# on the ground: a ping from you sends your squad's bots there, and one answers
	var bot: Hunter = mates[1] if mates.size() > 1 else mates[0]
	# the drop above is steered by script: if it ended off an island (stuck under a rim), put the
	# ground half of the test on solid ground so it tests pings and scouting, not the glide line
	var base_spot := m.world.free_spot_near(m.world.spawns[0], [], 1.0, 0.5, 8.0)
	for x in [P, bot]:
		# (a scripted glide that ends over the abyss loses that hunter: bring them back first, so the
		# rest tests pings and scouting with everyone alive, not whatever a revive beacon does later)
		if x.out or x.downed:
			Life.bring_back(m, x, base_spot + (Vector3(2.0, 0, 0) if x == bot else Vector3.ZERO), 1.0, false)
		if m.world.is_void(x.pos.x, x.pos.z) or x.pos.y < m.world.ground_at(x.pos.x, x.pos.z) - 1.0:
			x.teleport(base_spot + (Vector3(2.0, 0, 0) if x == bot else Vector3.ZERO))
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for o in m.hunters:
		if o.team != P.team:
			o.ctrl = "idle"; o.teleport(m.world.spawns[-1] + Vector3(0, 0, 0))     # (no fights in the way)
	var ev0 := D.events.size()
	var spot := bot.pos
	for k in 40:
		var q := m.world.free_spot_near(bot.pos + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)), [], 1.0, 0.5, 6.0)
		if m.world.island_of(q.x, q.z) == m.world.island_of(bot.pos.x, bot.pos.z) and bot.flat_dist(q) > 6.0 and bot.flat_dist(q) < 9.0 and m.world.los(bot.pos, q, bot.pos.y + 1.0):
			spot = q; break      # (6-9 m: an unseeded roll, so a far spot made the 6 s walk a coin flip)
	spot.y = m.world.ground_at(spot.x, spot.z)
	m.squad_ping(P, spot)
	var d0 := bot.flat_dist(spot)
	var went := false
	var closest := d0
	t = 0.0
	while t < 6.0:
		m.step(Match.DT); t += Match.DT
		# any squad bot: one busy with its downed Boki or a beacon leaves it to the other
		if mates.any(func(x): return String(x.ai.get("goal_kind", "")) == "ping"): went = true
		closest = minf(closest, mates.map(func(x): return x.flat_dist(spot)).min())
	var replies: Array = D.events.slice(ev0).filter(func(e): return String(e).begins_with("reply"))
	print("DCHECK ground ping: %s headed there=%s, %.1fm -> got within %.1fm; replies %s (from %s to %s)" % [bot.pname, went, d0, closest, str(replies), str(bot.pos.snapped(Vector3(0.1, 0.1, 0.1))), str(spot.snapped(Vector3(0.1, 0.1, 0.1)))])
	if not went or closest > 4.0 or not replies.any(func(r): return String(r).ends_with("omw")): ok = false; print("DCHECK FAIL squad bots ignore pings")
	m.unping(P)
	if not m.my_ping().is_empty() or bot.ai.has("ping_goal"): ok = false; print("DCHECK FAIL right click didn't take the ping down")
	# the spawns: the same candidates every match, a different live subset per seed
	var layout := World.load_layout(World.layout_for_tier(0))
	var subsets := {}
	for sd in [4101, 4102, 4103]:
		var plan := SpawnPlan.new(m)
		plan.build(layout)
		plan.roll(sd)
		subsets[sd] = plan.active_ids()
	print("DCHECK candidates %s; live by seed: %s" % [str(sp.shown_cats().map(func(cc): return "%s %d/%d" % [cc, sp.active_of(cc).size(), sp.of(cc).size()])), str(subsets)])
	if subsets[4101] != sp.active_ids(): ok = false; print("DCHECK FAIL the same seed rolled differently")
	if subsets[4101] == subsets[4102] and subsets[4102] == subsets[4103]: ok = false; print("DCHECK FAIL seeds roll the same spawns")
	# a generated map (no authored list): candidates come from its islands, the same for the same map
	var gm := Match.new()
	gm.world = World.new()
	gm.world.generate(9, World.BIG_SIZE, World.BIG_ISLANDS)
	var g1 := SpawnPlan.new(gm); g1.build({})
	var g2 := SpawnPlan.new(gm); g2.build({})
	var gpos: Array = g1.cands.map(func(cc): return cc["pos"])
	var counts: Array = g1.shown_cats().map(func(cc): return "%s %d" % [cc, g1.count_of(cc)])
	print("DCHECK generated map candidates: %s (same both times=%s)" % [str(counts), gpos == g2.cands.map(func(cc): return cc["pos"])])
	if g1.count_of("rare_kin") < 3 or g1.count_of("vault") < 2 or g1.count_of("cache") < 4 or gpos != g2.cands.map(func(cc): return cc["pos"]): ok = false; print("DCHECK FAIL generated map candidates")
	gm.world.free(); gm.free()
	# rare kin only at the live rare-kin points, one at each
	var rare: Array = m.kins.filter(func(k): return k.has_meta("rare"))
	var live: Array = sp.active_of("rare_kin")
	var stray := 0
	for k in rare:
		var near := false
		for cnd in live:
			if Vector2(k.home.x - cnd["pos"].x, k.home.z - cnd["pos"].z).length() < 3.0: near = true
		if not near: stray += 1
	var at_dead := 0
	for cnd in sp.of("rare_kin"):
		if cnd["active"]: continue
		for k in rare:
			if Vector2(k.home.x - cnd["pos"].x, k.home.z - cnd["pos"].z).length() < 3.0: at_dead += 1
	print("DCHECK rare kin: %d spawned for %d live points (%d strays, %d at points not rolled)" % [rare.size(), live.size(), stray, at_dead])
	if rare.size() != live.size() or stray > 0 or at_dead > 0: ok = false; print("DCHECK FAIL rare kin spawns")
	# scouting: walk the player to an unrolled candidate and its state turns from "?" to empty
	var hidden: Array = sp.cands.filter(func(cc): return not sp.cats[cc["cat"]].get("announce", false) and not cc["active"])
	if not hidden.is_empty():
		var hc: Dictionary = hidden[0]
		var before := sp.state_for(hc, P.team)
		if P.out or P.downed: Life.bring_back(m, P, hc["pos"], 1.0, false)      # (walking off an island is allowed now: the player may have gone over the edge during the checks above; same bring-back as the ground half)
		P.teleport(hc["pos"] + Vector3(1.5, 0, 0))
		for i in 30: m.step(Match.DT)
		print("DCHECK scouting %s: %s -> %s" % [hc["id"], before, sp.state_for(hc, P.team)])
		if before != "unknown" or sp.state_for(hc, P.team) != "empty": ok = false; print("DCHECK FAIL scouting")
	m.over = true
	print("DCHECK ", "PASS" if ok else "FAIL")
	main.get_tree().quit()
