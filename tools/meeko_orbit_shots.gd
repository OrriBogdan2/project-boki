extends "res://tools/clip_shots.gd"
## --meeko-orbit-shots --shots-dir=<dir> [--size=480] [--yaw=deg] [--frames=3] [--step=0.9]: Meeko with her sun and
## raincloud floating round her (WardenCompanions), a few frames a moment apart: <dir>/orbit_<view>_f<N>.png, once from
## the front three-quarter and once from above and behind. Needs a renderer.

const DT := 1.0 / 30.0

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var yaw := 155.0
	var frames := 3
	var step := 0.9
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--size="): frame_px = int(a.substr(7))
		if a.begins_with("--yaw="): yaw = float(a.substr(6))
		if a.begins_with("--frames="): frames = int(a.substr(9))
		if a.begins_with("--step="): step = float(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	DirAccess.make_dir_recursive_absolute(out)
	_stage(main)
	var model := Models.hunter(Arch.weight("tender"), Data.TEAM_COLORS[0], Arch.signature("tender"), "",
		PlayerLook.neutral(), "tender")
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	model.rotation.y = deg_to_rad(yaw)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 30:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	cam.fov = 30.0
	var views := {
		"front": [Vector3(0, 1.9, 4.6), Vector3(0, 1.05, 0)],
		"above": [Vector3(0, 4.0, 3.2), Vector3(0, 1.0, 0)],
	}
	for view in views:
		cam.position = views[view][0]
		cam.look_at(views[view][1])
		sync.companions.t = 0.0
		for i in frames:
			var steps := int(step / DT) if i > 0 else 20
			for k in steps:
				sync.call("_process", DT)
			await _grab(out.path_join("orbit_%s_f%d.png" % [view, i]))
	print("MEEKO_ORBIT_SHOTS_DONE")
	tree.quit()
