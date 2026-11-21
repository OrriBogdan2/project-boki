extends SceneTree
## Not committed (job tool). In-game look film of a rigged glb set, for hybrid-rig-Meeko-1121.
## Match look: Look.environment built like match.gd _build_env() from tier 0 (The Meadow) colours, Look.lights at
## (-55,-35,0) with shadow opacity 0.8, ground = shaders/terrain.gdshader with meadow top/top2 vertex colours.
## Views: "game" = the match camera (cam.gd pitch 57 deg, dist 32.2) with a narrow lens (native crop, no upscale);
## "eye" = eye level 3/4 front. args: OUTDIR glb1,glb2,... --n=20 --px=1080

const SKY := Color("10131f")
const AMB := Color("b9c4e6")
const SUN := Color("fff1dc")
const CL0 := Color(0.06, 0.07, 0.13)
const CL1 := Color(0.22, 0.24, 0.38)
const TOP := Color("5f8d45")
const TOP2 := Color("4a7538")

var out := ""
var glbs: PackedStringArray = []
var n := 20
var px := 1080


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	glbs = a[1].split(",")
	for s in a:
		if s.begins_with("--n="):
			n = int(s.substr(4))
		if s.begins_with("--px="):
			px = int(s.substr(5))
	DisplayServer.window_set_size(Vector2i(int(px * 0.75), px))
	root.size = Vector2i(int(px * 0.75), px)
	_run.call_deferred()


func _ground() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 30
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for z in range(-r, r):
		for x in range(-r, r):
			var q := [Vector3(x, 0, z), Vector3(x + 1, 0, z), Vector3(x + 1, 0, z + 1), Vector3(x, 0, z + 1)]
			var c := TOP.lerp(TOP2, rng.randf() * 0.6)
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_color(c)
				st.set_normal(Vector3.UP)
				st.add_vertex(q[i])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	mi.material_override = m
	return mi


func _run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": SKY.darkened(0.2), "mid": SKY.lerp(AMB, 0.35), "horizon": CL1.lerp(SUN, 0.5).lightened(0.15),
		"below": CL0, "ambient": AMB, "ambient_energy": 0.5, "fog": CL1.lightened(0.12).lerp(Color("4a5aa8"), 0.35), "sun_col": SUN})
	w.add_child(env)
	var sun := Look.lights(w, SUN, 1.0, Vector3(-55, -35, 0), 60.0)
	sun.shadow_opacity = 0.8
	w.add_child(_ground())
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.current = true
	for gi in glbs.size():
		var doc := GLTFDocument.new()
		var gs := GLTFState.new()
		if doc.append_from_file(glbs[gi], gs) != OK:
			print("FILM_ERR load ", glbs[gi])
			continue
		var sc := doc.generate_scene(gs)
		w.add_child(sc)
		var ap: AnimationPlayer = sc.find_children("*", "AnimationPlayer", true, false)[0]
		for an in ap.get_animation_list():
			var parts := an.split("|")
			var nm := (parts[1] if parts.size() >= 3 else an).replace(" ", "_")
			var dur := ap.get_animation(an).length
			ap.play(an)
			ap.pause()
			for v in ["game", "eye"]:
				var d := "%s/%d_%s/%s" % [out, gi, nm, v]
				DirAccess.make_dir_recursive_absolute(d)
				if v == "game":
					var p := deg_to_rad(57.0)
					cam.fov = 3.8
					cam.position = Vector3(0, 0.9 + 32.2 * sin(p), 32.2 * cos(p))
					cam.look_at(Vector3(0, 0.9, 0))
				else:
					var yaw := deg_to_rad(28.0)
					cam.fov = 30.0
					cam.position = Vector3(5.0 * sin(yaw), 1.05, 5.0 * cos(yaw))
					cam.look_at(Vector3(0, 0.95, 0))
				for f in n:
					ap.seek(dur * f / float(n), true)
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_jpg("%s/f%03d.jpg" % [d, f], 0.92)
			print("FILM_CLIP ", gi, " ", nm)
		sc.queue_free()
		await process_frame
	print("FILM_DONE")
	quit()
