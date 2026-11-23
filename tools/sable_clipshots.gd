extends "res://tools/live_audit.gd"
## --sable-shots --shots-dir=<dir> --wardens=<id> [--close] [--size=N] [--frames=10] [--bind-only]
## bind pose from 4 sides, then every clip of the hunter's library, N frames each, front (3/4) and back views.
## Files: <dir>/<id>/bind_<side>.jpg, <dir>/<id>/<clip>/f<NN>_<view>.jpg, clips.txt

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = ["thief"]
	var nf := 10
	var bind_only := false
	frame_px = 1024
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
		if a.begins_with("--frames="): nf = int(a.substr(9))
		if a == "--close": close = true
		if a == "--bind-only": bind_only = true
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	_posts()
	for p in posts:
		(p as Node3D).visible = false
	for id in ids:
		await _all(String(id), out.path_join(String(id)), nf, bind_only)
	print("SABLE_SHOTS_DONE")
	tree.quit()

func _all(id: String, dir: String, nf: int, bind_only: bool) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
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
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = false
	sk.reset_bone_poses()
	for k in 3:
		await tree.process_frame
	if close:
		_close_cam(model)
	else:
		_match_cam()
	var sides := {"front": PI, "right": PI / 2.0, "back": 0.0, "left": -PI / 2.0}
	for s in sides:
		model.rotation.y = float(sides[s])
		for k in 6:
			await tree.process_frame
		await _save(dir, "bind_%s.jpg" % s)
	if bind_only or clips == null:
		model.queue_free()
		return
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = true
	model.set_meta(WardenClips.STATE, {"vel": Vector3.ZERO, "face": THREE_Q_YAW, "grounded": true})
	for k in 20:
		sync.call("_process", DT)
	var names: Array = Array(clips.lib.get_animation_list())
	names.sort()
	var f := FileAccess.open(dir.path_join("clips.txt"), FileAccess.WRITE)
	for cn in names:
		var length := clips.lib.get_animation(cn).length
		f.store_line("%s %.3f" % [cn, length])
		DirAccess.make_dir_recursive_absolute(dir.path_join(cn))
		for i in nf:
			var t := minf(length * (float(i) + 0.5) / float(nf), length - 0.001)
			clips.force = {"clip": cn, "t": t}
			for k in 2:
				sync.call("_process", DT)
			for view in ["front", "back"]:
				model.rotation.y = THREE_Q_YAW + (PI if view == "back" else 0.0)
				await _save(dir.path_join(cn), "f%02d_%s.jpg" % [i + 1, view])
	f.close()
	clips.force = {}
	model.queue_free()
