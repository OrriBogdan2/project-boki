extends "res://tools/clip_shots.gd"
## --turn-step-shots --shots-dir=<dir> [--wardens=a,b,c] [--size=320]: the aim flips 180 degrees under a standing
## Hunter (scripts/heroes/warden_turn.gd). Per Hunter, <dir>/<id>/f000.png is the frame before the flip, then one
## frame every 1/30 s for 0.4 s, seen from above and in front. Needs a renderer.

const DT := 1.0 / 60.0
const FRAMES := 14
const EVERY := 2          # sim frames per picture

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = ["archer", "gunslinger", "juggernaut"]     # light, medium, heavy
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
	print("TURN_STEP_SHOTS_DONE ", ids.size())
	tree.quit()

func _hunter(id: String, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var anim := HunterAnim.new(model)
	for k in 30:
		await tree.process_frame
	var tall := _height(model)
	cam.position = Vector3(0, tall * 2.0, tall * 1.7)
	cam.look_at(Vector3(0, tall * 0.4, 0))
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var face := deg_to_rad(90.0)
	for i in 90:
		_step(model, anim, sync, face)
	for i in FRAMES:
		await _grab(dir.path_join("f%03d.png" % i))
		if i == 0:
			face -= PI
		for k in EVERY:
			_step(model, anim, sync, face)
	model.queue_free()
	await tree.process_frame

func _step(model: Node3D, anim: HunterAnim, sync: Node, face: float) -> void:
	model.rotation.y = face
	anim.update(DT, {"vel": Vector3.ZERO, "face": face, "grounded": true, "fired": 99.0})
	sync.call("_process", DT)
