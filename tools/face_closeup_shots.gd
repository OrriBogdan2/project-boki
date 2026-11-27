extends RefCounted
## --face-closeup-shots --shots-dir=<dir> [--warden=<id>] [--size=900] [--tag=<name>]: <dir>/<tag>_<view>.png,
## head close-ups (front, 3/4 left, 3/4 right, eye-level side) of one Hunter's in-game model. Needs a renderer.

const VIEWS := {"front": 180.0, "q34l": 140.0, "q34r": -140.0, "side": 90.0}  # deg the model turns, camera fixed
const FOCUS := Vector3(0, 1.45, 0)  # m: face centre of a Hunter model
const DIST := 0.75  # m camera to face
var holder: Node3D
var cam: Camera3D
var tree: SceneTree


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var px := 900
	var id := "thief"
	var tag := "live"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--size="): px = int(a.substr(7))
		if a.begins_with("--warden="): id = a.substr(9)
		if a.begins_with("--tag="): tag = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	_stage(main)
	for k in 30:
		await tree.process_frame
	for v in VIEWS:
		await _shot(id, float(VIEWS[v]), out.path_join("%s_%s.png" % [tag, v]))
	print("FACE_CLOSEUP_DONE")
	tree.quit()


func _shot(id: String, yaw: float, path: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	(m.get_node_or_null("TeamRing") as Node3D).visible = false
	m.rotation_degrees.y = yaw
	for k in 3:
		await tree.process_frame
	var img := tree.root.get_texture().get_image()
	if img != null:
		img.save_png(path)
	m.free()


func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	var sky := {"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0}
	env.environment = Look.environment(sky)
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	cam = Camera3D.new()
	cam.fov = 22.0
	cam.position = FOCUS + Vector3(0, 0, DIST)
	holder.add_child(cam)
	cam.look_at(FOCUS)
	cam.make_current()
