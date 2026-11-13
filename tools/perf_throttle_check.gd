extends RefCounted
## --perf-throttle-check, item 94's script throttles: an idle monster with nobody within Mob.NAP_M stops
## simulating and wakes when a Hunter comes close; a bot further than SimLod.FAR_M from the local player, on
## the ground, roaming or fighting something as far off, thinks and simulates every SimLod.EVERY steps (the
## skipped time added in, and walking on open ground it keeps to the ground (never over the abyss or in
## a rock) on the path a full-rate bot walks); a near one, one fighting near the player or just hit by
## them, every step; its Boki steps with it. A calm one past SimLod.THINK_FAR_M picks goals
## SimLod.THINK_FAR_K times less often; a bot aboard the sky ship picks nothing. A bot in a fight re-tests
## its line of sight to the same target every Bot.LOS_RECHECK_S (a new target at once).
## Shadows (ShadowPolicy): no mesh smaller than the preset's caster size casts (Hunters and each Boki's
## body excepted), effects never do, Hunters and walls do. World labels (LabelCull, TextCache): a plate
## off screen or past LabelCull.FAR_M isn't laid out, an on-screen one is, and a label's text is shaped
## once and reused until it changes. Skinned rigs (RigPace): every frame off GL over Metal; at RigPace.EVERY a
## Warden away from the camera's focus is posed every few frames with the held time, the one at the focus every frame.

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
	_far_mobs()
	_bot_los()
	_shadows()
	await _plates()
	await _rig_pace()
	print("PERFTHROTTLE DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _step(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

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

func _bot_los() -> void:
	var b: Hunter = null
	for h in m.hunters:
		if h.ctrl == "bot":
			b = h
	ok(b != null, "setup: a bot for the line-of-sight cache")
	if b == null:
		return
	var brain: Bot = m.bot_brain
	var first := brain.los_to(m, b, m.player, Match.DT)
	var real := first == brain.can_hit(m, b, m.player)
	ok(b.ai["los_tgt"] == m.player and real, "a bot's first look at a target is a real line-of-sight test")
	b.ai["los"] = not first
	var trusted := brain.los_to(m, b, m.player, Match.DT) == (not first)
	ok(trusted, "within %.1f s it trusts its last look" % Bot.LOS_RECHECK_S)
	var mb: Mob = m.mobs[0]
	var fresh := brain.los_to(m, b, mb, Match.DT)
	ok(b.ai["los_tgt"] == mb and fresh == brain.can_hit(m, b, mb), "a new target is looked at at once")
	b.ai["los"] = not fresh
	var again := fresh
	for i in int(Bot.LOS_RECHECK_S / Match.DT) + 1:
		again = brain.los_to(m, b, mb, Match.DT)
	var looked := again == brain.can_hit(m, b, mb)
	ok(looked, "after %.1f s on the same target it looks again" % Bot.LOS_RECHECK_S)

func _far_bots() -> void:
	var b: Hunter = null
	for h in m.hunters:
		if h.ctrl == "bot":
			b = h
	ok(b != null, "setup: a bot")
	if b == null:
		return
	b.ai["tgt"] = null
	b.ai["goal_kind"] = "roam"
	var every := SimLod.EVERY
	_far_walks(b)
	var spot := _spot(SimLod.FAR_M + 10.0, SimLod.THINK_FAR_M - 10.0, 0)
	ok(spot != Vector3.INF, "setup: open ground %.0f-%.0f m off" % [SimLod.FAR_M + 10.0, SimLod.THINK_FAR_M - 10.0])
	_place(b, spot)
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
	spot = _spot(SimLod.THINK_FAR_M + 10.0, SimLod.THINK_FAR_M + 60.0, 0)
	ok(spot != Vector3.INF, "setup: open ground past %.0f m" % (SimLod.THINK_FAR_M + 10.0))
	_place(b, spot)
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
	_place(b, m.player.pos + Vector3(5.0, 0, 0))
	ok(_lod_steps(b, 6)[0] == 6, "near the player it steps every step")

const WALK_TRIES := 6       # walks from open ground far off, each a different heading
const WALK_STEPS := 240     # sim steps a walk (4 s)
const WALK_PATH_M := 0.5    # m a throttled walk may end from the same walk at the full rate
const WALK_RUNS_K := 1.3    # steps run may be this much over 1 in EVERY (off the ground it runs every step)

## Walks a far bot from open ground (and once up a flight of stairs) at the full rate and throttled: the
## throttled one runs about one step in EVERY, stays on the ground (on it when grounded, never over the
## abyss or in a rock) and ends where the full-rate walk does.
func _far_walks(b: Hunter) -> void:
	var w: World = m.world
	var lo := SimLod.FAR_M + 10.0
	var hi := SimLod.THINK_FAR_M - 10.0
	var walks := []
	for t in WALK_TRIES:
		var at := _spot(lo, hi, t * 4)
		if at != Vector3.INF:
			walks.append([at, Vector2.RIGHT.rotated(TAU * t / WALK_TRIES)])
	var stair := _stair_walk(lo, hi)
	ok(not stair.is_empty(), "setup: a flight of stairs %.0f-%.0f m off" % [lo, hi])
	if not stair.is_empty():
		walks.append(stair)
	var runs := 0
	var steps := 0
	var bad := 0
	var worst := 0.0
	for walk in walks:
		var at: Vector3 = walk[0]
		var heading: Vector2 = walk[1]
		var ends := []
		for lod in [false, true]:
			_place(b, at)
			for i in WALK_STEPS:
				b.inp["move"] = heading
				m.time += Match.DT
				SimLod.plan(m, Match.DT)
				var sd := SimLod.step_dt(b, Match.DT) if lod else Match.DT
				if sd > 0.0:
					b.sim(sd)
					runs += int(lod)
				steps += int(lod)
				var off := b.grounded and absf(b.pos.y - b.ground()) > 0.001
				if lod and (off or b.over_void() or w.is_block(b.pos.x, b.pos.z)):
					bad += 1
			ends.append(b.pos)
		worst = maxf(worst, (ends[0] as Vector3).distance_to(ends[1]))
	b.inp["move"] = Vector2.ZERO
	ok(steps > 0 and runs * SimLod.EVERY <= steps * WALK_RUNS_K,
		"walking far off it runs about 1 in %d steps (%d of %d)" % [SimLod.EVERY, runs, steps])
	ok(steps > 0 and bad == 0,
		"throttled, it walks on the ground, never over the abyss or in a rock (%d bad steps)" % bad)
	ok(steps > 0 and worst <= WALK_PATH_M, "throttled, it walks the full-rate path (ends %.2f m apart)" % worst)

## A flight of stairs lo-hi m (flat) from the player: [the ground 2 m before its foot, the heading up
## it], or [] if there is none.
func _stair_walk(lo: float, hi: float) -> Array:
	var w: World = m.world
	for i in w.stairs:
		var up: Vector2i = w.stairs[i]
		var foot := Vector3(i % w.w + 0.5 - up.x * 2.0, 0.0, i / w.w + 0.5 - up.y * 2.0)
		var r := Vector2(foot.x - m.player.pos.x, foot.z - m.player.pos.z).length()
		if r > lo and r < hi and not w.is_void(foot.x, foot.z) and not w.is_block(foot.x, foot.z):
			foot.y = w.ground_at(foot.x, foot.z)
			return [foot, Vector2(up)]
	return []

## Open ground lo-hi m (flat) from the player, from the map's own spot query (clear of rocks, walls and
## the abyss); the ring is searched from heading `turn` (of 24). INF if there is none.
func _spot(lo: float, hi: float, turn: int) -> Vector3:
	var w: World = m.world
	for d in range(int(lo) + 2, int(hi) - 2, 3):
		for a in 24:
			var p: Vector3 = m.player.pos + Vector3(d, 0, 0).rotated(Vector3.UP, TAU * float((a + turn) % 24) / 24.0)
			var s := w.free_spot_near(p, [], 1.0, 0.45, 2.0)
			if not w.is_void(s.x, s.z) and not w.is_block(s.x, s.z):
				return s
	return Vector3.INF

## A bot standing still on the ground at `at` (a teleport leaves grounded as it was; the model's step-up
## ease runs in render frames, which a walk here has none of).
func _place(b: Hunter, at: Vector3) -> void:
	b.teleport(at)
	b.grounded = true
	b.vel = Vector3.ZERO
	b.step_vis = 0.0
	b.ai["lod_dt"] = 0.0

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

func _rig_pace() -> void:
	var syncs := m.find_children("Sync", "Node", true, false).filter(func(n): return n is WardenGlb.Sync)
	ok(not syncs.is_empty(), "the match has Warden rigs (%d)" % syncs.size())
	if syncs.is_empty():
		return
	var want := RigPace.EVERY if RigPace.dear() else 1
	ok(syncs.all(func(sy): return sy.pace.every == want), "each rig's pace fits the driver")
	var sy: WardenGlb.Sync = syncs[0]
	sy.set_process(false)
	sy.pace.every = RigPace.EVERY
	sy.pace.held = 0.0
	m.cam.focus = sy.root.global_position + Vector3(RigPace.LEAD_M * 4.0, 0, 0)
	var posed := 0
	for i in RigPace.EVERY * 2:
		await main.get_tree().process_frame
		sy._process(0.01)
		if sy.pace.held == 0.0:
			posed += 1
	ok(posed == 2, "a Warden away from the focus is posed on %d of %d frames" % [posed, RigPace.EVERY * 2])
	m.cam.focus = sy.root.global_position
	posed = 0
	for i in RigPace.EVERY * 2:
		await main.get_tree().process_frame
		sy._process(0.01)
		if sy.pace.held == 0.0:
			posed += 1
	ok(posed == RigPace.EVERY * 2, "the one at the camera's focus every frame (%d)" % posed)
	sy.pace.every = want
	sy.set_process(true)
