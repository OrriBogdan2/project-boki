extends "res://tools/clip_shots.gd"
## --rooted-shots --shots-dir=<dir> [--wardens=a,b] [--size=320]: every Hunter's first move cast while the velocity
## still says he runs, through the game's own HunterAnim: <dir>/<id>/free_<n>.png (not rooted: the run cycle slides in
## place) over rooted_<n>.png (the "rooted" state: the legs stay planted, the body casts). Frames 0.1 s apart. Needs a
## renderer; `ffmpeg -pattern_type glob ... tile` makes the strips.

const FRAMES := 6
const STEP := 0.1       # s between frames
const DT := 1.0 / 30.0

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
		await _hunter(String(id), out.path_join(String(id)))
	print("ROOTED_SHOTS_DONE ", ids.size())
	tree.quit()

func _hunter(id: String, dir: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	model.rotation.y = deg_to_rad(90.0)
	for k in 30:
		await tree.process_frame
	cam.position = Vector3(0, 1.1, 4.4)
	cam.look_at(Vector3(0, 0.8, 0))
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var flow: Array = WardenClips.data(WardenGlb.art(id)).get("flow", [])
	var move := String(flow[0][0]) if not flow.is_empty() else ""
	DirAccess.make_dir_recursive_absolute(dir)
	for rooted in [false, true]:
		var anim := HunterAnim.new(model)
		var s := {"vel": Vector3(0, 0, -3.0), "face": 0.0, "grounded": true, "fired": 99.0, "rooted": rooted}
		for k in 20:
			anim.update(DT, s)
			sync.call("_process", DT)
		for i in FRAMES:
			s["kmove"] = move
			for k in int(STEP / DT):
				s["kmove_t"] = i * STEP + k * DT
				anim.update(DT, s)
				sync.call("_process", DT)
			await _grab(dir.path_join("%s_%d.png" % ["rooted" if rooted else "free", i]))
	model.queue_free()
	await tree.process_frame
