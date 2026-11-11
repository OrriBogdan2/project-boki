extends "res://tools/clip_shots.gd"
## --turn-shots --shots-dir=<dir> [--wardens=a,b] [--size=320]: the before/after strip of turning on the spot
## (TurnStep, WardenTurn). Per Hunter, in <dir>/<id>/: off/ and on/, frames every STEP s while the standing aim
## swings 180° over SWING s and the feet settle, from a fixed camera above the side. Needs a renderer.

const SWING := 0.3            # s: the 180° swing (as --turn-step-check)
const FILM := 1.4             # s filmed from the swing's start
const STEP := 0.1             # s between frames
const DT := 1.0 / 60.0

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = ["gunslinger", "juggernaut", "archer"]
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
		for mode in ["off", "on"]:
			await _hunter(String(id), out.path_join(String(id)).path_join(mode), mode == "on")
	print("TURN_SHOTS_DONE ", ids.size())
	tree.quit()

func _hunter(id: String, dir: String, step_on: bool) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var anim := HunterAnim.new(model)
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	if not step_on:
		clips.turn = null
	cam.position = Vector3(1.6, 2.9, 2.6)
	cam.look_at(Vector3(0, 0.55, 0))
	var t := -0.6
	var i := 0
	while t < FILM:
		var face := PI * clampf(t / SWING, 0.0, 1.0)
		model.rotation.y = face
		anim.update(DT, {"vel": Vector3.ZERO, "face": face, "grounded": true, "fired": 99.0})
		sync.call("_process", DT)
		if t >= i * STEP - 0.0001:
			await _grab(dir.path_join("f%02d.png" % i))
			i += 1
		t += DT
	model.queue_free()
	await tree.process_frame
