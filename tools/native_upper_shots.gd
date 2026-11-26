extends "res://tools/clip_shots.gd"
## --native-upper-shots --shots-dir=<dir> [--size=480] [--ids=a,b]: each native Hunter running at 4.6 m/s with a swing
## pressed 0.3 s in, a side view, a frame every 1/30 s to 1.2 s: <dir>/<id>/f###.png. Needs a renderer.

const DT := 1.0 / 30.0
const PRESS := 0.3  # s into the run the swing starts
const SECS := 1.2
const RUN := 4.6  # m/s
const IDS := ["mage", "juggernaut", "archer", "dredge"]


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = IDS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
		if a.begins_with("--ids="):
			ids = a.substr(6).split(",")
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 30.0
	cam.position = Vector3(5.0, 1.2, 0.0)
	cam.look_at(Vector3(0, 0.9, 0))
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)))
	print("NATIVE_UPPER_SHOTS_DONE")
	tree.quit()


func _hunter(id: String, dir: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	model.rotation.y = deg_to_rad(90.0)
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var poser := model.get_node("Warden/Native")
	poser.set_process(false)
	DirAccess.make_dir_recursive_absolute(dir)
	var base := {"grounded": true, "face": model.rotation.y, "cast": 99.0, "vel": Vector3(0, 0, -RUN)}
	for k in 20:
		model.set_meta(WardenClips.STATE, base)
		poser.call("_process", DT)
	for i in int(SECS / DT):
		var s := base.duplicate()
		if i * DT >= PRESS:
			s["swing_n"] = 1
			s["combo"] = 0
			s["cast"] = 0.0
		model.set_meta(WardenClips.STATE, s)
		poser.call("_process", DT)
		await _grab(dir.path_join("f%03d.png" % i))
	model.queue_free()
	await tree.process_frame
