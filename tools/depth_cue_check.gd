extends RefCounted
## --depth-cue-check: the height cues of briefs/CAMERA_DEPTH.md exist and stay cheap. Headless, no
## renderer: a live match has the ledge-light terrain shader (depth_k on, with ledges for it to light),
## the dimmed abyss clouds, a shadow disc on the ground under every hunter and under every flying shot
## (at the ground's height, hidden over the void), and a per-frame cost within budget with no new
## nodes once warmed up. With the setting off the terrain and cloud cues read as off. Never touches the save.

const SHOTS := 120              # shots in the air at once for the cost test (the pool holds 160)
const SHOT_LIFT := 1.5          # m above the ground the test shots fly
const BUDGET_US := 2000.0       # us per frame for all discs (hunters + SHOTS shots), a generous headless bound
const FRAMES := 30              # frames averaged for the cost

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("DEPTHCUECHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	await _check_match(main)
	Settings.set_v("depth_cues", false, false)
	ok(DepthCues.k() == 0.0 and DepthCues.abyss_dim() == 1.0, "setting off: no terrain cues, abyss not dimmed")
	Settings.set_v("depth_cues", true, false)
	print("DEPTHCUECHECK done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _check_match(main: Node) -> void:
	Settings.set_v("depth_cues", true, false)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var dc: DepthCues = m.get_node_or_null("DepthCues")
	ok(dc != null, "the DepthCues node is in the match")
	if dc == null:
		return
	_check_ledge_light(m)
	_check_abyss(m)
	_check_hunter_discs(m, dc)
	_check_shot_discs(m, dc)
	m.queue_free()

func _find_material(root: Node, shader_file: String) -> ShaderMaterial:
	if root is GeometryInstance3D:
		var mat := (root as GeometryInstance3D).material_override as ShaderMaterial
		if mat != null and mat.shader != null and mat.shader.resource_path.ends_with(shader_file):
			return mat
	for c in root.get_children():
		var found := _find_material(c, shader_file)
		if found != null:
			return found
	return null

func _check_ledge_light(m: Match) -> void:
	var terrain := _find_material(m.world, "terrain.gdshader")
	ok(terrain != null and float(terrain.get_shader_parameter("depth_k")) == 1.0, "terrain shader has the ledge light on (depth_k 1)")
	ok(terrain != null and terrain.shader.code.contains("depth_cues("), "terrain shader carries the cliff shading and lip light")
	var w := m.world
	var ledges := 0
	for z in range(1, w.h - 1):
		for x in range(1, w.w - 1):
			var i := w.idx(x, z)
			if w.kind[i] == World.T_GROUND and w.kind[w.idx(x + 1, z)] == World.T_VOID:
				ledges += 1
	ok(ledges > 0, "the map has ground ending in a drop for the light to catch (%d tiles)" % ledges)

func _check_abyss(m: Match) -> void:
	var clouds := _find_material(m.world, "clouds.gdshader")
	ok(clouds != null and is_equal_approx(float(clouds.get_shader_parameter("abyss_dim")), DepthCues.ABYSS_DIM), "abyss cloud sea is dimmed to %.2f" % DepthCues.ABYSS_DIM)

func _check_hunter_discs(m: Match, dc: DepthCues) -> void:
	dc._process(0.0)
	var live := 0
	for i in m.hunters.size():
		var h: Hunter = m.hunters[i]
		var disc: MeshInstance3D = dc._discs.get(h)
		ok(disc != null, "a shadow disc for hunter %d" % i)
		if disc == null or not disc.visible:
			continue
		live += 1
		var y := m.world.ground_at(h.global_position.x, h.global_position.z)
		ok(absf(disc.global_position.y - (y + DepthCues.LIFT)) < 0.001, "hunter %d's disc lies on the ground (y %.2f)" % [i, y])
	ok(live > 0, "at least one hunter's disc is visible on the ground")

func _check_shot_discs(m: Match, dc: DepthCues) -> void:
	var P: Hunter = m.player
	var ground := m.world.ground_at(P.pos.x, P.pos.z)
	for i in SHOTS:
		m.spawn_shot(P, Vector3(P.pos.x, ground + SHOT_LIFT, P.pos.z), Vector2(1, 0), 1.0, 5.0, 0.1, Color.WHITE)
	var t0 := Time.get_ticks_usec()
	for f in FRAMES:
		dc._process(0.0)
	var per_frame := float(Time.get_ticks_usec() - t0) / FRAMES
	var shown := dc._shot_discs.filter(func(d): return d.visible)
	ok(shown.size() == SHOTS, "one visible disc per flying shot (%d of %d)" % [shown.size(), SHOTS])
	ok(shown.all(func(d): return absf(d.global_position.y - (ground + DepthCues.LIFT)) < 0.001), "every shot's disc lies on the ground under it (y %.2f)" % ground)
	ok(per_frame <= BUDGET_US, "discs cost %.0f us per frame for %d hunters + %d shots (budget %.0f)" % [per_frame, m.hunters.size(), SHOTS, BUDGET_US])
	var warm := dc.get_child_count()
	dc._process(0.0)
	ok(dc.get_child_count() == warm, "no nodes added once warmed up")
	for s in m.shots.duplicate():
		m._shot_end(s, s["pos"], null)
	dc._process(0.0)
	ok(dc._shot_discs.all(func(d): return not d.visible), "shot discs hide when the shots are gone")
