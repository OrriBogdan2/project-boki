extends SceneTree
## film.gd -- OUTDIR GLB,GLB,... [--n=20] [--px=1080]: in-game look frames of Meshy-rigged glbs (not committed).
## Match look: Look.environment + Look.lights exactly as match.gd _build_env for tier 0, terrain shader ground.
## Views: game = match camera (pitch 57, 32.2 m back) with a narrow lens (native crop, no upscale); eye = 1.0 m, 3.4 m.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := String(args[0])
	var glbs := String(args[1]).split(",")
	var n := 20
	var px := 1080
	for a in args:
		if String(a).begins_with("--n="):
			n = int(String(a).substr(4))
		elif String(a).begins_with("--px="):
			px = int(String(a).substr(5))
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(px * 3 / 4, px)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var tier: Dictionary = {"sky": Color("10131f"), "ambient": Color("b9c4e6"), "sun": Color("fff1dc"),
		"clouds": [Color(0.06, 0.07, 0.13), Color(0.22, 0.24, 0.38)]}
	var sky: Color = tier["sky"]
	var amb: Color = tier["ambient"]
	var cl: Array = tier["clouds"]
	var we := WorldEnvironment.new()
	we.environment = Look.environment({"top": sky.darkened(0.2), "mid": sky.lerp(amb, 0.35),
		"horizon": (cl[1] as Color).lerp(tier["sun"], 0.5).lightened(0.15), "below": cl[0], "ambient": amb,
		"ambient_energy": 0.5, "fog": (cl[1] as Color).lightened(0.12).lerp(Color("4a5aa8"), 0.35), "sun_col": tier["sun"]})
	vp.add_child(we)
	var sun := Look.lights(vp, tier["sun"], 1.0, Vector3(-55, -35, 0), 60.0)
	sun.shadow_opacity = 0.8
	vp.add_child(_ground())
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	for gi in glbs.size():
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(glbs[gi], st) != OK:
			push_error("load failed " + glbs[gi])
			continue
		var sc: Node3D = doc.generate_scene(st, 30.0)
		vp.add_child(sc)
		var ap: AnimationPlayer = sc.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Skeleton3D = sc.find_children("*", "Skeleton3D", true, false)[0]
		var hb := sk.find_bone("Hips")
		for an in ap.get_animation_list():
			var ln := ap.get_animation(an).length
			var tag := "%d_%s" % [gi, String(an).replace(" ", "_").replace("|", "_")]
			for v in ["game", "eye"]:
				DirAccess.make_dir_recursive_absolute(out.path_join(tag).path_join(v))
				for f in n:
					ap.play(an)
					ap.seek(ln * f / float(n), true)
					await process_frame
					var hp := sk.global_transform * sk.get_bone_global_pose(hb).origin
					var fo := Vector3(hp.x, 0.0, hp.z)
					if v == "game":
						var p := deg_to_rad(57.0)
						cam.fov = 4.6
						cam.position = fo + Vector3(0, sin(p), cos(p)) * 32.2
						cam.look_at(fo + Vector3(0, 0.95, 0))
					else:
						var y := deg_to_rad(30.0)
						cam.fov = 40.0
						cam.position = fo + Vector3(sin(y) * 3.4, 1.0, cos(y) * 3.4)
						cam.look_at(fo + Vector3(0, 0.92, 0))
					await process_frame
					await process_frame
					vp.get_texture().get_image().save_jpg(out.path_join(tag).path_join(v).path_join("f%03d.jpg" % f), 0.92)
			print("FILM_CLIP ", tag)
		sc.queue_free()
		await process_frame
	print("FILM_DONE ", out)
	quit(0)


## 60 x 60 m of meadow ground: tier-0 biome top colours in vertex colour, the island terrain shader.
func _ground() -> MeshInstance3D:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Color("5f8d45")
	var b := Color("4a7538")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var h := 30
	var cols := {}
	for x in range(-h, h + 1):
		for z in range(-h, h + 1):
			cols[Vector2i(x, z)] = a.lerp(b, rng.randf())
	for x in range(-h, h):
		for z in range(-h, h):
			for c in [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x + 1, z + 1), Vector2i(x, z), Vector2i(x + 1, z + 1), Vector2i(x, z + 1)]:
				s.set_color(cols[c])
				s.set_normal(Vector3.UP)
				s.set_uv(Vector2(c.x + h, c.y + h) / float(2 * h))
				s.add_vertex(Vector3(c.x, 0.0, c.y))
	var mi := MeshInstance3D.new()
	mi.mesh = s.commit()
	mi.material_override = _terrain_mat()
	return mi


func _terrain_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	return m
