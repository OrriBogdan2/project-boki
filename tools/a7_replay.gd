extends "res://tools/live_audit.gd"
## --a7-replay [--keys=f1,f2,..] (eye-level e%04d + knee-level k%04d full-body views on those frames) --shots-dir=<dir> [--size=1024] [--pose=<json>] [--step=1]: scratch (never committed). Gil's real model
## with the game's recorded bone poses (pose_dump_game_run.json) replayed frame by frame. bind_<side>.jpg for 4 sides,
## then c%04d.jpg (close cam) and m%04d.jpg (match cam, every 3rd frame).

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var pose := "res://tools/a7_pose.json"
	var step := 1
	var keys := {}
	var only_keys := false
	frame_px = 1024
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--pose="): pose = a.substr(7)
		if a.begins_with("--size="): frame_px = int(a.substr(7))
		if a.begins_with("--step="): step = int(a.substr(7))
		if a == "--only-keys": only_keys = true
		if a.begins_with("--keys="):
			for k in a.substr(7).split(","):
				keys[int(k)] = true
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	ground_col = Color("8a7f6e")
	_stage(main)
	DirAccess.make_dir_recursive_absolute(out)
	var id := "gil"
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 25:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = false
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	var skin: Skin
	for mi in sk.get_parent().find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin != null and (mi as MeshInstance3D).name == "Body":
			skin = (mi as MeshInstance3D).skin
	var nbn := sk.get_bone_count()
	var ibm: Array = []
	for i in nbn:
		ibm.append(Transform3D())
	for i in skin.get_bind_count():
		var bi := skin.get_bind_bone(i)
		if bi < 0:
			bi = sk.find_bone(skin.get_bind_name(i))
		ibm[bi] = skin.get_bind_pose(i)
	var d = JSON.parse_string(FileAccess.get_file_as_string(pose))
	var names: Array = d["bones"]
	var frames: Array = d["frames"]
	var labels: Array = d["labels"]
	var bidx: Array = []
	for n in names:
		bidx.append(sk.find_bone(String(n)))
	# bind pose, four sides, close then match
	sk.reset_bone_poses()
	for cm in ["close"]:
		for side in [["front", PI], ["right", PI / 2.0], ["back", 0.0], ["left", -PI / 2.0]]:
			model.rotation.y = float(side[1])
			if cm == "close":
				_close_cam(model)
			else:
				_match_cam()
			for k in 6:
				await tree.process_frame
			await _save(out, "bind_%s_%s.jpg" % [cm, side[0]])
	model.rotation.y = PI + 0.6
	_close_cam(model)
	var bx := _body_box(model)
	var b0: float = float(bx[0])
	var h0: float = clampf(float(bx[1]), 1.2, 2.8)
	var hips := sk.find_bone("hips")
	sk.reset_bone_poses()
	var hrest: Vector3 = sk.global_transform * sk.get_bone_global_pose(hips).origin
	var cfov := cam.fov
	var cpos := cam.position
	var order: Array = []
	for i in nbn:
		order.append(i)
	var n := 0
	var f := 0
	while f < frames.size():
		var row: Array = frames[f]
		var glob := {}
		for k in names.size():
			var o := k * 12
			var b := Basis(Vector3(row[o + 0], row[o + 4], row[o + 8]), Vector3(row[o + 1], row[o + 5], row[o + 9]), Vector3(row[o + 2], row[o + 6], row[o + 10]))
			var m := Transform3D(b, Vector3(row[o + 3], row[o + 7], row[o + 11]))
			glob[bidx[k]] = m * (ibm[bidx[k]] as Transform3D).affine_inverse()
		# locals, parents first
		var done := {}
		var guard := 0
		while done.size() < nbn and guard < 40:
			guard += 1
			for i in nbn:
				if done.has(i):
					continue
				var p := sk.get_bone_parent(i)
				if p >= 0 and not done.has(p):
					continue
				var g: Transform3D = glob[i] if glob.has(i) else sk.get_bone_global_rest(i)
				var pg: Transform3D = Transform3D() if p < 0 else (glob[p] if glob.has(p) else sk.get_bone_global_rest(p))
				var loc := pg.affine_inverse() * g
				sk.set_bone_pose_position(i, loc.origin)
				sk.set_bone_pose_rotation(i, loc.basis.get_rotation_quaternion())
				sk.set_bone_pose_scale(i, loc.basis.get_scale())
				done[i] = true
		if only_keys and not keys.has(f):
			f += step
			continue
		var hd: Vector3 = (sk.global_transform * sk.get_bone_global_pose(hips).origin) - hrest
		cam.fov = cfov
		cam.position = cpos + hd
		cam.look_at(Vector3(hd.x, cpos.y + hd.y, hd.z))
		for k in 2:
			await tree.process_frame
		await _save(out, "c%04d.jpg" % f)
		if keys.has(f):
			# eye level, full body (other 3/4 side), then knee level looking up (the fish side)
			model.rotation.y = PI - 0.55
			_ground(model, sk, hips, b0)
			hd = Vector3.ZERO
			cam.fov = rad_to_deg(2.0 * atan((h0 * 1.45) / (2.0 * 4.5)))
			cam.position = Vector3(hd.x, b0 + h0 * 0.8 + hd.y, 4.5 + hd.z)
			cam.look_at(Vector3(hd.x, b0 + h0 * 0.5 + hd.y, hd.z))
			for k in 2:
				await tree.process_frame
			await _save(out, "e%04d.jpg" % f)
			model.rotation.y = PI + 0.35
			_ground(model, sk, hips, b0)
			hd = Vector3.ZERO
			cam.position = Vector3(hd.x, b0 + 0.28 + hd.y, 4.5 + hd.z)
			cam.look_at(Vector3(hd.x, b0 + h0 * 0.5 + hd.y, hd.z))
			for k in 2:
				await tree.process_frame
			await _save(out, "k%04d.jpg" % f)
			model.rotation.y = PI + 0.6
			model.position = Vector3.ZERO
		f += step
	var fo := FileAccess.open(out.path_join("labels.txt"), FileAccess.WRITE)
	fo.store_string("\n".join(PackedStringArray(labels)))
	fo.close()
	print("A6_REPLAY_DONE ", frames.size())
	tree.quit()



## Eye/knee views: the replayed pose may carry the hunter's world drop/lift; stand its lowest point on the floor
## (rest bottom b0) and put the hips over the origin, so the stage floor reads right.
func _ground(model: Node3D, sk: Skeleton3D, hips: int, b0: float) -> void:
	model.position = Vector3.ZERO
	var hp: Vector3 = sk.global_transform * sk.get_bone_global_pose(hips).origin
	var bx := _body_box(model)
	model.position = Vector3(-hp.x, b0 - float(bx[0]), -hp.z)
