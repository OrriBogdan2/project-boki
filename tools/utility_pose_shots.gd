extends RefCounted
## --utility-pose-shots --warden=<id> --shots-dir=<dir> [--size=420] [--frames=8] [--yaw=125]:
## a Hero going through each belt
## move (throw, place, read, drink), driven through the game state (HunterAnim, then WardenClips) the way
## Hunter._anim_state feeds it (UtilityPose.fill): <dir>/<move>/f00.png... evenly across the move, at a close
## camera that shows the hand. Needs a renderer.

const DT := 1.0 / 30.0
const SECS := 1.2          # one run of a move, to see the whole of it (the real ones last their item's cast time)

var tree: SceneTree
var cam: Camera3D

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var id := "thief"
	var px := 420
	var frames := 8
	var yaw_deg := 125.0     # turned so the left (free) hand faces the camera
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--warden="): id = a.substr(9)
		if a.begins_with("--size="): px = int(a.substr(7))
		if a.begins_with("--frames="): frames = int(a.substr(9))
		if a.begins_with("--yaw="): yaw_deg = float(a.substr(6))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	var holder := _stage(main)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var yaw := deg_to_rad(yaw_deg)
	model.rotation.y = yaw
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var anim := HunterAnim.new(model)
	for k in 30:
		await tree.process_frame
	var sync := model.get_node_or_null("Warden/Sync")
	if sync:
		sync.set_process(false)
	for mv in UtilityPose.MOVES:
		DirAccess.make_dir_recursive_absolute(out.path_join(mv))
		var n := int(SECS / DT)
		var shot := 0
		for step in n:
			var p := float(step) / float(n - 1)
			var s := {"vel": Vector3.ZERO, "face": yaw, "grounded": true, "crouch": 0.0, "fired": 99.0,
				"drink": -1.0, "util": -1.0}
			if mv == "drink":
				s["drink"] = p
			else:
				s["util"] = p
				s["util_move"] = mv
				if mv == "place":
					s["crouch"] = UtilityPose.weight(mv, p)
			anim.update(DT, s)
			if sync:
				sync.call("_process", DT)
			if step * frames / n == shot and shot < frames:
				var hp := model.to_local(anim.hand_l.global_position) if anim.hand_l else Vector3.ZERO
				print("UPOSE_HAND %s f%02d %s" % [mv, shot, hp.snappedf(0.01)])
				_aim()
				await _grab(out.path_join(mv).path_join("f%02d.png" % shot))
				shot += 1
	print("UTILITY_POSE_SHOTS_DONE ", frames)
	tree.quit()

func _aim() -> void:
	cam.fov = 28.0
	cam.position = Vector3(0, 1.3, 5.0)
	cam.look_at(Vector3(0, 0.9, 0))

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)

func _stage(main: Node) -> Node3D:
	var holder := Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
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
	return holder
