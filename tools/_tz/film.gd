extends SceneTree
## godot --path TREE -s res://tools/_tz/film.gd -- OUT GLB[,GLB...] [--n=20] [--px=1080]
## Renders every clip of each glb on the match look: Look.environment with tier-0 match params, Look.lights (match
## sun fff1dc, rot -55,-35), the island terrain shader on a ground plane (biome top colour), the match camera's pitch
## 57 deg at its 32.2 m distance (lens narrowed = a native crop of the game view, no upscale) and an eye-level camera.
var out := ""
var px := 1080
var n := 20

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var glbs := a[1].split(",")
	for x in a:
		if x.begins_with("--n="): n = int(x.substr(4))
		if x.begins_with("--px="): px = int(x.substr(5))
	DisplayServer.window_set_size(Vector2i(px * 3 / 4, px))
	root.size = Vector2i(px * 3 / 4, px)
	_run.call_deferred(glbs)

func _run(glbs: PackedStringArray) -> void:
	var holder := Node3D.new(); root.add_child(holder)
	var T := {"sky": Color("10131f"), "ambient": Color("b9c4e6"), "sun": Color("fff1dc"), "clouds": [Color(0.06, 0.07, 0.13), Color(0.22, 0.24, 0.38)]}
	var sky: Color = T["sky"]; var amb: Color = T["ambient"]; var cl: Array = T["clouds"]
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": sky.darkened(0.2), "mid": sky.lerp(amb, 0.35), "horizon": (cl[1] as Color).lerp(T["sun"], 0.5).lightened(0.15),
		"below": cl[0], "ambient": amb, "ambient_energy": 0.5, "fog": (cl[1] as Color).lightened(0.12).lerp(Color("4a5aa8"), 0.35), "sun_col": T["sun"]})
	holder.add_child(env)
	var sun := Look.lights(holder, T["sun"], 1.0, Vector3(-55, -35, 0), 60.0)
	sun.shadow_opacity = 0.8
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := 40.0; var k := 0
	for i in 40:
		for j in 40:
			var x0 := -g + i * 2.0; var z0 := -g + j * 2.0
			var c := Color("5f8d45")
			for p in [Vector3(x0, 0, z0), Vector3(x0 + 2, 0, z0), Vector3(x0 + 2, 0, z0 + 2), Vector3(x0, 0, z0), Vector3(x0 + 2, 0, z0 + 2), Vector3(x0, 0, z0 + 2)]:
				st.set_color(c); st.set_normal(Vector3.UP); st.add_vertex(p)
	var ground := MeshInstance3D.new(); ground.mesh = st.commit()
	var tm := ShaderMaterial.new(); tm.shader = load("res://shaders/terrain.gdshader"); ground.material_override = tm
	holder.add_child(ground)
	var cam := Camera3D.new(); holder.add_child(cam); cam.make_current()
	var gi := 0
	for path in glbs:
		var doc := GLTFDocument.new(); var gs := GLTFState.new()
		var err := doc.append_from_file(path, gs)
		if err != OK: print("LOAD FAIL ", path, " ", err); continue
		var model: Node3D = doc.generate_scene(gs)
		holder.add_child(model)
		var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		for clip in ap.get_animation_list():
			var an := ap.get_animation(clip); var L := an.length
			var cname := clip.get_slice("|", 1) if clip.contains("|") else clip
			for view in ["game", "eye"]:
				if view == "game":
					var pit := deg_to_rad(57.0); var d := 32.2; var yaw := deg_to_rad(20.0)
					cam.position = Vector3(d * cos(pit) * sin(yaw), d * sin(pit) + 0.6, d * cos(pit) * cos(yaw))
					cam.fov = rad_to_deg(2.0 * atan(1.05 / d))
					cam.look_at(Vector3(0, 0.6, 0))
				else:
					var d2 := 9.0; var yaw2 := deg_to_rad(20.0)
					cam.position = Vector3(d2 * sin(yaw2), 1.0, d2 * cos(yaw2))
					cam.fov = rad_to_deg(2.0 * atan(1.15 / d2))
					cam.look_at(Vector3(0, 0.95, 0))
				DirAccess.make_dir_recursive_absolute("%s/%d_%s/%s" % [out, gi, cname, view])
				ap.play(clip)
				for f in n:
					ap.seek(L * f / float(n), true)
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_jpg("%s/%d_%s/%s/f%03d.jpg" % [out, gi, cname, view, f], 0.92)
		model.queue_free(); await process_frame; gi += 1
	print("FILM_DONE")
	quit()
