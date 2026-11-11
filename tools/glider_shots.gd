extends "res://tools/clip_shots.gd"
## --glider-shots --shots-dir=<dir> [--size=480]: every glider skin open over a Hunter, in two team colours
## (<dir>/<skin>_<team index>.png), and the farm's bare canopy (<dir>/<skin>_farm.png), for before/after
## frames of a change to how a canopy is built or coloured. Needs a renderer.

const ARCH := "gunslinger"
const TEAMS := [0, 2]           # Data.TEAM_COLORS indices: orange and pink, cloth and stripe both show
const SETTLE := 20              # frames before a grab

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 30.0
	cam.position = Vector3(0, 4.2, 4.6)
	cam.look_at(Vector3(0, 1.7, 0))
	for g in Gliders.LIST:
		var id := String(g["id"])
		for t in TEAMS:
			await _hunter(id, t, out.path_join("%s_%d.png" % [id, t]))
		await _farm(id, out.path_join("%s_farm.png" % id))
	print("GLIDER_SHOTS_DONE ", Gliders.LIST.size())
	tree.quit()

func _hunter(id: String, team: int, path: String) -> void:
	var look := PlayerLook.neutral()
	look["glider"] = id
	var model := Models.hunter(Arch.weight(ARCH), Data.TEAM_COLORS[team], Arch.signature(ARCH), "", look, ARCH)
	holder.add_child(model)
	model.rotation.y = deg_to_rad(155.0)
	var gl := model.get_node("Rig/Torso/Glider") as Node3D
	gl.visible = true
	gl.rotation.x = 0.25
	for k in SETTLE:
		await tree.process_frame
	await _grab(path)
	model.queue_free()

func _farm(id: String, path: String) -> void:
	var can := MeshInstance3D.new()
	Gliders.dress(can, id, Data.TEAM_COLORS[0], UI.ACCENT)
	can.position = Vector3(0, 1.4, 0)
	can.rotation = Vector3(-0.35, deg_to_rad(155.0), 0)
	holder.add_child(can)
	for k in SETTLE:
		await tree.process_frame
	await _grab(path)
	can.queue_free()
