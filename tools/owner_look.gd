extends "res://tools/clip_shots.gd"
## --owner-look --shots-dir=<dir> --wardens=<arch> [--only=front|game|vid]: owner view render of one Hunter as the game
## plays it (Models.hunter + the model's pose node). Scratch-tree tool (nothing of the game changes).
##   <dir>/<arch>/front.png        idle, eye-level lens-shift camera, face side, grey background (1200x1600)
##   <dir>/<arch>/game_raw.png     match camera (fov 8, 66 deg), running, 1024 px
##   <dir>/<arch>/vf/f####.jpg     move_front frames (1080), <dir>/<arch>/vg/f####.jpg move_game frames (1080)
##   <dir>/<arch>/marks.txt        glb, tris, body height, eye height

const DT := 1.0 / 30.0
const RUN_MPS := 5.0
const FACE_YAW := PI                  # forward = +Z = toward the eye-level camera
const SEGS := [["Idle", 1.5], ["Run (slow circle)", 3.0], ["Attack", 1.5], ["Jump", 1.0], ["Idle", 1.0]]

var ground: MeshInstance3D
var env_node: WorldEnvironment
var env_game: Environment
var env_grey: Environment
var face_yaw := PI
var true_h := 0.0
var true_y0 := 0.0

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = []
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--only="): only = a.substr(7)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	_stage_extra()
	await tree.create_timer(2.5).timeout
	for id in ids:
		await _hunter(main, String(id), out.path_join(String(id)), only)
	print("OWNER_LOOK_DONE ", ids.size())
	tree.quit()

func _stage_extra() -> void:
	for c in holder.get_children():
		if c is WorldEnvironment:
			env_node = c
		elif c is MeshInstance3D:
			ground = c
	env_game = env_node.environment
	env_grey = Environment.new()
	env_grey.background_mode = Environment.BG_COLOR
	env_grey.background_color = Color(0.52, 0.52, 0.52)
	env_grey.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_grey.ambient_light_color = Color(0.8, 0.8, 0.8)
	env_grey.ambient_light_energy = 0.6

func _size(main: Node, w: int, h: int) -> void:
	main.get_window().size = Vector2i(w, h)
	main.get_viewport().size = Vector2i(w, h)
	for i in 4:
		await tree.process_frame

func _match_cam() -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 8.0
	cam.position = Vector3(0, 21.0, 9.4)
	cam.look_at(Vector3(0, 0.8, 0))

## Eye-level camera: at eye height E looking level (-Z), a lens shift frames feet to above the head. y0 = feet, span =
## the vertical extent shown, bottom = world y at the frame's bottom edge.
func _eye_cam(eye: float, bottom: float, span: float) -> void:
	var fov := 22.0
	var d := span / (2.0 * tan(deg_to_rad(fov * 0.5)))
	cam.rotation = Vector3.ZERO
	cam.position = Vector3(0, eye, d)
	var centre := bottom + span * 0.5
	var n := 0.05
	cam.set_frustum(span * n / d, Vector2(0.0, (centre - eye) * n / d), n, 60.0)

func _body_box(model: Node3D) -> Array:
	var lo := 1e9
	var hi := -1e9
	var tris := 0
	for mi in model.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var bb := m.global_transform * m.get_aabb()
		lo = minf(lo, bb.position.y)
		hi = maxf(hi, bb.end.y)
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
				tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return [lo, hi - lo, tris]

## World y of the eyes: a third of the way up the skull from the Head joint (Meshy's Head -> head_end).
func _eye_y(poser: Node, bx: Array) -> float:
	var sk := poser.get("skel") as Skeleton3D
	if sk != null:
		var hb := sk.find_bone("Head")
		var he := sk.find_bone("head_end")
		if he < 0:
			he = sk.find_bone("HeadTop_End")
		if hb >= 0 and he >= 0:
			var a := (sk.global_transform * sk.get_bone_global_pose(hb)).origin.y
			var b := (sk.global_transform * sk.get_bone_global_pose(he)).origin.y
			return lerpf(a, b, 0.4)
	return float(bx[0]) + float(bx[1]) * 0.9

## [first row, last row] of pixels that differ from the corner colour (the background), -1 if none.
func _extent(img: Image) -> Vector2i:
	var bg := img.get_pixel(0, 0)
	var top := -1
	var bot := -1
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) > 0.09:
				if top < 0:
					top = y
				bot = y
				break
	return Vector2i(top, bot)

func _state(clip: String, yaw: float, t: float) -> Dictionary:
	var fw := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var s := {"face": yaw, "grounded": true, "vel": Vector3.ZERO}
	match clip:
		"run":
			s["vel"] = fw * RUN_MPS
		"jump":
			s["grounded"] = false
			s["vel"] = fw * 4.0 + Vector3(0.0, 3.0 - t * 6.0, 0.0)
	return s

func _grab(path: String, jpg := false) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	if jpg:
		img.save_jpg(path, 0.92)
	else:
		img.save_png(path)

