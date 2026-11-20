extends "res://tools/idle_shots.gd"
## --idle-break-shots --shots-dir=<dir> [--wardens=a,b] [--size=320]: each Hunter standing, then the idle break
## (WardenBreak) every 0.25 s from its start to its end, in <dir>/<id>/f000.png... The first frame is the idle just
## before the break. Needs a renderer.

const STEP := 0.25      # s between frames
const YAW := 155.0      # model yaw, degrees

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 30.0
	for id in ids:
		await _film(String(id), out.path_join(String(id)))
	print("IDLE_BREAK_SHOTS_DONE ", ids.size())
	tree.quit()

func _film(id: String, dir: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.rotation.y = deg_to_rad(YAW)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 30:
		await tree.process_frame
	var tall := _height(model)
	cam.position = Vector3(0, tall * 0.52, tall * 2.15)
	cam.look_at(Vector3(0, tall * 0.5, 0))
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var brk := sync.get("idle_break") as WardenBreak
	DirAccess.make_dir_recursive_absolute(dir)
	model.set_meta(WardenClips.STATE, {"idle_break": true, "grounded": true, "fired": 99.0, "face": model.rotation.y})
	var wait := WardenBreak.WAIT - 0.1
	var i := 0
	var t := 0.0
	while t < wait + brk.dur + 0.2:
		sync.call("_process", DT)
		if t >= wait + (i - 1) * STEP and i <= int(brk.dur / STEP) + 1:
			await _grab(dir.path_join("f%03d.png" % i))
			i += 1
		t += DT
	model.queue_free()
	await tree.process_frame
