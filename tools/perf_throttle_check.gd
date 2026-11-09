extends RefCounted
## --perf-throttle-check, item 94's script throttles: an idle monster with nobody within Mob.NAP_M stops
## simulating and wakes when a Hunter comes close; a bot further than Bot.FAR_M from the local player decides
## and roaming decides every Bot.FAR_EVERY steps (the skipped time added in), a near one every step.
## Shadows (ShadowPolicy): no mesh smaller than the preset's caster size casts (Hunters and each Boki's
## body excepted), effects never do, Hunters and walls do. World labels (LabelCull, TextCache): a plate
## off screen or past LabelCull.FAR_M isn't laid out, an on-screen one is, and a label's text is shaped
## once and reused until it changes. SpawnPlan's sight checks are spread over frames.

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
	_shadows()
	_spawn_sight()
	await _plates()
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

func _far_bots() -> void:
	var b: Hunter = null
	for h in m.hunters:
		if h.ctrl == "bot":
			b = h
	ok(b != null, "setup: a bot")
	if b == null:
		return
	var brain := Bot.new()
	b.teleport(m.player.pos + Vector3(Bot.FAR_M + 15.0, 0, 0))
	b.ai["tgt"] = null
	b.ai["goal_kind"] = "roam"
	var thinks := 0
	for i in Bot.FAR_EVERY * 4:
		var before := float(b.ai["dash_cd"])
		brain.tick(m, b, Match.DT)
		if float(b.ai["dash_cd"]) != before:
			thinks += 1
	ok(thinks == 4, "far away it decides every %d steps (%d decisions)" % [Bot.FAR_EVERY, thinks])
	b.teleport(m.player.pos + Vector3(5.0, 0, 0))
	thinks = 0
	for i in 6:
		var before := float(b.ai["dash_cd"])
		brain.tick(m, b, Match.DT)
		if float(b.ai["dash_cd"]) != before:
			thinks += 1
	ok(thinks == 6, "near the player it decides every step (%d of 6)" % thinks)

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
			var k := "%s/%s" % [_nm(g.get_parent()), _nm(g)]
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
