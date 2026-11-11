extends RefCounted
## --perf-throttle-check, item 94's script throttles: an idle monster with nobody within Mob.NAP_M stops
## simulating and wakes when a Hunter comes close; a bot further than SimLod.FAR_M from the local player, on
## the ground, roaming or fighting something as far off, thinks and simulates every SimLod.EVERY steps (the
## skipped time added in); a near one, one fighting near the player or just hit by them, every step; its
## Boki steps with it. A calm one past SimLod.THINK_FAR_M picks goals SimLod.THINK_FAR_K times less often;
## a bot aboard the sky ship picks nothing.
## Shadows (ShadowPolicy): no mesh smaller than the preset's caster size casts (Hunters and each Boki's
## body excepted), effects never do, Hunters and walls do. World labels (LabelCull, TextCache): a plate
## off screen or past LabelCull.FAR_M isn't laid out, an on-screen one is, and a label's text is shaped
## once and reused until it changes. Fight effects (FxPool): a flurry of rings, ghosts, bolts and beams
## adds no node to the Fx and every mesh is hidden again once they end (telegraphs are freed, not pooled).
## SpawnPlan's sight checks are spread over frames. World.los and
## World.tile_kind read the grid once a tile and agree with the plain per-sample rule; Hunter.gear_stat's
## worn-gear and perk sums are kept a step and renewed by refresh_gear and a perk taken.

