extends RefCounted
## --rig-hands-shots --glb=<file> --shots-dir=<dir> [--hands=RightHand,LeftHand] [--front=-z] [--curl=60]
## [--curl-axis=z] [--tag=name]: stills of one rig .glb (no Hunter data, any rig):
## <tag>_game.png (the match camera, true pixels x4),
## <tag>_<hand>_front.png and <tag>_<hand>_side.png (eye level on each hand: fingers and what the hand holds).
## --curl closes the finger bones (Thumb/Index/Middle/Ring/Pinky joints) by that many degrees about their local axis.
## Needs a renderer (jobq --needs gpu). Used for the rig-pipeline before/after sheets (docs/art/wardens/V95_SWAP.md).

const CAM_PITCH := 66.0  # degrees: the default match camera (CamRig STYLES "default")
const CAM_DIST := 23.0
const CAM_FOV := 32.0
const CLOSE_DIST := 0.5  # m: the eye-level camera from the hand
const CLOSE_FOV := 30.0
const FINGER := "(Thumb|Index|Middle|Ring|Pinky|thumb|fing)"

var tree: SceneTree
var cam: Camera3D


func run(main: Node) -> void:
	tree = main.get_tree()
	var glb := ""
	var out := ""
	var tag := "rig"
	var hands := PackedStringArray(["RightHand", "LeftHand"])
	var front := Vector3(0, 0, -1)
	var curl := 0.0
	var axis := Vector3.BACK
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--glb="):
			glb = a.substr(6)
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--tag="):
			tag = a.substr(6)
		if a.begins_with("--hands="):
			hands = a.substr(8).split(",")
		if a.begins_with("--front="):
			front = Vector3(0, 0, 1) if a.substr(8) == "z" else Vector3(0, 0, -1)
		if a.begins_with("--curl="):
			curl = float(a.substr(7))
		if a.begins_with("--curl-axis="):
			axis = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}[a.substr(12)]
	DirAccess.make_dir_recursive_absolute(out)
	var holder := Node3D.new()
	main.add_child(holder)
	_stage(holder)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_file(glb, state)
	var model := doc.generate_scene(state) as Node3D
	holder.add_child(model)
	var sk := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	if curl > 0.0:
		_curl(sk, curl, axis)
	await _frames(4)
	await _game(model, out.path_join(tag + "_game.png"))
	for h in hands:
		var bi := sk.find_bone(h)
		if bi < 0:
			push_error("no bone " + h)
			continue
		var at := sk.global_transform * sk.get_bone_global_pose(bi).origin
		var side := front.cross(Vector3.UP)
		var right := h.contains("Right") or h.ends_with(".R")
		for view in [["front", front], ["side", side if right else -side]]:
			cam.fov = CLOSE_FOV
			cam.global_position = at - (view[1] as Vector3) * CLOSE_DIST
			cam.look_at(at)
			await _frames(2)
			_grab().save_png(out.path_join("%s_%s_%s.png" % [tag, h.replace(".", "_"), view[0]]))
	print("RIG_HANDS_SHOTS_DONE ", out)
	tree.quit()


func _stage(holder: Node3D) -> void:
	var env := WorldEnvironment.new()
	env.environment = Look.environment(
		{"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0}
	)
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()


func _curl(sk: Skeleton3D, deg: float, axis: Vector3) -> void:
	var re := RegEx.create_from_string(FINGER)
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i)
		if re.search(nm) and not nm.ends_with("4") and not nm.ends_with("_End"):
			var rest := sk.get_bone_rest(i).basis.get_rotation_quaternion()
			sk.set_bone_pose_rotation(i, rest * Quaternion(axis, deg_to_rad(deg)))


func _game(model: Node3D, path: String) -> void:
	var p := deg_to_rad(CAM_PITCH)
	var mid := Vector3(0, 1.0, 0)
	cam.fov = CAM_FOV
	cam.position = mid + Vector3(0, sin(p), cos(p)) * CAM_DIST
	cam.rotation = Vector3(-p, 0, 0)
	await _frames(3)
	var img := _grab()
	var a := cam.unproject_position(model.position + Vector3(-1.1, 2.2, -1.0))
	var b := cam.unproject_position(model.position + Vector3(1.1, -0.3, 1.0))
	var crop := img.get_region(Rect2i(Vector2i(a), Vector2i(b - a)))
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png(path)


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _grab() -> Image:
	var img := tree.root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
