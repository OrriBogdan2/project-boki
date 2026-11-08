extends Node3D
## Tooling: the authored expedition map from straight above (or at an angle), with its place names.
## Run with -- --map-overview [--map-angle] --shot=out.png --frames=N

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0})
	add_child(env)
	Look.lights(self, Color("fff1dc"), 1.0, Vector3(-55, -30, 0), 60.0)
	var w := World.new()
	w.biome = Data.TIERS[0]["biome"].duplicate()
	w.clouds = Data.TIERS[0]["clouds"]
	add_child(w)
	w.generate_authored(World.load_layout(_map_id()), 7)
	w.build_meshes()
	var ground := Array(OS.get_cmdline_user_args()).any(func(a): return String(a).begins_with("--map-ground="))
	for lb in ([] if ground else w.labels):      # (eye-height shots: names through walls would clutter them)
		var l := Label3D.new()
		l.text = String(lb["name"])
		l.font = UI.big; l.font_size = 64 if lb["kind"] == "poi" else 40; l.pixel_size = 0.06; l.outline_size = 16
		l.modulate = Color("fff4d8") if lb["kind"] == "poi" else (Color("ffe2a0") if lb["kind"] == "rail" else Color("ffb36a"))
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
		l.position = (lb["pos"] as Vector3) + Vector3(0, 6, 0)
		add_child(l)
	if not w.train_route.is_empty():
		# the sky train's loop, as a dotted amber line
		var s := 0.0
		while s < float(w.train_route["len"]):
			var q := w.train_at(s)
			var d := MeshInstance3D.new(); d.mesh = Models.box(0.9, 0.3, 0.9)
			d.material_override = Models.glow_mat(Color(1.0, 0.75, 0.35, 0.9 if q.y > -1.0 else 0.4))
			d.position = q
			add_child(d)
			s += 2.0
	for p in w.portal_spots:
		var m := MeshInstance3D.new(); m.mesh = Models.cyl(1.4, 1.4, 6.0, 12)
		m.material_override = Models.glow_mat(Color("8fe3c8")); m.position = p + Vector3(0, 3, 0)
		add_child(m)
	var cam := Camera3D.new()
	if "--map-angle" in OS.get_cmdline_user_args():
		cam.position = Vector3(112, 24, 141); cam.rotation = Vector3(-0.95, 0, 0); cam.fov = 42
	else:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = w.w + 6.0     # the whole map and a 3 m margin
		cam.position = Vector3(w.w * 0.5, 120, w.h * 0.5); cam.rotation = Vector3(-PI / 2, 0, 0)
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--map-ground="):
			_ground_shots(w, cam, String(a).substr(13))

## --map-ground=<dir>: the top-down view as <dir>/top.png, then one eye-height shot per region as
## <dir>/<region id>.png, then quit. The
## camera stands GROUND_BACK m out from the region's first island's point of interest (on the side
## away from the map centre, or the near side if that's void) and looks at it.
const GROUND_BACK := 22.0    # m: far enough back to see the landmark and its surroundings
func _ground_shots(w: World, cam: Camera3D, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _save(dir.path_join("top.png"))
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE; cam.fov = 70.0
	var mid := Vector2(w.w * 0.5, w.h * 0.5)
	for r in w.regions:
		var isl: Dictionary = {}
		for I in w.islands:
			if I.get("id", "") == String((r["islands"] as Array)[0]): isl = I
		if isl.is_empty():
			continue
		var poi: Vector2 = isl["poi_at"]
		var out := (poi - mid).normalized() if poi.distance_to(mid) > 1.0 else Vector2.DOWN
		var at := poi + out * GROUND_BACK
		if w.is_void(at.x, at.y):
			at = poi - out * GROUND_BACK
		var gy := w.ground_at(at.x, at.y)
		cam.position = Vector3(at.x, (gy if gy > World.VOID else 0.0) + 1.8, at.y)
		cam.look_at(Vector3(poi.x, w.ground_at(poi.x, poi.y) + 2.0, poi.y))
		await _save(dir.path_join(String(r["id"]) + ".png"))
		print("GROUND ", r["id"], " at ", at)
	get_tree().quit()

## Lets the view settle a few frames, then saves it (headless draws nothing: no file).
func _save(path: String) -> void:
	for _f in 8:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)

## --map=<id> picks the layout (default: the expedition map, World.layout_for_tier(0)).
func _map_id() -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--map="): return String(a).substr(6)
	return World.layout_for_tier(0)
