extends "res://tools/idle_shots.gd"
## --result-pose-shots --shots-dir=<dir> [--wardens=a,b] [--size=256]: every Hunter's win, lose and board beat as the
## game plays them (HunterAnim state with "beat" and "beat_t"), three frames each: the pose arriving, held, and
## breathing out. <dir>/<id>/<beat>_<n>.png; tools/result_pose_strip.py makes the strip of all twelve. Needs a renderer.

const SAMPLES := [0.25, 0.9, 2.2]     # s into the beat

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	frame_px = 256
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
		await _beats(String(id), out.path_join(String(id)))
	print("RESULT_POSE_SHOTS_DONE ", ids.size())
	tree.quit()

func _beats(id: String, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	model.rotation.y = deg_to_rad(155.0)
	var anim := HunterAnim.new(model)
	for k in 30:
		await tree.process_frame
	var tall := _height(model)
	cam.position = Vector3(0, tall * 0.52, tall * 2.15)
	cam.look_at(Vector3(0, tall * 0.5, 0))
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	for beat in WardenBeats.NAMES:
		var t := 0.0
		for n in SAMPLES.size():
			while t < SAMPLES[n]:
				t += DT
				var s := {"vel": Vector3.ZERO, "face": model.rotation.y, "grounded": true, "beat": beat, "beat_t": t,
						"crouch": 0.0}
				anim.update(DT, s)
				sync.call("_process", DT)
			await _grab(dir.path_join("%s_%d.png" % [beat, n]))
	model.queue_free()
	await tree.process_frame
