extends RefCounted
## --clip-shots --warden=<id> --shots-dir=<dir> [--clips=a,b] [--fps=15] [--size=480] [--yaw=deg] [--turn] [--match]
## [--strafe=<kmove>]:
## a Hero's hand-keyed clips frame by frame in the game's renderer (ART-1 approval sheets): <dir>/<clip>/f000.png...,
## and with --turn a turntable in <dir>/turntable/. Needs a renderer. ffmpeg makes the GIFs and sheets.

var ground_col := Color("4f7a3e")
var holder: Node3D
var cam: Camera3D
var tree: SceneTree
var frame_px := 480

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var id := "juggernaut"
	var wanted: Array = []
	var fps := 15.0
	var yaw := 150.0
	var turn := false
	var game_cam := false
	var true_cam := false
	var dist := 5.2
	var at_y := 0.82
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--warden="): id = a.substr(9)
		if a.begins_with("--clips="): wanted = Array(a.substr(8).split(",", false))
		if a.begins_with("--fps="): fps = float(a.substr(6))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
		if a.begins_with("--yaw="): yaw = float(a.substr(6))
		if a.begins_with("--dist="): dist = float(a.substr(7))
		if a.begins_with("--at="): at_y = float(a.substr(5))
		if a == "--turn": turn = true
		if a == "--match": game_cam = true
		if a == "--true-cam": true_cam = true      # (the game's own camera: 23 m out at 66 degrees, fov 32)
		if a.begins_with("--ground="): ground_col = Color(a.substr(9))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	model.rotation.y = deg_to_rad(yaw)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring and not game_cam and not true_cam:
		ring.visible = false
	if true_cam:
		cam.fov = 32.0
		cam.position = Vector3(0, 23.0 * sin(deg_to_rad(66.0)), 23.0 * cos(deg_to_rad(66.0)))
		cam.look_at(Vector3(0, 0.8, 0))
	elif game_cam:
		cam.fov = 8.0
		cam.position = Vector3(0, 21.0 * 1.0, 9.4)
		cam.look_at(Vector3(0, 0.8, 0))
	else:
		cam.fov = 30.0
		cam.position = Vector3(0, at_y + 0.25, dist)
		cam.look_at(Vector3(0, at_y, 0))
	for k in 30:
		await tree.process_frame       # (past the title's fade)
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	if OS.get_cmdline_user_args().has("--list-meshes"):
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).is_visible_in_tree() and not String(model.get_path_to(mi)).begins_with("Warden"):
				print("MESH ", model.get_path_to(mi), " ", (mi as Node3D).global_position)
	if turn:
		var dir := out.path_join("turntable")
		DirAccess.make_dir_recursive_absolute(dir)
		clips.force = {"clip": "idle", "t": 0.0}
		for k in 8:
			sync.call("_process", 1.0 / 30.0)
		for i in 48:
			model.rotation.y = TAU * i / 48.0
			clips.force = {"clip": "idle", "t": fmod(i / 15.0, 3.2)}
			sync.call("_process", 1.0 / 15.0)
			await _grab(dir.path_join("f%03d.png" % i))
		model.rotation.y = deg_to_rad(yaw)
	var names: Array = wanted if not wanted.is_empty() else Array(clips.lib.get_animation_list())
	for nm in names:
		var anim_name := String(nm)
		if anim_name == "turntable" or not clips.lib.has_animation(anim_name):
			continue
		var dir := out.path_join(anim_name)
		DirAccess.make_dir_recursive_absolute(dir)
		var length := clips.lib.get_animation(anim_name).length
		clips.force = {"clip": anim_name, "t": 0.0}
		for k in 8:
			sync.call("_process", 1.0 / 30.0)
		var n := int(ceil(length * fps)) + 1
		for i in n:
			var t := minf(float(i) / fps, length - 0.001)
			clips.force = {"clip": anim_name, "t": t}
			sync.call("_process", 1.0 / fps)
			await _grab(dir.path_join("f%03d.png" % i))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--strafe="):
			await _strafe(model, sync, clips, out, a.substr(9), fps)
	if OS.get_cmdline_user_args().has("--moods"):
		await _moods(model, sync, clips, out)
	print("CLIP_SHOTS_DONE")
	tree.quit()

## --strafe=<kmove>: the live legs at full stick in each of AnimStrafeCheck's directions, facing -Z with that move
## held mid-clip on the upper body: <dir>/strafe_<d>/f000.png...
func _strafe(model: Node3D, sync: Node, clips: WardenClips, out: String, km: String, fps: float) -> void:
	var checker := preload("res://tools/anim_strafe_check.gd")
	var mv: Dictionary = clips.d.get("kmoves", {}).get(km, {})
	var half := clips.lib.get_animation(String(mv["clip"])).length * 0.5 if mv.has("clip") else 0.0
	for nm in checker.DIRS:
		var dir := out.path_join("strafe_" + String(nm))
		DirAccess.make_dir_recursive_absolute(dir)
		var s := {"vel": checker.DIRS[nm] * checker.SPEED, "face": 0.0, "grounded": true}
		if half > 0.0:
			s.merge({"kmove": km, "kmove_t": half})
		model.set_meta(WardenClips.STATE, s)
		for k in 30:
			sync.call("_process", 1.0 / 30.0)
		for i in 8:
			sync.call("_process", 1.0 / fps)
			await _grab(dir.path_join("f%03d.png" % i))
	model.set_meta(WardenClips.STATE, {})

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)

func _stage(main: Node) -> void:
	holder = Node3D.new()
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
	ground.material_override = Models.toon(ground_col, false)
	holder.add_child(ground)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()

## --moods: one frame of each face a Hero's mood data draws (WardenMood), <dir>/moods/<mood>.png.
func _moods(model: Node3D, sync: Node, clips: WardenClips, out: String) -> void:
	var dir := out.path_join("moods")
	DirAccess.make_dir_recursive_absolute(dir)
	clips.force = {"clip": "idle", "t": 0.0}
	var states := {"calm": {}, "happy": {"emote": "x"}, "angry": {"kmove": "bul_smash"},
		"determined": {"kmove": "bul_guard"}, "sad": {"downed": true}}
	for nm in states:
		model.set_meta(WardenClips.STATE, states[nm])
		for k in 20:
			sync.call("_process", 1.0 / 30.0)
		await _grab(dir.path_join("%s.png" % nm))
	model.set_meta(WardenMood.FLARE, true)
	for k in 30:
		sync.call("_process", 1.0 / 30.0)
	await _grab(dir.path_join("flare.png"))
	model.set_meta(WardenMood.FLARE, false)