func _hunter(main: Node, id: String, dir: String, only: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 30:
		await tree.process_frame
	var poser := model.get_node_or_null("Warden/Native")
	var native := poser != null
	if poser == null:
		poser = model.get_node("Warden/Sync")
	poser.set_process(false)
	var bx := _body_box(model)
	var eye := _eye_y(poser, bx)
	var y0: float = bx[0]
	var h: float = bx[1]
	var f := FileAccess.open(dir.path_join("marks.txt"), FileAccess.WRITE)
	f.store_string("kind %s glb %s tris %d body_h %.3f feet_y %.3f eye_y %.3f\n" % [
		"native" if native else "contract", WardenGlb.path(id), bx[2], h, y0, eye])
	f.close()
	# ---- front.png: idle, face side, eye level, grey
	if only == "" or only == "front":
		await _size(main, 1200, 1600)
		ground.visible = false
		env_node.environment = env_grey
		model.rotation.y = FACE_YAW
		model.set_meta(WardenClips.STATE, _state("idle", FACE_YAW, 0.0))
		for k in 70:
			poser.call("_process", DT)
		# face the camera: the Head -> headfront bones' horizontal heading, turned onto +Z (the idle clip twists the hips)
		var yaw := FACE_YAW
		var sk := poser.get("skel") as Skeleton3D
		if sk != null and sk.find_bone("headfront") >= 0 and sk.find_bone("Head") >= 0:
			var dv := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("headfront"))).origin \
				- (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin
			yaw = FACE_YAW - atan2(dv.x, dv.z)
			model.rotation.y = yaw
			poser.call("_process", DT)
		face_yaw = yaw
		print("FACE ", id, " headfront=", sk != null and sk.find_bone("headfront") >= 0, " yaw=", snappedf(rad_to_deg(yaw), 0.1))
		# frame it: the real extent comes from the rendered pixels (skinned AABBs read small), two correction passes
		var span := h / 0.84
		var bottom := y0 - 0.08 * span
		for pass_i in 3:
			_eye_cam(eye, bottom, span)
			await _grab(dir.path_join("front.png"))
			var img := Image.load_from_file(dir.path_join("front.png"))
			var ext := _extent(img)
			if ext.y < 0:
				break
			var hh := float(img.get_height())
			var top_y := bottom + span * (1.0 - float(ext.x) / hh)
			var bot_y := bottom + span * (1.0 - float(ext.y) / hh)
			h = top_y - bot_y
			y0 = bot_y
			span = h / 0.84
			bottom = y0 - 0.08 * span
		true_h = h
		true_y0 = y0
	# ---- game_raw.png: match camera, running (3/4 toward the camera)
	if only == "" or only == "game":
		await _size(main, 1024, 1024)
		ground.visible = true
		env_node.environment = env_game
		var yaw := face_yaw - 0.6
		model.rotation.y = yaw
		model.set_meta(WardenClips.STATE, _state("run", yaw, 0.0))
		for k in 50:
			poser.call("_process", DT)
		_match_cam()
		await _grab(dir.path_join("game_raw.png"))
	# ---- the 8 s move sequence, two cameras per frame
	if only == "" or only == "vid":
		await _size(main, 1080, 1080)
		DirAccess.make_dir_recursive_absolute(dir.path_join("vf"))
		DirAccess.make_dir_recursive_absolute(dir.path_join("vg"))
		model.rotation.y = face_yaw
		model.position = Vector3.ZERO
		model.set_meta(WardenClips.STATE, _state("idle", face_yaw, 0.0))
		for k in 40:
			poser.call("_process", DT)
		h = true_h if true_h > 0.0 else h
		y0 = true_y0 if true_h > 0.0 else y0
		var span := h * 1.5
		var frame := 0
		var swing := 0
		for seg in SEGS:
			var name: String = seg[0]
			var secs: float = seg[1]
			var n := int(round(secs / DT))
			for i in n:
				var t := i * DT
				var yaw := face_yaw
				var st: Dictionary
				model.position = Vector3.ZERO
				if name.begins_with("Run"):
					yaw = face_yaw + TAU * (t / secs)
					st = _state("run", yaw, t)
				elif name == "Attack":
					st = _state("idle", yaw, t)
					if i == 0 or (native and float(poser.get("attack_left")) <= 0.05):
						swing += 1
					st["swing_n"] = swing
				elif name == "Jump":
					st = _state("jump", yaw, t)
					model.position.y = maxf(0.0, 3.0 * t - 3.0 * t * t)
				else:
					st = _state("idle", yaw, t)
				model.rotation.y = yaw
				model.set_meta(WardenClips.STATE, st)
				poser.call("_process", DT)
				var nm := "f%04d.jpg" % frame
				ground.visible = false
				env_node.environment = env_grey
				_eye_cam(eye, y0 - 0.07 * span, span)
				await _grab(dir.path_join("vf").path_join(nm), true)
				ground.visible = true
				env_node.environment = env_game
				_match_cam()
				await _grab(dir.path_join("vg").path_join(nm), true)
				frame += 1
	model.queue_free()
