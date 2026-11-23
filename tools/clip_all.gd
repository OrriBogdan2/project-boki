extends "res://tools/live_audit.gd"
## --clip-all --shots-dir=<dir> [--wardens=rimewright] [--size=800] [--cam=close|game|game2x] [--dump=<file>] [--norender]
## Every clip of the hunter, frame by frame at 30 fps (clips in library order), one jpg per frame + index.txt
## ("<n> <clip> <i>/<count>"). --dump writes, per frame, every skinned mesh's bind matrices (bone global pose * bind pose,
## 12 float32 per bind) so a numpy skinner can pose the glb exactly as the game does. Job-dir tool, not shipped.

var cam_kind := "close"
var dump_path := ""
var norender := false
var yaw_add := 0.0
var zoom := 1.0
var only: Array = []
var bind := false

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = ["rimewright"]
	frame_px = 800
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
		if a.begins_with("--cam="): cam_kind = a.substr(6)
		if a.begins_with("--dump="): dump_path = a.substr(7)
		if a == "--norender": norender = true
		if a == "--bind": bind = true
		if a.begins_with("--yaw-add="): yaw_add = float(a.substr(10))
		if a.begins_with("--zoom="): zoom = float(a.substr(7))
		if a.begins_with("--clips="): only = Array(a.substr(8).split(",", false))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	for id in ids:
		await _all(String(id), out.path_join(String(id)))
	print("CLIP_ALL_DONE ", ids.size())
	tree.quit()

func _all(id: String, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring and cam_kind != "game" and cam_kind != "game2x":
		ring.visible = false
	for k in 25:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	model.rotation.y = THREE_Q_YAW + yaw_add
	model.set_meta(WardenClips.STATE, {"vel": Vector3.ZERO, "face": THREE_Q_YAW + yaw_add, "grounded": true})
	for k in 20:
		sync.call("_process", DT)
	if cam_kind == "close":
		_close_cam(model)
	elif cam_kind == "eye" or cam_kind == "knee":
		_close_cam(model)
		var bx := _body_box(model)
		var h := clampf(float(bx[1]), 1.2, 2.8)
		var cy: float = float(bx[0]) + h * 0.5
		var ey: float = float(bx[0]) + (h * 0.9 if cam_kind == "eye" else h * 0.28)
		cam.position = Vector3(0, ey, 4.0)
		cam.look_at(Vector3(0, cy, 0))
	else:
		_match_cam()
		if cam_kind == "game2x":
			cam.fov = 4.0
	cam.fov /= zoom
	for k in 5:
		await tree.process_frame
	if bind:
		for at in model.find_children("*", "AnimationTree", true, false):
			(at as AnimationTree).active = false
		for i in 4:
			model.rotation.y = THREE_Q_YAW + yaw_add + i * PI / 2.0
			sk.reset_bone_poses()
			for k in 4:
				await tree.process_frame
			await _save(dir, "bind_%d.jpg" % i)
		model.queue_free()
		return
	var insts: Array = []
	for mi in model.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh != null and m.skin != null and m.is_visible_in_tree():
			insts.append(m)
	var df: FileAccess = null
	if dump_path != "":
		df = FileAccess.open(dump_path, FileAccess.WRITE)
		var hdr := FileAccess.open(dump_path + ".txt", FileAccess.WRITE)
		for m in insts:
			var sk2: Skin = (m as MeshInstance3D).skin
			var names: PackedStringArray = []
			for i in sk2.get_bind_count():
				names.append(sk2.get_bind_name(i))
			hdr.store_line("%s %d %s" % [(m as MeshInstance3D).name, sk2.get_bind_count(), ",".join(names)])
		var pr := cam.get_camera_projection()
		var fl: PackedStringArray = []
		for c in 4:
			for r in 4:
				fl.append(str(pr[c][r]))
		hdr.store_line("proj " + " ".join(fl))
		for nm2 in ["cam", "skel"]:
			var t2: Transform3D = cam.global_transform if nm2 == "cam" else sk.global_transform
			var f2: PackedStringArray = []
			for c in 3:
				f2.append_array([str(t2.basis.x[c]), str(t2.basis.y[c]), str(t2.basis.z[c]), str(t2.origin[c])])
			hdr.store_line(nm2 + " " + " ".join(f2))
		hdr.close()
	var idx: PackedStringArray = []
	var n := 0
	for nm in clips.lib.get_animation_list():
		if not only.is_empty() and not only.has(String(nm)):
			continue
		var length := clips.lib.get_animation(nm).length
		var cnt := int(ceil(length * 30.0 - 0.001)) + 1
		clips.force = {"clip": String(nm), "t": 0.0}
		for k in 4:
			sync.call("_process", DT)
		for i in cnt:
			clips.force = {"clip": String(nm), "t": minf(i * DT, length - 0.0005)}
			sync.call("_process", DT)
			if df:
				for m in insts:
					var mm := m as MeshInstance3D
					var s: Skin = mm.skin
					for b in s.get_bind_count():
						var bi := s.get_bind_bone(b)
						if bi < 0:
							bi = sk.find_bone(s.get_bind_name(b))
						var t: Transform3D = sk.get_bone_global_pose(bi) * s.get_bind_pose(b)
						for c in 3:
							df.store_float(t.basis.x[c]); df.store_float(t.basis.y[c]); df.store_float(t.basis.z[c]); df.store_float(t.origin[c])
			idx.append("%d %s %d/%d" % [n, nm, i, cnt])
			if not norender:
				await _save(dir, "f%04d.jpg" % n)
			n += 1
	if df:
		df.close()
	clips.force = {}
	var f := FileAccess.open(dir.path_join("index.txt"), FileAccess.WRITE)
	f.store_string("\n".join(idx) + "\n")
	f.close()
	model.queue_free()