var main: Node
var fails := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("PERFTHROTTLE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	await main.get_tree().process_frame
	_mob_naps()
	_far_bots()
	_catch_up()
	_far_mobs()
	_shadows()
	await _occluders()
	_spawn_sight()
	_sight_lines()
	_worn_sums()
	await _plates()
	await _fx_pools()
	print("PERFTHROTTLE DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _step(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

## SpawnPlan looks at a slice of its spots each frame, each spot again within REVISIT_S, and a squad
## standing on one still learns it in that time.
func _spawn_sight() -> void:
	var sp := m.spawn_plan
	ok(sp != null and sp.cands.size() > 4, "setup: a spawn plan with spots")
	if sp == null or sp.cands.size() <= 4:
		return
	var n := sp.cands.size()
	var c: Dictionary = sp.cands[n / 2]
	(c["known"] as Dictionary).erase(m.player.team)
	m.player.teleport(c["pos"])
	var at := sp._next
	sp.tick(Match.DT)
	var per := posmod(sp._next - at, n)
	ok(per <= ceili(n * Match.DT / SpawnPlan.REVISIT_S), "one frame looks at %d of %d spots" % [per, n])
	var t := Match.DT
	while not (c["known"] as Dictionary).has(m.player.team) and t < SpawnPlan.REVISIT_S + 0.1:
		sp.tick(Match.DT)
		t += Match.DT
	ok((c["known"] as Dictionary).has(m.player.team), "the spot underfoot is known within %.2f s" % t)

## World.los reads each tile once (three lookups a sample before); World.tile_kind is one read. On random
## lines over the real map both agree with the plain per-sample reading of the same rule.
func _sight_lines() -> void:
	var W: World = m.world
	ok(W.dyn_walls.is_empty(), "setup: no ability walls up (the plain rule below reads terrain only)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad := 0
	for i in 400:
		var a := Vector3(rng.randf_range(0.0, W.w), 0.0, rng.randf_range(0.0, W.h))
		var b := a + Vector3(rng.randf_range(-12.0, 12.0), 0.0, rng.randf_range(-12.0, 12.0))
		var y := rng.randf_range(0.5, 2.0)
		if not W.is_void(a.x, a.z):
			y += W.ground_at(a.x, a.z)
		if W.los(a, b, y) != _plain_los(W, a, b, y):
			bad += 1
		var plain := World.T_GROUND
		if W.is_block(b.x, b.z):
			plain = World.T_BLOCK
		elif W.is_void(b.x, b.z):
			plain = World.T_VOID
		if W.tile_kind(b.x, b.z) != plain:
			bad += 1
	ok(bad == 0, "los and tile_kind agree with the plain per-sample reading on 400 random lines (%d differ)" % bad)

## The sight rule as World.los stated it before, a fresh read of every sample.
func _plain_los(W: World, a: Vector3, b: Vector3, y: float) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var n := int(d.length() / 0.4) + 1
	for i in range(1, n):
		var t := float(i) / n
		var px := a.x + d.x * t
		var pz := a.z + d.y * t
		if W.is_block(px, pz) and W.ground_at(px, pz) + World.BLOCK_H > y:
			return false
		if W.ground_at(px, pz) > y + 0.2:
			return false
	return true

## Hunter.gear_stat keeps its worn-gear and perk sums for a step: a slot changed through refresh_gear
## and a perk taken count in the same step, not the next.
func _worn_sums() -> void:
	var p: Hunter = m.player
	p.gear = Gear.empty_slots()
	p.refresh_gear()
	var base := p.gear_stat("speed")
	var gid := ""
	for g in Gear.ALL:
		if float((Gear.ALL[g]["stats"] as Dictionary).get("speed", 0.0)) > 0.0:
			gid = String(g)
			break
	ok(gid != "", "setup: a gear piece with a speed stat")
	if gid != "":
		p.gear[0] = {"id": gid, "rar": 1}
		p.refresh_gear()
		ok(p.gear_stat("speed") > base, "gear put on through refresh_gear counts in the same step")
	var pid := ""
	var pk := ""
	for id in Data.PERKS:
		var st: Dictionary = (Data.PERKS[id] as Dictionary).get("stats", {})
		if not st.is_empty() and String(st.keys()[0]) != "dmg" and p.perk_open(String(id)):
			pid = String(id)
			pk = String(st.keys()[0])
			break
	ok(pid != "", "setup: an open perk with a stat")
	if pid != "":
		var before := p.gear_stat(pk)
		p.add_perk(pid)
		ok(p.gear_stat(pk) != before, "a perk taken counts in the same step (%s: %s)" % [pid, pk])

func _mob_naps() -> void:
	var mb: Mob = null
	for x in m.mobs:
		if not x.dead and x.st == "idle":
			mb = x
			break
	ok(mb != null, "setup: an idle camp monster")
	if mb == null:
		return
	for h in m.hunters:
		if h.flat_dist(mb) < Mob.NAP_M + 10.0:
			h.teleport(mb.pos + Vector3(Mob.NAP_M + 20.0, 0, 0))
	for k in m.kins:
		k.pos = mb.pos + Vector3(Mob.NAP_M + 20.0, 0, 0)
	_step(1.0)
	var at := mb.pos
	_step(2.0)
	ok(mb.pos == at and mb.st == "idle", "with nobody within %.0f m it sleeps where it stands" % Mob.NAP_M)
	m.player.teleport(mb.pos + Vector3(4.0, 0, 0))
	for k in m.kins:
		k.pos = m.player.pos
	_step(1.5)
	ok(mb.st != "idle" or mb.pos != at, "a Hunter walking up wakes it (%s)" % mb.st)

## A 100 ms frame offline advances DashPace.CATCH_UP_S of sim (three steps, not six); online the clock can't wait.
func _catch_up() -> void:
	m.player.roll_t = 0.0
	ok(is_equal_approx(DashPace.frame_dt(m, 0.1), DashPace.CATCH_UP_S), "offline a slow frame advances three steps")
	m.net_on = true
	ok(is_equal_approx(DashPace.frame_dt(m, 0.1), 0.1), "online a slow frame advances its whole time")
	m.net_on = false

func _far_bots() -> void:
	var b: Hunter = null
	for h in m.hunters:
		if h.ctrl == "bot":
			b = h
	ok(b != null, "setup: a bot")
	if b == null:
		return
	b.teleport(m.player.pos + Vector3(SimLod.FAR_M + 15.0, 0, 0))
	b.grounded = true
	b.ai["tgt"] = null
	b.ai["goal_kind"] = "roam"
	var every := SimLod.EVERY
	ok(_lod_steps(b, every * 4) == [4, every * 4], "far and calm it steps every %d sim steps, losing no time" % every)
	var kin: Kin = null
	for k in m.kins:
		if k.owner_h == b:
			kin = k
	if kin:
		kin.state = "active"
		kin.cmd = "follow"
		kin.target = null
		ok(SimLod.kin_dt(kin, Match.DT) == SimLod.step_dt(b, Match.DT), "its Boki on follow steps with it")
	var far_foe: Ent = null
	for mb in m.mobs:
		if mb.flat_dist(m.player) > SimLod.FAR_M:
			far_foe = mb
			break
	b.ai["tgt"] = far_foe
	var far_runs: int = _lod_steps(b, every * 2)[0] if far_foe else -1
	ok(far_runs == 2, "fighting something far off it still steps every %d" % every)
	b.ai["tgt"] = m.player
	ok(_lod_steps(b, 6)[0] == 6, "fighting the player (or anything near them) it steps every step")
	b.ai["tgt"] = null
	b.last_hit_by = m.player
	b.hurt_at = m.time
	ok(_lod_steps(b, 6)[0] == 6, "just hit by the player it steps every step")
	b.hurt_at = -9.0
	b.ai["goal_kind"] = "box"
	ok(_lod_steps(b, every * 2)[0] == 2, "walking to a box far off it still steps every %d" % every)
	b.ai["goal_kind"] = "board"
	ok(_lod_steps(b, 6)[0] == 6, "boarding something that moves it steps every step")
	b.ai["goal_kind"] = "roam"
	ok(SimLod.think_k(m, b) == 1.0, "inside %.0f m it chooses at the usual pace" % SimLod.THINK_FAR_M)
	b.teleport(m.player.pos + Vector3(SimLod.THINK_FAR_M + 15.0, 0, 0))
	b.grounded = true
	var far_m := SimLod.THINK_FAR_M
	var k := SimLod.THINK_FAR_K
	ok(SimLod.think_k(m, b) == k, "past %.0f m and calm it chooses %.0fx less often" % [far_m, k])
	b.ai["tgt"] = m.player
	ok(SimLod.think_k(m, b) == 1.0, "past %.0f m but fighting the player it chooses at the usual pace" % far_m)
	b.ai["tgt"] = null
	b.riding = true
	b.inp["move"] = Vector2(1, 0)
	m.bot_brain.think(m, b, Match.DT)
	ok(b.inp["move"] == Vector2.ZERO, "aboard the sky ship it holds still and picks nothing")
	b.riding = false
	b.teleport(m.player.pos + Vector3(5.0, 0, 0))
	b.grounded = true
	ok(_lod_steps(b, 6)[0] == 6, "near the player it steps every step")

## Plans n sim steps; returns [steps the bot ran, sim steps of time it was given].
func _lod_steps(b: Hunter, n: int) -> Array:
	var runs := 0
	var got := -float(b.ai.get("lod_dt", 0.0))   # time banked before, and after, counts as given
	for i in n:
		SimLod.plan(m, Match.DT)
		var sd := SimLod.step_dt(b, Match.DT)
		if sd > 0.0:
			runs += 1
			got += sd
	got += float(b.ai.get("lod_dt", 0.0))
	return [runs, roundi(got / Match.DT)]

func _far_mobs() -> void:
	var mb: Mob = null
	for x in m.mobs:
		if not x.dead:
			mb = x
	ok(mb != null, "setup: a monster")
	if mb == null:
		return
	mb.grounded = true
	mb.tgt = null
	mb.pos = m.player.pos + Vector3(Mob.FAR_M + 15.0, 0, 0)
	mb._far_dt = 0.0
	var steps := 0
	var banked := 0.0
	for i in Mob.FAR_EVERY * 4:
		m.time += Match.DT
		var dt := mb._far_step(Match.DT)
		if dt > 0.0:
			steps += 1
			banked += dt
	var all := Match.DT * Mob.FAR_EVERY * 4
	ok(steps >= 4 and steps <= 5 and is_equal_approx(banked + mb._far_dt, all),
		"far away a monster steps every %d sim steps, no time lost (%d steps)" % [Mob.FAR_EVERY, steps])
	mb.pos = m.player.pos + Vector3(5.0, 0, 0)
	mb._far_dt = 0.0
	steps = 0
	for i in 6:
		m.time += Match.DT
		if mb._far_step(Match.DT) == Match.DT:
			steps += 1
	ok(steps == 6, "near the player it steps every sim step (%d of 6)" % steps)

## The world box of a mesh: its longest side in metres.
func _world_size(gi: GeometryInstance3D) -> float:
	var box := gi.get_aabb()
	var s := (gi.global_transform * box).size
	return maxf(s.x, maxf(s.y, s.z))

func _casts(gi: Node) -> bool:
	return (gi as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _nm(n: Node) -> String:
	return String(n.name).rstrip("0123456789@_")

func _under(n: Node, cls) -> Node:
	var up := n.get_parent()
	while up:
		if is_instance_of(up, cls): return up
		up = up.get_parent()
	return null

func _shadows() -> void:
	var lim := ShadowPolicy.min_size()
	# the helpers themselves
	var root := Node3D.new()
	var small := Models.part(root, Models.sphere(0.2), Models.toon(Color.WHITE))
	var big := Models.part(root, Models.box(3.0, 3.0, 3.0), Models.toon(Color.WHITE))
	ok(small.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "a small part (0.4 m) doesn't cast")
	ok(big.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "a big part (3 m) casts")
	root.free()
	for q in ["low", "medium", "high", "ultra"]:
		var qs := float(ShadowPolicy.MIN_SIZE.get(q, 0.0))
		ok(qs >= 1.0, "%s has a caster size (%.1f m)" % [q, qs])
	# the whole match: nothing small casts outside a Hunter (or a Boki's body)
	var bad := {}
	var n_cast := 0
	for gi in m.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not g.is_visible_in_tree():
			continue
		n_cast += 1
		# (scatter batches are judged per instance in World._chunked, tested below: a headless run's
		# multimesh keeps no instance transforms to measure)
		if _under(g, Hunter) or _under(g, Kin) or g is MultiMeshInstance3D:
			continue
		if _world_size(g) < lim:
			var k := "%s/%s/%s" % [_nm(g.get_parent().get_parent()), _nm(g.get_parent()), _nm(g)]
			bad[k] = int(bad.get(k, 0)) + 1
	ok(bad.is_empty(), "no mesh under %.1f m casts outside Hunters and Boki bodies (%d casters; small ones: %s)"
		% [lim, n_cast, str(bad).left(1500)])
	# scatter: rocks and trees split into casting (big) and non-casting (small) batches
	var rock := Models.box(1.0, 1.0, 1.0)
	var items := [[Transform3D(Basis().scaled(Vector3.ONE * 0.5), Vector3.ZERO), Color.WHITE],
		[Transform3D(Basis().scaled(Vector3.ONE * 2.5), Vector3.ZERO), Color.WHITE]]
	var parts := ShadowPolicy.split_instances(items, rock)
	ok((parts[0] as Array).size() == 1 and (parts[1] as Array).size() == 1 and is_same(parts[1][0], items[0]),
		"a 0.5 m rock goes in a non-casting batch, a 2.5 m one in a casting batch")
	var casting_chunks := 0
	for gi in m.world.find_children("rock_*", "MultiMeshInstance3D", true, false):
		var small_batch := String(gi.name).contains("_small_")
		if small_batch:
			ok(not _casts(gi), "small rock batch %s doesn't cast" % gi.name)
		elif _casts(gi):
			casting_chunks += 1
	ok(casting_chunks > 0, "big rocks cast (%d batches)" % casting_chunks)
	# effects
	m.fx.ring(m.player.pos, 2.0, Color.WHITE)
	m.fx.burst(m.player.pos, Color.WHITE)
	m.fx.bolt(m.player.pos, m.player.pos + Vector3(4, 1, 0), Color.WHITE)
	var fx_cast := 0
	for gi in m.fx.find_children("*", "GeometryInstance3D", true, false):
		if (gi as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: fx_cast += 1
	ok(fx_cast == 0, "no effect casts (%d do)" % fx_cast)
	# Hunters and walls do
	for h in m.hunters:
		var c := 0
		for gi in h.find_children("*", "MeshInstance3D", true, false):
			if _casts(gi) and (gi as Node3D).is_visible_in_tree():
				c += 1
		ok(c > 0, "%s casts (%d meshes)" % [h.pname, c])
	var walls := 0
	for gi in m.world.find_children("Walls_*", "GeometryInstance3D", true, false):
		if (gi as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: walls += 1
	ok(walls > 0, "walls cast (%d wall batches)" % walls)
	# a Boki: its body casts, its bits don't
	var kn := Models.kin(Data.KIN.keys()[0])
	var on := 0
	var off := 0
	for gi in kn.find_children("*", "GeometryInstance3D", true, false):
		if (gi as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: on += 1
		else: off += 1
	ok(on == 1 and off > 0, "a Boki: the body casts, the bits don't (%d cast, %d don't)" % [on, off])
	kn.free()

func _plates() -> void:
	var H = m.hud
	ok(H != null, "setup: the HUD")
	if H == null:
		return
	H.visible = true
	H.process_mode = Node.PROCESS_MODE_INHERIT
	var P: Hunter = m.player
	var rivals: Array = m.hunters.filter(func(x): return x != P)
	ok(rivals.size() >= 1, "setup: a rival")
	if rivals.is_empty():
		return
	var r: Hunter = rivals[0]
	r.unseen = false
	# near and on screen: laid out
	r.teleport(P.pos + Vector3(3.0, 0, 0))
	m.cam.snap(P.pos)
	m._process(0.0)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var f0 := Engine.get_process_frames()
	var at0 := int(LabelCull.laid.get(r.nid, -9))
	ok(at0 >= f0 - 2, "a rival on screen gets a plate (frame %d, now %d)" % [at0, f0])
	# far away: not laid out
	var spots := [["past %.0f m" % LabelCull.FAR_M, Vector3(LabelCull.FAR_M + 25.0, 0, 0)],
		["off screen", Vector3.ZERO]]
	for where in spots:
		var at: Vector3 = P.pos + where[1]
		if where[0] == "off screen":
			# inside FAR_M but beyond the screen's edge (and the slack)
			var rect: Rect2 = (H.c as CanvasItem).get_viewport_rect().grow(LabelCull.EDGE_PX)
			for d in range(8, int(LabelCull.FAR_M) - 2, 2):
				var tp := P.pos + Vector3(d, 0, 0)
				if not rect.has_point(m.cam.unproject_position(tp + Vector3(0, 2.3, 0))):
					at = tp
					break
			ok(at != P.pos, "setup: a spot off screen within %.0f m" % LabelCull.FAR_M)
		r.teleport(at)
		m.cam.snap(P.pos)
		m._process(0.0)
		await main.get_tree().process_frame
		var mark := Engine.get_process_frames()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		var at1 := int(LabelCull.laid.get(r.nid, -9))
		ok(at1 < mark, "a rival %s isn't laid out (last at frame %d, since %d)" % [where[0], at1, mark])
	# text: shaped once, reused while it stays the same
	var f: Font = HudStyle.BIG
	var a := TextCache.line(f, "Wild Pebblit", 16)
	var n0 := TextCache.shaped
	var b := TextCache.line(f, "Wild Pebblit", 16)
	ok(is_same(a, b) and TextCache.shaped == n0, "the same label reuses its layout")
	TextCache.line(f, "Wild Pebblit 2", 16)
	ok(TextCache.shaped == n0 + 1, "changed text is laid out once")

func _fx_pools() -> void:
	var fx: Fx = m.fx
	var kids := fx.get_child_count()
	var out := [fx.ring_pool.live(), fx.ghost_pool.live(), fx.beam_pool.live()]
	var tele: Array = []
	for i in 3:
		var at := Vector3(i, 0, 0)
		fx.ring(at, 3.0, Color.WHITE)
		fx.ghost(at, 0.0, Color.WHITE, 1.0)
		fx.bolt(at, at + Vector3(4, 1, 0), Color.CYAN)
		fx.beam(at, at + Vector3(5, 1, 0), Color.WHITE)
		tele.append(fx.telegraph_rect(at, Vector2.RIGHT, 3.0, 1.0, Color.RED))
	for t in tele:
		fx.end_telegraph(t)
	ok(fx.ring_pool.live() == int(out[0]) + 3, "a flurry takes pooled meshes (3 more rings out)")
	for i in 60:
		fx._process(0.02)
		await main.get_tree().process_frame
	ok(fx.get_child_count() == kids, "a flurry of rings, ghosts, bolts, beams and telegraphs adds no node to the Fx")
	var back: bool = fx.ring_pool.live() <= out[0] and fx.ghost_pool.live() <= out[1]
	back = back and fx.beam_pool.live() <= out[2]
	ok(back,
		"the flurry's ring, ghost and beam meshes (a bolt is beams) are all back in their pools")

## Baked occluders (Occluders): on for Medium and up, off at Low; on a big map the boxes stay under the
## ground and above the underside (so they never hide what shows), large rocks get a box inside them,
## small rocks none, and a small map gets nothing.
func _occluders() -> void:
	var low: bool = Settings.QUALITY["low"]["occlusion"]
	ok(not low and bool(Settings.QUALITY["medium"]["occlusion"]), "occlusion culling is off at Low, on at Medium")
	var W := m.world
	var holder := Node3D.new()
	main.add_child(holder)
	await Occluders.build(W, holder, {})
	var oi := holder.get_node_or_null("Occluders") as OccluderInstance3D
	ok(W.w < Occluders.MIN_MAP or oi != null, "a %d-tile map gets an occluder" % W.w)
	if oi != null:
		var arr := (oi.occluder as ArrayOccluder3D)
		var verts := arr.vertices
		var bad := 0
		for p in verts:
			# a corner on a tile border is judged by the highest ground of the four tiles around it
			var g := -INF
			for d in [Vector2(-0.01, -0.01), Vector2(0.01, -0.01), Vector2(-0.01, 0.01), Vector2(0.01, 0.01)]:
				g = maxf(g, W.ground_at(p.x + d.x, p.z + d.y))
			if p.y > g + 0.01: bad += 1
		ok(bad == 0, "no occluder corner above the ground (%d boxes' %d corners)" % [verts.size() / 8, verts.size()])
		ok(arr.indices.size() / 3 <= 24000, "%d occluder triangles stay under the budget" % (arr.indices.size() / 3))
		var sunk := 0
		for p in verts:
			var ti := W.idx(clampi(int(p.x), 0, W.w - 1), clampi(int(p.z), 0, W.h - 1))
			if W.kind[ti] != World.T_VOID and p.y < W.under[ti] - 0.01: sunk += 1
		ok(sunk == 0, "no occluder corner below its island's underside")
	holder.free()
	var at := [Transform3D(Basis.IDENTITY, Vector3(5, 2, 5)), Color.WHITE]
	var rock := {"k": {"mesh": Models.box(3.0, 3.0, 3.0), "label": "rock_a", "items": [at]},
		"s": {"mesh": Models.box(1.0, 1.0, 1.0), "label": "rock_b", "items": [at]}}
	var o := Occluders.new()
	o._w = W
	o._rocks(rock)
	ok(o._verts.size() == 8, "a 3 m rock gets one box and a 1 m rock none (%d corners)" % o._verts.size())
	var inside := true
	for p in o._verts:
		if absf(p.x - 5.0) > 1.5 or absf(p.y - 2.0) > 1.5 or absf(p.z - 5.0) > 1.5: inside = false
	ok(inside, "the rock's box is inside its bounds")
