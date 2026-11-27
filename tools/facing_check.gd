extends "res://tools/clip_shots.gd"
## --facing-check [--shots-dir=<dir>] [--size=640]: every Hunter built the way the match builds it (Models.hunter),
## turned by the match's own face rule (Hunter._physics: face = atan2(-aim.x, -aim.y); Hunter.render: basis =
## Basis(UP, face)), must FACE its aim. The check measures the horizontal forward of its skeleton at rest (up x
## (right thigh - left thigh): the hips, not the shoulders, which a stance twists on purpose) against the aim at four
## aims and prints the worst error per Hunter (FACING <name> ...); more than MAX_ERR_DEG fails. With --shots-dir
## (needs a renderer): eye_ / game_ / rest_<name>.png, one cell per Hunter, the camera in front at eye level (the aim
## is toward it) and at the game's view; rest_ has the idle clip off. No team ring.

const MAX_ERR_DEG := 20.0  # a Hunter facing its aim is within a few degrees; a backwards model is ~180
const AIMS_DEG := [0.0, 90.0, 180.0, 270.0]  # aim directions on the ground, deg from +Z toward +X
## owner name -> archetype id, in the sheet's order
const HUNTERS := [
	["Vex", "gunslinger"],
	["Kael", "juggernaut"],
	["Lace", "archer"],
	["Albert", "bulwark"],
	["Sparkle", "mage"],
	["Cinder", "ashwick"],
	["Grimble", "dredge"],
	["Meeko", "tender"],
	["Neve", "rimewright"],
	["Tenzo", "dolm"],
	["Motley", "ostra"],
	["Sable", "thief"],
	["Gil", "gil"],
]
const EYE_CAM := [Vector3(0.0, 1.3, 5.5), Vector3(0.0, 0.9, 0.0), 42.0]  # eye level, 5.5 m in front, fov 42
const FRONT_FACE := PI  # the face (yaw) of an aim straight at the camera's side (+Z): atan2(-0, -1)
const GAME_CAM := [Vector3(0.0, 21.0, 9.4), 8.0]  # the match view of clip_shots --match: from above and in front, fov 8


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
	var shots := not out.is_empty()
	if shots:
		DirAccess.make_dir_recursive_absolute(out)
		if main.get("fade") != null:
			main.fade.reveal(0.01)
		main.get_window().size = Vector2i(frame_px, frame_px)
		main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	var worst := 0.0
	var rows := []
	for h in HUNTERS:
		var id: String = h[1]
		var model := await _spawn(id, FRONT_FACE)
		var errs := []
		var e := 0.0
		for deg: float in AIMS_DEG:
			var aim := Vector2(sin(deg_to_rad(deg)), cos(deg_to_rad(deg)))
			model.rotation.y = atan2(-aim.x, -aim.y)  # (the match's face rule)
			errs.append(_error_deg(model, aim))
			e = maxf(e, absf(errs[-1]))
		worst = maxf(worst, e)
		rows.append({"name": h[0], "id": id, "err_deg": errs, "worst": e, "ok": e <= MAX_ERR_DEG})
		print("FACING %s (%s) worst %.1f deg %s" % [h[0], id, e, errs])
		if shots:
			model.rotation.y = FRONT_FACE
			_cam_eye()
			await _grab(out.path_join("eye_%s.png" % h[0]))
			_cam_game()
			await _grab(out.path_join("game_%s.png" % h[0]))
			_cam_eye()
			model.get_node("Warden").propagate_call("set_process", [false])
			WardenGlb.skeleton(model.get_node("Warden")).reset_bone_poses()  # (rest pose: the clips' stance off)
			await _grab(out.path_join("rest_%s.png" % h[0]))
		model.queue_free()
		await tree.process_frame
	if shots:
		var f := FileAccess.open(out.path_join("facing.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, "\t"))
	print("FACING_CHECK %s worst %.1f deg" % ["OK" if worst <= MAX_ERR_DEG else "FAIL", worst])
	tree.quit(0 if worst <= MAX_ERR_DEG else 1)


## The Hunter as the match builds it, standing still facing `face`, fed the anim state the match gives it
## (Hunter._anim_state: grounded, face, look), ring hidden.
func _spawn(id: String, face: float) -> Node3D:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	model.rotation.y = face
	for k in 30:
		model.set_meta(
			WardenClips.STATE, {"grounded": true, "face": face, "look": Vector3(sin(face + PI), 0.0, cos(face + PI))}
		)
		await tree.process_frame
	return model


## Degrees between the skeleton's horizontal forward and `aim` (x, z).
func _error_deg(model: Node3D, aim: Vector2) -> float:
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	sk.reset_bone_poses()  # (the rest pose: the idle clip's weight shifts and turns vary run to run)
	var left := _bone_pos(sk, "thigh.L")
	var right := _bone_pos(sk, "thigh.R")
	var fwd := Vector3.UP.cross(right - left)
	return rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(aim))


func _bone_pos(sk: Skeleton3D, bone: String) -> Vector3:
	return sk.to_global(sk.get_bone_global_pose(WardenSkeleton.find(sk, bone)).origin)


func _cam_eye() -> void:
	cam.fov = EYE_CAM[2]
	cam.position = EYE_CAM[0]
	cam.look_at(EYE_CAM[1])


func _cam_game() -> void:
	cam.fov = GAME_CAM[1]
	cam.position = GAME_CAM[0]
	cam.look_at(Vector3(0, 0.8, 0))
