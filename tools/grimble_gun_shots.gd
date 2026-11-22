extends RefCounted
## --grimble-gun-shots --shots-dir=<dir> [--warden=dredge] [--yaw=2.2] [--size=1600]: a Warden idle and mid-fire
## (HunterAnim, clips and aim bones) at the match camera and at eye level, <dir>/<id>_{idle,fire}_{game,eye}.png.
## Proof that one gun is drawn: on the hip at rest, in the hand when firing, never both. Needs a renderer.

const SETTLE := 90  # frames of HunterAnim before an idle shot
const FIRE_FRAMES := 24  # frames after the trigger (fired 0 -> 0.4 s)
const CAM_PITCH := 66.0  # degrees: the default match camera (CamRig STYLES "default")
const CAM_DIST := 6.5  # m from the hunter (the match camera is 23: the same angle, closer so he fills the frame)
const CAM_FOV := 32.0
const EYE_DIST := 5.2  # m, eye level close shot
const EYE_FOV := 30.0

var holder: Node3D
var cam: Camera3D
var tree: SceneTree


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var id := "dredge"
	var yaw := 2.2
	var px := 1600
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--warden="):
			id = a.substr(9)
		if a.begins_with("--yaw="):
			yaw = float(a.substr(6))
		if a.begins_with("--size="):
			px = int(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	_stage(main)
	for k in 30:
		await tree.process_frame  # (past the title's fade)
	for pose in ["idle", "fire"]:
		for view in ["game", "eye"]:
			await _shot(id, pose, view, yaw, out.path_join("%s_%s_%s.png" % [id, pose, view]))
	print("GRIMBLE_GUN_SHOTS_DONE")
	tree.quit()


func _shot(id: String, pose: String, view: String, yaw: float, path: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	m.rotation.y = yaw
	holder.add_child(m)
	(m.get_node_or_null("TeamRing") as Node3D).visible = false
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var an := HunterAnim.new(m)
	var s := {"grounded": true, "fired": 99.0, "face": yaw}
	for i in SETTLE:
		an.update(1.0 / 60.0, s)
		sync.call("_process", 1.0 / 60.0)
	if pose == "fire":
		for i in FIRE_FRAMES:
			s["fired"] = float(i) / 60.0
			an.update(1.0 / 60.0, s)
			sync.call("_process", 1.0 / 60.0)
	print("GUN_NODES %s %s %s" % [id, pose, _gun_report(m)])
	_aim_camera(view)
	for k in 3:
		await tree.process_frame  # (frame_post_draw never fires on some workers)
	var img := tree.root.get_texture().get_image()
	if img != null:
		img.save_png(path)
	m.free()


## The visible meshes of the Gun node (the procedural weapon, hidden when the .glb carries its own) as name list.
func _gun_report(m: Node) -> String:
	var gun := m.get_node_or_null("Rig/Torso/Aim/Gun")
	var names := []
	if gun:
		for mi in gun.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).is_visible_in_tree():
				names.append(String(mi.name))
	return "gun_node_visible_meshes=%s" % [names]


func _aim_camera(view: String) -> void:
	if view == "game":
		var p := deg_to_rad(CAM_PITCH)
		cam.fov = CAM_FOV
		cam.position = Vector3(0, 0.9, 0) + Vector3(0, sin(p), cos(p)) * CAM_DIST
		cam.look_at(Vector3(0, 0.9, 0))
	else:
		cam.fov = EYE_FOV
		cam.position = Vector3(0, 1.0, EYE_DIST)
		cam.look_at(Vector3(0, 0.95, 0))


func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment(
		{"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0}
	)
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()
