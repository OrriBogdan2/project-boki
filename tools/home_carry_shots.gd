extends "res://tools/clip_shots.gd"
## --home-carry-shots --shots-dir=<dir> [--size=512] [--ids=a,b]: every Hunter at home holding a Boki (a ball marks the
## socket the Boki rides at): <dir>/<id>_arms.png (in the arms), <id>_back.png (on the back), <id>_verb.png (a garden
## verb: weapon away, arms free) and <id>_idle.png (the weapon in hand), a front three-quarter view. Needs a renderer.

const DT := 1.0 / 30.0
const IDS := [
	"thief",
	"gunslinger",
	"bulwark",
	"ashwick",
	"dolm",
	"dredge",
	"gil",
	"juggernaut",
	"mage",
	"ostra",
	"rimewright",
	"tender",
	"archer"
]
const STATES := {"arms": {"act": "carry"}, "back": {"act": "pack"}, "verb": {"holster": true}, "idle": {}}
const VIEW_FOV := 34.0
const VIEW_AT := Vector3(1.9, 1.5, -3.4)  # a front three-quarter view; the model faces -Z


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
	DirAccess.make_dir_recursive_absolute(out)
	for id in ids:
		await _hunter(String(id), out)
	print("HOME_CARRY_SHOTS_DONE")
	tree.quit()


func _hunter(id: String, out: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var poser := model.get_node_or_null("Warden/Native")
	if poser == null:
		poser = model.get_node("Warden/Sync")
	poser.set_process(false)
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	ball.scale = Vector3.ONE * 0.3
	holder.add_child(ball)
	cam.fov = VIEW_FOV
	var height := 1.7 * absf(model.scale.y)
	cam.position = VIEW_AT * height / 1.7
	cam.look_at(Vector3(0.0, height * 0.55, 0.0))
	for st in STATES:
		var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "fired": 99.0}
		s.merge(STATES[st])
		model.set_meta(WardenClips.STATE, s)
		for k in 25:
			poser.call("_process", DT)
		ball.visible = model.has_meta(WardenCarry.SOCKET)
		ball.global_position = model.get_meta(WardenCarry.SOCKET, Vector3.ZERO)
		await _grab(out.path_join("%s_%s.png" % [id, st]))
	ball.queue_free()
	model.queue_free()
	await tree.process_frame
