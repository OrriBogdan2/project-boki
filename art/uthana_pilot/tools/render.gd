extends Control
## Uthana pilot: left = our current clip, right = the Uthana motion-only GLB remapped onto the same Skeleton3D.
## Arg: --jobs=<tsv: out_dir model ours_clip|- uth_anim_glb label>; frames go to out_dir/f%04d.png, 30 fps.
const SIDE := 480 ## px per half
const CONTACT_H := 0.06 ## m above the lowest foot height that counts as planted
const FPS := 30.0
var _sides: Array[Dictionary] = []
var _frame := 0

func _ready() -> void:
	var jobs := ""
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--jobs="): jobs = s.trim_prefix("--jobs=")
	for line in FileAccess.get_file_as_string(jobs).split("\n", false):
		await _run(line.split("\t"))
	get_tree().quit()

func _run(j: PackedStringArray) -> void:
	var out := j[0]
	DirAccess.make_dir_recursive_absolute(out)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	_sides.clear()
	_frame = 0
	var ours := j[2] if j[2] != "-" else ""
	_sides.append(_make_side(row, j[1], ours, null, "ours: " + (ours if ours else "(none)")))
	_sides.append(_make_side(row, j[1], "", _remap_anim(j[3]), "uthana: " + j[4]))
	await RenderingServer.frame_post_draw ## warm-up: the first frame comes out blank
	var uth_len: float = _sides[1]["ap"].get_animation(_sides[1]["ap"].assigned_animation).length
	var n := int(uth_len * FPS)
	for f in n:
		var t := f / FPS
		for s in _sides:
			var ap: AnimationPlayer = s["ap"]
			if ap.assigned_animation != "":
				ap.seek(fmod(t, ap.get_animation(ap.assigned_animation).length), true)
		_track()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [out, f])
	for s in _sides:
		print("SLIDE %s | %s frames=%d planted_slide_m=%.3f foot_min_y=%.3f" % [out.get_file(), s["name"], _frame, s["slide"], s["minh"]])
	row.queue_free()
	await get_tree().process_frame

func _make_side(row: HBoxContainer, model: String, clip: String, anim: Animation, label: String) -> Dictionary:
	var box := SubViewportContainer.new()
	box.custom_minimum_size = Vector2(SIDE, SIDE)
	row.add_child(box)
	var vp := SubViewport.new()
	vp.size = Vector2i(SIDE, SIDE)
	vp.own_world_3d = true
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	vp.add_child(sun)
	vp.add_child(_ground())
	var m: Node3D = load(model).instantiate()
	vp.add_child(m)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	if anim:
		var lib := AnimationLibrary.new()
		lib.add_animation("uth", anim)
		ap.add_animation_library("uthana", lib)
		clip = "uthana/uth"
	if clip != "":
		ap.play(clip)
		ap.pause()
	var cam := Camera3D.new()
	cam.fov = 40
	vp.add_child(cam)
	var l := Label.new()
	l.text = label
	l.position = Vector2(8, 6)
	l.add_theme_font_size_override("font_size", 15)
	box.add_child(l)
	return {"m": m, "ap": ap, "sk": sk, "cam": cam, "name": label, "feet": _feet(sk), "prev": {}, "slide": 0.0, "minh": 99.0}

func _feet(sk: Skeleton3D) -> Array[int]:
	var out: Array[int] = []
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.begins_with("foot.") or n.begins_with("x_foot."): out.append(i)
	return out

func _remap_anim(path: String) -> Animation:
	var n: Node = load(path).instantiate()
	var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
	var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate(true)
	for t in a.get_track_count():
		var bone := String(a.track_get_path(t)).split(":")[0].get_file()
		if bone.ends_with("_L") or bone.ends_with("_R"): ## Godot turns "thigh.L" into node "thigh_L"
			bone = bone.left(-2) + "." + bone.right(1)
		a.track_set_path(t, NodePath("Armature/Skeleton3D:" + bone))
	n.free()
	return a

func _ground() -> MeshInstance3D:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	g.mesh = pm
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.fill(Color(0.32, 0.33, 0.36))
	img.set_pixel(0, 0, Color(0.42, 0.43, 0.47))
	img.set_pixel(1, 1, Color(0.42, 0.43, 0.47))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(40, 40, 1) ## 0.5 m checks
	g.material_override = mat
	return g

func _track() -> void:
	_frame += 1
	for s in _sides:
		var sk: Skeleton3D = s["sk"]
		var root := sk.global_transform * sk.get_bone_global_pose(0).origin
		var cam: Camera3D = s["cam"]
		cam.position = Vector3(root.x + 4.4, 1.5, root.z + 2.0)
		cam.look_at(Vector3(root.x, 0.8, root.z))
		for f in s["feet"]:
			var p := sk.global_transform * sk.get_bone_global_pose(f).origin
			s["minh"] = minf(s["minh"], p.y)
			if s["prev"].has(f) and p.y < s["minh"] + CONTACT_H and _frame > 2:
				var d: Vector3 = p - s["prev"][f]
				s["slide"] += Vector2(d.x, d.z).length()
			s["prev"][f] = p
