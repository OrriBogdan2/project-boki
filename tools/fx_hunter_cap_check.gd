extends RefCounted
## --fx-hunter-cap-check: a glow sphere (shaders/glowball.gdshader) within FxHunterCap.NEAR_R of a Hunter is drawn at
## most MAX_SIZE across and at NEAR_ALPHA of its alpha, and gets its own size and alpha back once it is away; a smoke
## cloud's puffs part round a Hunter (hidden within their radius plus PUFF_CLEAR) and come back when it leaves.
## Headless, no renderer; never touches the save.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("FXHUNTERCAPCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var cap: FxHunterCap = m.get_node_or_null("FxHunterCap")
	ok(cap != null, "the FxHunterCap node is in the match")
	if cap == null:
		main.get_tree().quit(1)
		return
	var h: Hunter = m.player
	var orb := Models.part(m, Models.sphere(1.5), Models.glow_mat(Color(1, 0.4, 0.8)), h.pos + Vector3(0.5, 1.0, 0))
	var small := Models.part(m, Models.sphere(0.2), Models.glow_mat(Color.WHITE), h.pos + Vector3(0.5, 1.0, 0))
	cap._rescan()
	cap._process(0.016)
	var sz := (orb.global_transform * orb.get_aabb()).size
	ok(maxf(sz.x, maxf(sz.y, sz.z)) <= FxHunterCap.MAX_SIZE + 0.01, "a 3 m orb on a Hunter is capped (%.2f m)" % sz.x)
	ok(
		is_equal_approx(float(orb.get_instance_shader_parameter(FxHunterCap.PARAM)), FxHunterCap.NEAR_ALPHA),
		"its alpha is cut"
	)
	ok(small.scale.is_equal_approx(Vector3.ONE), "a small glow keeps its size")
	orb.global_position = h.pos + Vector3(30, 1.0, 0)
	cap._process(0.016)
	ok(orb.scale.is_equal_approx(Vector3.ONE), "away from every Hunter the orb has its own size back")
	ok(is_equal_approx(float(orb.get_instance_shader_parameter(FxHunterCap.PARAM)), 1.0), "and its full alpha")
	var smoke := Models.gear_smoke()
	m.add_child(smoke)
	m.smokes.append({"pos": h.pos, "r": 3.6, "t": 8.0, "node": smoke})
	var on := smoke.get_child(0) as MeshInstance3D
	var off := smoke.get_child(1) as MeshInstance3D
	on.global_position = h.pos + Vector3(0.4, 1.0, 0)
	off.global_position = h.pos + Vector3(9.0, 1.0, 0)
	cap._process(0.016)
	ok(not on.visible, "a smoke puff on a Hunter parts")
	ok(off.visible, "a puff away from every Hunter stays")
	ok(m.in_smoke(h.pos), "the Hunter is still in smoke for concealment")
	on.global_position = h.pos + Vector3(9.0, 1.0, 3.0)
	cap._process(0.016)
	ok(on.visible, "the puff is back once the Hunter is clear of it")
	print("FXHUNTERCAPCHECK done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
