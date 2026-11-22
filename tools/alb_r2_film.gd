extends RefCounted
## TEMP (job 20261121-182115-a2, never committed): --alb-r2-film --rig=R.glb --clips=a.glb,b.glb --shots-dir=DIR
## [--size=768] [--fps=15] [--views=game,eye,knee,face] [--yaw=30]
## round 1's film.gd as a registered check so it runs on the GPU pods: a Meshy rig glb (textures) + its clip glbs,
## each clip frame by frame on match lighting over a terrain-shader ground, in an own-world SubViewport.
## game = match camera (pitch 66, 23 m) narrowed to the hero; eye = eye level 5.2 m; knee = 0.45 m up, looking up;
## face = 1.7 m from the Head bone. Files: DIR/<view>/<clip>/f###.jpg

var size := 768
var fps := 15.0

func _glb(p: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(p if p.begins_with("/") else ProjectSettings.globalize_path("res://" + p), st)
	if err != OK:
		push_error("glb load failed %s %d" % [p, err])
		return null
	return doc.generate_scene(st) as Node3D

func _ground(T: Dictionary) -> MeshInstance3D:
	var bio: Dictionary = T["biome"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for z in n:
		for x in n:
			var c: Color = (bio["top"] as Color).lerp(bio["top2"], rng.randf() * 0.6)
			var p0 := Vector3(x - n / 2, 0, z - n / 2)
			var q := [p0, p0 + Vector3(1, 0, 0), p0 + Vector3(1, 0, 1), p0, p0 + Vector3(1, 0, 1), p0 + Vector3(0, 0, 1)]
			for v in q:
				st.set_color(c)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("map_size", Vector2(n, n))
	mat.set_shader_parameter("use_ao", false)
	mi.material_override = mat
	return mi

func run(main: Node) -> void:
	var tree := main.get_tree()
	var rig := ""
	var clip_paths: Array = []
	var out := ""
	var views := ["game", "eye", "knee", "face"]
	var yaw := 30.0
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rig="): rig = a.substr(6)
		if a.begins_with("--clips="): clip_paths = Array(a.substr(8).split(",", false))
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--size="): size = int(a.substr(7))
		if a.begins_with("--fps="): fps = float(a.substr(6))
		if a.begins_with("--views="): views = Array(a.substr(8).split(",", false))
		if a.begins_with("--yaw="): yaw = float(a.substr(6))
		if a.begins_with("--only="): only = a.substr(7)
	print("ALBFILM renderer ", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_video_adapter_vendor())
	var sv := SubViewport.new()
	sv.size = Vector2i(size, size)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(sv)
	var T: Dictionary = Data.TIERS[0]
	var holder := Node3D.new()
	sv.add_child(holder)
	var env := WorldEnvironment.new()
	var sky: Color = T["sky"]
	var amb: Color = T["ambient"]
	var cl: Array = T["clouds"]
	env.environment = Look.environment({"top": sky.darkened(0.2), "mid": sky.lerp(amb, 0.35), "horizon": (cl[1] as Color).lerp(T["sun"], 0.5).lightened(0.15),
		"below": cl[0], "ambient": amb, "ambient_energy": 0.5, "fog": (cl[1] as Color).lightened(0.12).lerp(Color("4a5aa8"), 0.35), "sun_col": T["sun"]})
	holder.add_child(env)
	var sun := Look.lights(holder, T["sun"], 1.0, Vector3(-55, -35, 0), 60.0)
	sun.shadow_opacity = 0.8
	RenderingServer.global_shader_parameter_set("vis_dark", 1.0)
	holder.add_child(_ground(T))
	var tex_src := _glb(rig)
	var mats: Array = []
	for mi in tex_src.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		var row: Array = []
		for si in mesh.get_surface_count():
			row.append(mesh.surface_get_material(si))
		mats.append(row)
		print("ALBFILM rig mesh ", mi.name, " surfaces ", mesh.get_surface_count())
	var cam := Camera3D.new()
	holder.add_child(cam)
	cam.current = true
	cam.far = 200.0
	for p in clip_paths:
		var model := _glb(String(p))
		if model == null:
			continue
		holder.add_child(model)
		model.rotation.y = deg_to_rad(yaw)
		var k := 0
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m3 := mi as MeshInstance3D
			print("ALBFILM clip mesh ", m3.name, " <- rig mesh ", k)
			if k < mats.size():
				for si in mini(m3.mesh.get_surface_count(), (mats[k] as Array).size()):
					m3.set_surface_override_material(si, mats[k][si])
			k += 1
		var ap := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var hips := skel.find_bone("Hips")
		if hips < 0: hips = skel.find_bone("hips")
		var head := skel.find_bone("Head")
		if head < 0: head = skel.find_bone("head")
		for k2 in 10:
			await tree.process_frame
		for view in views:
			for nm in ap.get_animation_list():
				if only != "" and not String(nm).contains(only):
					continue
				var key := String(nm).replace("|", "_").replace("/", "_")
				if key.contains("walking"): key = "walk"
				if key.contains("running"): key = "run"
				var dir: String = out.path_join(view).path_join(key)
				DirAccess.make_dir_recursive_absolute(dir)
				var length := ap.get_animation(nm).length
				ap.play(nm)
				ap.pause()
				var n := maxi(2, int(length * fps))
				for i in n:
					ap.seek(minf(i / fps, length - 0.001), true)
					var hp := skel.global_transform * skel.get_bone_global_pose(hips).origin
					var hd := skel.global_transform * skel.get_bone_global_pose(head).origin
					_place(cam, view, Vector3(hp.x, hp.y + 0.43, hp.z), hd, model.global_transform.basis.z)
					await RenderingServer.frame_post_draw
					await RenderingServer.frame_post_draw
					sv.get_texture().get_image().save_jpg(dir.path_join("f%03d.jpg" % i), 0.9)
				print("DONE ", view, " ", key, " ", n)
		model.queue_free()
		await tree.process_frame
	print("FILM_DONE")
	tree.quit(0)

func _place(cam: Camera3D, view: String, tgt: Vector3, hd: Vector3, fwd: Vector3) -> void:
	if view == "game":
		var pitch := deg_to_rad(66.0)
		cam.position = tgt + Vector3(0, sin(pitch), cos(pitch)) * 23.0
		cam.look_at(tgt)
		cam.fov = rad_to_deg(2.0 * atan(1.25 / 23.0))
	elif view == "knee":
		cam.position = Vector3(tgt.x, 0.45, tgt.z + 5.2)
		cam.look_at(Vector3(tgt.x, tgt.y + 0.1, tgt.z))
		cam.fov = rad_to_deg(2.0 * atan(1.35 / 5.2))
	elif view == "face":
		var f := hd + Vector3(0, 0.15, 0)
		cam.position = f + Vector3(fwd.x, 0.0, fwd.z).normalized() * 1.7 + Vector3(0, 0.05, 0)
		cam.look_at(f)
		cam.fov = rad_to_deg(2.0 * atan(0.36 / 1.7))
	else:
		cam.position = tgt + Vector3(0, 0.05, 5.2)
		cam.look_at(tgt)
		cam.fov = rad_to_deg(2.0 * atan(1.3 / 5.2))
