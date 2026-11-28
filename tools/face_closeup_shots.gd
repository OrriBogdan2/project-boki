extends RefCounted
## --face-closeup-shots --shots-dir=<dir> [--warden=<id>] [--size=900] [--tag=<name>] [--focus-y=<m>]: <dir>/<tag>_<view>.png,
## head close-ups (front, 3/4 left, 3/4 right, eye-level side) of one Hunter's in-game model. Needs a renderer.

const VIEWS := {"front": 180.0, "q34l": 150.0, "q34r": -150.0, "side": 110.0, "back": 0.0}  # deg the model turns, camera fixed
var focus := Vector3(0, 1.45, 0)  # m: face centre of a Hunter model (--focus-y=<m> moves it)
const DIST := 0.75  # m camera to face
var holder: Node3D
var cam: Camera3D
var tree: SceneTree


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var px := 900
	var id := "thief"
	var tag := "live"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--size="): px = int(a.substr(7))
		if a.begins_with("--warden="): id = a.substr(9)
		if a.begins_with("--tag="): tag = a.substr(6)
		if a.begins_with("--focus-y="): focus.y = float(a.substr(10))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	_stage(main)
	for k in 30:
		await tree.process_frame
	if "--dump" in OS.get_cmdline_user_args():
		await _dump(id, out.path_join("verts.json"))
	for v in VIEWS:
		await _shot(id, float(VIEWS[v]), out.path_join("%s_%s.png" % [tag, v]))
	print("FACE_CLOSEUP_DONE")
	tree.quit()


func _shot(id: String, yaw: float, path: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	(m.get_node_or_null("TeamRing") as Node3D).visible = false
	m.rotation_degrees.y = yaw
	for k in 3:
		await tree.process_frame
	var img := tree.root.get_texture().get_image()
	if img != null:
		img.save_png(path)
	m.free()


func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	var sky := {"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0}
	env.environment = Look.environment(sky)
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	cam = Camera3D.new()
	cam.fov = 22.0
	cam.position = focus + Vector3(0, 0, DIST)
	holder.add_child(cam)
	cam.look_at(focus)
	cam.make_current()


func _dump(id: String, path: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	for k in 33:
		await tree.process_frame
	var res := []
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin == null or mi.skeleton.is_empty():
			continue
		var sk := mi.get_node(mi.skeleton) as Skeleton3D
		var mats := []
		for i in mi.skin.get_bind_count():
			var b := mi.skin.get_bind_bone(i)
			if b < 0:
				b = sk.find_bone(mi.skin.get_bind_name(i))
			mats.append(mi.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(b) * mi.skin.get_bind_pose(i))
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bn: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wt: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var nout := PackedFloat32Array()
			var out := PackedFloat32Array()
			for i in vs.size():
				var p := Vector3.ZERO
				var nv := Vector3.ZERO
				for k in 4:
					p += (mats[bn[i * 4 + k]] * vs[i]) * wt[i * 4 + k]
					nv += (mats[bn[i * 4 + k]].basis * nm[i]) * wt[i * 4 + k]
				out.append_array([p.x, p.y, p.z])
				nout.append_array([nv.x, nv.y, nv.z])
			res.append({"mesh": mi.name, "surf": s, "mat": mi.mesh.surface_get_material(s).resource_name if mi.mesh.surface_get_material(s) else "", "n": vs.size(), "pos": Array(out), "nrm": Array(nout), "rest": Array(vs.to_byte_array().to_float32_array()), "uv": Array((arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array).to_byte_array().to_float32_array()), "xf": str(mi.global_transform)})
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(res))
	f.close()
	m.free()
