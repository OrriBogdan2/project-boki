extends RefCounted
## --kin-shots --shots-dir=<dir> [--species=pebbit,cindle] [--px=1024] [--procedural]: a Boki's model sheet and
## review shots (docs/art/kin/PIPELINE.md). Per species, under <dir>/<id>/:
##   flat_front/three_quarter/side/back.png, flat_face.png and flat_sheet.png: flat even light on plain grey, one
##     camera for every view (the inputs for the 3D run, and the old-vs-new comparison);
##   day_*.png and night_*.png: the same views and the face under the game's day light and a dark-biome night;
##   match.png: the match camera (pitch 66, 23 m, fov 32), true pixels then enlarged 3x.
## --procedural shoots the KinModels primitives of a species that has a model (the "old" in old-vs-new).
## Needs a renderer.

const VIEWS := {"front": PI, "three_quarter": PI * 0.75, "side": PI * 0.5, "back": 0.0}
const FACE_FOV := 24.0     # degrees: the face shot is a tighter lens aimed at the head
const MATCH_PITCH := 66.0
const MATCH_DIST := 23.0
const MATCH_FOV := 32.0
const ENLARGE := 3

func run(main: Node) -> void:
	var out := ""
	var ids := ["pebbit"]
	var px := 1024
	var procedural := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--species="): ids = Array(a.substr(10).split(","))
		if a.begins_with("--px="): px = int(a.substr(5))
		if a == "--procedural": procedural = true
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	for id in ids:
		var dir := out.path_join(String(id))
		DirAccess.make_dir_recursive_absolute(dir)
		for stage in ["flat", "day", "night"]:
			await _shoot(main, String(id), dir, stage, px, procedural)
		await _match(main, String(id), dir, procedural)
	print("KIN_SHOTS_DONE")
	main.get_tree().quit()

func _viewport(main: Node, px: Vector2i, stage: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = px
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var env := WorldEnvironment.new()
	vp.add_child(env)
	if stage == "flat":
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("c9c9c9")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.7
		var key := DirectionalLight3D.new()       # one soft light from the camera side: flat, no shadows
		key.rotation_degrees = Vector3(-25, 0, 0)
		key.light_energy = 0.8
		vp.add_child(key)
	elif stage == "night":
		env.environment = Look.environment({"top": Color("0b0f24"), "mid": Color("141a3a"), "horizon": Color("1d2347"),
			"stars": 0.6, "ambient": Color("2a3358"), "ambient_energy": 0.35})
		Look.lights(vp, Color("6f86c8"), 0.45, Vector3(-50, 145, 0), 40.0)
	else:
		env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"),
			"horizon": Color("ffd2a8"), "stars": 0.0})
		Look.lights(vp, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	return vp

func _ground(vp: Node, stage: String) -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("2f4a3a") if stage == "night" else Color("4f7a3e"), false)
	vp.add_child(ground)

func _kin(species: String, procedural: bool) -> Node3D:
	KinGlb.enabled = not procedural
	return Models.kin(species)

func _shoot(main: Node, species: String, dir: String, stage: String, px: int, procedural: bool) -> void:
	var vp := _viewport(main, Vector2i(px, px), stage)
	if stage != "flat":
		_ground(vp, stage)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	var kin := _kin(species, procedural)
	vp.add_child(kin)
	var strip := Image.create(px * VIEWS.size(), px, false, Image.FORMAT_RGBA8)
	var i := 0
	for nm in VIEWS:
		kin.rotation.y = VIEWS[nm]
		cam.fov = 28.0
		cam.position = Vector3(0, 0.42, 3.4)
		cam.look_at(Vector3(0, 0.36, 0))
		var img := await _grab(vp)
		img.save_png(dir.path_join("%s_%s.png" % [stage, nm]))
		strip.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(i * px, 0))
		i += 1
	strip.save_png(dir.path_join("%s_sheet.png" % stage))
	kin.rotation.y = 0.0
	var head: Vector3 = KinGlb.FRAME.get(species, {"head": Vector3(0, 0.28, -0.36)})["head"]
	cam.fov = FACE_FOV
	cam.position = head + Vector3(0.0, 0.04, -1.4)
	cam.look_at(head)
	(await _grab(vp)).save_png(dir.path_join("%s_face.png" % stage))
	vp.queue_free()

func _match(main: Node, species: String, dir: String, procedural: bool) -> void:
	var vp := _viewport(main, Vector2i(1280, 720), "day")
	_ground(vp, "day")
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	var kin := _kin(species, procedural)
	kin.rotation.y = PI * 0.8
	vp.add_child(kin)
	var p := deg_to_rad(MATCH_PITCH)
	cam.fov = MATCH_FOV
	cam.position = Vector3(0, sin(p), cos(p)) * MATCH_DIST
	cam.rotation = Vector3(-p, 0, 0)
	var img := await _grab(vp)
	var mid := Vector2i(cam.unproject_position(Vector3(0, 0.3, 0)))
	var crop := img.get_region(Rect2i(mid - Vector2i(64, 48), Vector2i(128, 96)))
	var big := crop.duplicate() as Image
	big.resize(crop.get_width() * ENLARGE * 2, crop.get_height() * ENLARGE * 2, Image.INTERPOLATE_NEAREST)
	big.save_png(dir.path_join("match.png"))
	vp.queue_free()

func _grab(vp: SubViewport) -> Image:
	for k in 6:
		await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
