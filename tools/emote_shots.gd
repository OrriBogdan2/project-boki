extends "res://tools/clip_shots.gd"
## --emote-shots --shots-dir=<dir> [--wardens=a,b,c,d] [--emotes=truce,wave] [--at=0.5,1.0] [--speed=0] [--size=320]:
## the emote wheel through the game's own hand-off (the state's emote and emote_t, as Truce shows them). One image per
## emote and moment, <dir>/<emote>_<t>.png, the Hunters side by side. --speed=4 runs them forward at 4 m/s, so the
## legs keep running under the gesture. An id off the wheel plays the Hero's own "emote" clip. Needs a renderer.

const DT := 1.0 / 30.0
const GAP := 1.3       # m between Hunters
const YAW := 165.0     # degrees: turned to the camera, a little off

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = ["gunslinger", "juggernaut", "tender", "thief"]
	var emotes: Array = Truce.EMOTES.map(func(e): return e["id"])
	var times: Array = [0.5, 1.0]
	var speed := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--emotes="): emotes = Array(a.substr(9).split(",", false))
		if a.begins_with("--at="): times = Array(a.substr(5).split(",", false)).map(func(t): return float(t))
		if a.begins_with("--speed="): speed = float(a.substr(8))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px * ids.size(), frame_px)
	main.get_viewport().size = Vector2i(frame_px * ids.size(), frame_px)
	_stage(main)
	cam.fov = 30.0
	cam.position = Vector3(0, 1.15, 3.4 + GAP * ids.size() * 0.55)
	cam.look_at(Vector3(0, 0.85, 0))
	var models: Array = []
	for i in ids.size():
		var id := String(ids[i])
		var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id),
				"", PlayerLook.neutral(), id)
		model.set_meta("anim_seed", 1)
		holder.add_child(model)
		model.position.x = (i - (ids.size() - 1) * 0.5) * GAP
		model.rotation.y = deg_to_rad(YAW)
		(model.get_node("Warden/Sync") as Node).set_process(false)
		models.append(model)
	for k in 30:
		await tree.process_frame
	DirAccess.make_dir_recursive_absolute(out)
	for em in emotes:
		await _play(models, String(em), times, speed, out)
	print("EMOTE_SHOTS_DONE")
	tree.quit()

func _state(model: Node3D, em: String, t: float, speed: float) -> void:
	var face := model.rotation.y
	model.set_meta(WardenClips.STATE, {"grounded": true, "face": face, "emote": em, "emote_t": t,
			"vel": Vector3(-sin(face), 0.0, -cos(face)) * speed})

## Stand (or run) a moment, start the emote, and grab it at each time.
func _play(models: Array, em: String, times: Array, speed: float, out: String) -> void:
	for model in models:
		_state(model, "", 99.0, speed)
		for k in 12:
			(model.get_node("Warden/Sync") as Node).call("_process", DT)
	var t := 0.0
	for want in times:
		while t < float(want) - 0.001:
			t += DT
			for model in models:
				_state(model, em, t, speed)
				(model.get_node("Warden/Sync") as Node).call("_process", DT)
		await _grab(out.path_join("%s_%.1f.png" % [em, float(want)]))
