extends RefCounted
## --clip-shots --warden=<id> --shots-dir=<dir> [--clips=a,b] [--fps=15] [--size=480] [--yaw=deg] [--match]
## [--turn [--turn-clip=run_f]]
## [--carry [--heart]] [--cc] [--cast=<kmove> [--cast-speed=<m/s>]]: a Hero's hand-keyed clips frame by frame in the
## game's renderer (ART-1 approval sheets): <dir>/<clip>/f000.png..., and with --turn a turntable in
## <dir>/turntable/, with --flinch a hit mid-run in <dir>/flinch/ (--solid or --heavy: a harder hit), with --cc a stun,
## a root and Grounded standing in <dir>/cc_<state>/, with --cast a move pressed on the run (or standing,
## --cast-speed=0) in <dir>/cast_<kmove>/.
## --states: the game states (STATE_SHOTS) one after another as the match hands them over, on any model (contract
## clips or a Meshy-native one), <dir>/states/f###.png every 1/fps s; a native Hunter with its own kit-move clips (data
## "kmoves") also gets each move, standing and (a layered one) running, in <dir>/move_<id>_<stand|run>/ (--no-moves: the
## same moves without its own clips, Meshy's Attack for each: the "before"). --contract: the contract model even for a
## Meshy-native Hunter (the live look); --cam-y=<m>: the camera's height (eye level, knee level) looking at --at.
## --drop: every Hero in a row wearing the drop poses (WardenDropPose), <dir>/drop/<pose>_<view>.png.
## Needs a renderer. ffmpeg makes the GIFs and sheets.

const ClipCheck := preload("res://tools/clip_check.gd")

## --states: [state, the match's state for it (WardenClips.STATE), s it is held]
const STATE_SHOTS := [
	["idle", {"grounded": true}, 2.0],
	["walk", {"grounded": true, "vel": Vector3(0.0, 0.0, -1.5)}, 1.5],
	["run", {"grounded": true, "vel": Vector3(0.0, 0.0, -4.6)}, 1.5],
	["jump", {"grounded": false, "vel": Vector3(0.0, 2.0, -4.0)}, 1.2],
	["attack", {"grounded": true}, 1.6],
	["crouch", {"grounded": true, "crouch": 1.0, "vel": Vector3(0.0, 0.0, -1.2)}, 1.5],
]
const MOVE_SHOT := 1.2  # s of the kit's clock each native kit move is filmed for
## --states --views=match,eye,knee: each view's [fov, camera, looks at]; the states go to <dir>/states_<view>/ (match:
## the game's angle on a long lens, team ring on; eye: a standing person's eyes; knee: from knee height, up at him)
const STATE_VIEWS := {
	"match": [8.0, Vector3(0.0, 21.0, 9.4), Vector3(0.0, 0.8, 0.0)],
	"eye": [30.0, Vector3(0.0, 1.6, 5.6), Vector3(0.0, 0.95, 0.0)],
	"knee": [30.0, Vector3(0.0, 0.45, 5.6), Vector3(0.0, 0.95, 0.0)],
}
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
	var turn_clip := "idle"
	var game_cam := false
	var true_cam := false
	var dist := 5.2
	var at_y := 0.82
	var cam_y := -1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--warden="):
			id = a.substr(9)
		if a.begins_with("--clips="):
			wanted = Array(a.substr(8).split(",", false))
		if a.begins_with("--fps="):
			fps = float(a.substr(6))
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
		if a.begins_with("--yaw="):
			yaw = float(a.substr(6))
		if a.begins_with("--dist="):
			dist = float(a.substr(7))
		if a.begins_with("--at="):
			at_y = float(a.substr(5))
		if a.begins_with("--cam-y="):
			cam_y = float(a.substr(8))  # (camera height, m; default at + 0.25)
		if a == "--contract":
			WardenNative.contract_only = true  # (the contract model even where Meshy-native is on)
		if a == "--turn":
			turn = true
		if a.begins_with("--turn-clip="):
			turn_clip = a.substr(12)
		if a == "--match":
			game_cam = true
		if a == "--true-cam":
			true_cam = true  # (the game's own camera: 23 m out at 66 degrees, fov 32)
		if a.begins_with("--ground="):
			ground_col = Color(a.substr(9))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	if OS.get_cmdline_user_args().has("--drop"):
		await _drop_lineup(out)
		print("CLIP_SHOTS_DONE")
		tree.quit()
		return
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
		cam.position = Vector3(0, at_y + 0.25 if cam_y < 0.0 else cam_y, dist)
		cam.look_at(Vector3(0, at_y, 0))
	for k in 30:
		await tree.process_frame       # (past the title's fade)
	if OS.get_cmdline_user_args().has("--states"):
		var views: Array = []
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--views="):
				views = Array(a.substr(8).split(",", false))
		if views.is_empty():
			await _states(model, fps, out)
		for v in views:
			var vw: Array = STATE_VIEWS[v]
			cam.fov = float(vw[0])
			cam.position = vw[1]
			cam.look_at(vw[2])
			if ring:
				ring.visible = v == "match"
			await _states(model, fps, out, "states_" + String(v))
		print("CLIP_SHOTS_DONE")
		tree.quit()
		return
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
		var turn_len := clips.lib.get_animation(turn_clip).length
		clips.force = {"clip": turn_clip, "t": 0.0}
		for k in 8:
			sync.call("_process", 1.0 / 30.0)
		for i in 48:
			model.rotation.y = TAU * i / 48.0
			clips.force = {"clip": turn_clip, "t": fmod(i / 15.0, turn_len)}
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
	if OS.get_cmdline_user_args().has("--flinch"):
		await _flinch(model, sync, fps, out)
	if OS.get_cmdline_user_args().has("--cc"):
		await tree.create_timer(1.5).timeout  # (the title's logo fades in real time, not in frames)
		for key in ["stun", "rooted", "gnd"]:
			await _cc(model, sync, fps, out, key)
	var cast_speed := 4.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cast-speed="):
			cast_speed = float(a.substr(13))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cast="):
			await _cast(model, sync, fps, out, a.substr(7), cast_speed)
	if OS.get_cmdline_user_args().has("--moods"):
		await _moods(model, sync, clips, out)
	if OS.get_cmdline_user_args().has("--carry"):
		await _carry(model, sync, out)
	print("CLIP_SHOTS_DONE")
	tree.quit()


## --cast=<kmove>: moving at `speed` m/s (0: standing), the move is pressed 0.3 s in and let go at its clip's end;
## <dir>/cast_<kmove>/f###.png every 1/fps s for 0.6 s past that (the hand-over in, and back to the legs).
func _cast(model: Node3D, sync: Node, fps: float, out: String, kmove: String, speed: float) -> void:
	var dir := out.path_join("cast_" + kmove)
	DirAccess.make_dir_recursive_absolute(dir)
	var clips: WardenClips = sync.get("clips")
	clips.force = {}
	var s := {"vel": Vector3(0, 0, -speed), "face": model.rotation.y, "grounded": true}
	model.set_meta(WardenClips.STATE, s)
	for k in 45:
		sync.call("_process", 1.0 / 30.0)
	var length := clips.lib.get_animation(String(clips.d["kmoves"][kmove]["clip"])).length
	for i in int(fps * (0.3 + length + 0.6)):
		var t := float(i) / fps - 0.3
		if t >= 0.0 and t < length:
			s["kmove"] = kmove
			s["kmove_t"] = t
		else:
			s.erase("kmove")
		sync.call("_process", 1.0 / fps)
		await _grab(dir.path_join("f%03d.png" % i))

## --states: each STATE_SHOTS state fed to the model's pose node for its seconds; the attack is the kit's first move
## (contract clips) and one swing (a Meshy-native model).
func _states(model: Node3D, fps: float, out: String, sub := "states") -> void:
	var dir := out.path_join(sub)
	DirAccess.make_dir_recursive_absolute(dir)
	var poser := model.get_node_or_null("Warden/Native")
	if poser == null:
		poser = model.get_node("Warden/Sync")
	poser.set_process(false)
	var clips: WardenClips = poser.get("clips")
	var kmove := ""
	if clips:
		kmove = String((clips.d.get("kmoves", {}) as Dictionary).keys().front())
	var native := poser as WardenNative
	if native and OS.get_cmdline_user_args().has("--no-moves"):
		native.moves = null
		native.own_casts = false
	var i := 0
	for st in STATE_SHOTS:
		var s: Dictionary = (st[1] as Dictionary).duplicate()
		s["face"] = model.rotation.y
		model.set_meta(WardenClips.STATE, s)
		for k in int(float(st[2]) * fps):
			if st[0] == "attack":
				s["swing_n"] = 1
				s["kmove"] = kmove
				s["kmove_t"] = k / fps
			poser.call("_process", 1.0 / fps)
			await _grab(dir.path_join("f%03d.png" % i))
			i += 1
	print("STATES ", ", ".join(STATE_SHOTS.map(func(st): return "%s %.1fs" % [st[0], st[2]])))
	if native and OS.get_cmdline_user_args().has("--no-moves") or native and native.moves:
		await _native_moves(model, native, fps, out)


## The kit moves a native Hunter has its own clips for (data "kmoves"), each pressed on the spot, an upper-body one
## also on the run, held for MOVE_SHOT s of the kit's clock: <dir>/move_<id>_<stand|run>/f###.png.
func _native_moves(model: Node3D, native: WardenNative, fps: float, out: String) -> void:
	for km in native.d.get("kmoves", {}):
		var upper := bool(native.d["kmoves"][km].get("upper", false))
		for pace in ["stand", "run"] if upper else ["stand"]:
			var dir := out.path_join("move_%s_%s" % [km, pace])
			DirAccess.make_dir_recursive_absolute(dir)
			var s := {"grounded": true, "face": model.rotation.y, "kmove": km}
			if pace == "run":
				s["vel"] = Vector3(0.0, 0.0, -4.6)
			model.set_meta(WardenClips.STATE, s)
			for k in int(MOVE_SHOT * fps):
				s["kmove_t"] = k / fps
				native.call("_process", 1.0 / fps)
				await _grab(dir.path_join("f%03d.png" % k))


func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)


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
	ground.material_override = Models.toon(ground_col, false)
	holder.add_child(ground)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()


## --flinch: running at 4 m/s, a hit lands 0.2 s in; <dir>/flinch/f###.png every 1/fps s for 1 s.
func _flinch(model: Node3D, sync: Node, fps: float, out: String) -> void:
	var dir := out.path_join("flinch")
	DirAccess.make_dir_recursive_absolute(dir)
	var heavy := OS.get_cmdline_user_args().has("--heavy")
	var hit_k := Oomph.hit_strength(0.03, 2.0)  # a chip hit
	if OS.get_cmdline_user_args().has("--solid"):
		hit_k = Oomph.hit_strength(0.09, 8.0)
	if heavy:
		hit_k = Oomph.HEAVY_FLINCH
	var s := {
		"vel": Vector3(0, 0, -4.0),
		"face": model.rotation.y,
		"grounded": true,
		"hit_t": 99.0,
		"hit_k": hit_k,
		"hit_dir": Vector2(0, -1)
	}
	model.set_meta(WardenClips.STATE, s)
	for k in 30:
		sync.call("_process", 1.0 / 30.0)
	for i in int(fps):
		var t := float(i) / fps
		s["hit_t"] = t - 0.2 if t >= 0.2 else 99.0
		sync.call("_process", 1.0 / fps)
		await _grab(dir.path_join("f%03d.png" % i))


## --cc: standing, state `key` on from 0.2 s to 1.0 s; <dir>/cc_<key>/f###.png every 1/fps s for 1.2 s.
func _cc(model: Node3D, sync: Node, fps: float, out: String, key: String) -> void:
	var dir := out.path_join("cc_" + key)
	DirAccess.make_dir_recursive_absolute(dir)
	var s := {"vel": Vector3.ZERO, "face": model.rotation.y, "grounded": true}
	model.set_meta(WardenClips.STATE, s)
	for k in 30:
		sync.call("_process", 1.0 / 30.0)
	for i in int(fps * 1.2):
		var t := float(i) / fps
		s[key] = t >= 0.2 and t < 1.0
		sync.call("_process", 1.0 / fps)
		await _grab(dir.path_join("f%03d.png" % i))


## --drop: the 12 Heroes 1.6 m apart in each drop pose: aboard the rocket, the skydive, banking into a right steer,
## and a beat after the glider opens; side-on, and from behind and above (as the skydive camera sees them).
func _drop_lineup(out: String) -> void:
	var dir := out.path_join("drop")
	DirAccess.make_dir_recursive_absolute(dir)
	var ids: Array = ClipCheck.OWN_MODELS.keys()
	var models: Array = []
	for i in ids.size():
		var m := Models.hunter(
			Arch.weight(ids[i]), Data.TEAM_COLORS[0], Arch.signature(ids[i]), "", PlayerLook.neutral(), ids[i]
		)
		m.set_meta("anim_seed", 1)
		holder.add_child(m)
		m.position = Vector3((i - (ids.size() - 1) * 0.5) * 1.6, 1.2, 0.0)
		m.get_node("Warden/Sync").set_process(false)
		models.append(m)
	for k in 120:
		await tree.process_frame  # (past the title: 12 Heroes load slower than one)
	var poses := {
		"ride": {"rocket": true},
		"skydive": {"skydive": true},
		"bank": {"skydive": true, "bank": true},
		"open": {"gliding": true}
	}
	var views := {"side": [PI / 2.0, Vector3(0.0, 3.0, 30.0), 40.0], "behind": [0.0, Vector3(0.0, 14.0, 22.0), 48.0]}
	for v in views:
		var face := float(views[v][0])
		cam.position = views[v][1]
		cam.fov = float(views[v][2])
		cam.look_at(Vector3(0, 1.6, 0))
		for nm in poses:
			var s: Dictionary = {"vel": Vector3(0, -13.0, 0), "face": face, "grounded": false}
			s.merge(poses[nm], true)
			if s.has("bank"):  # (steering right of the facing)
				s["vel"] = Vector3(cos(face), 0.0, -sin(face)) * HunterFeel.dive_speed + Vector3(0, -13.0, 0)
			for k in 40:
				for m in models:
					(m as Node3D).rotation.y = face
					(m as Node3D).set_meta(WardenClips.STATE, s)
					(m as Node3D).get_node("Warden/Sync").call("_process", 1.0 / 30.0)
			await _grab(dir.path_join("%s_%s.png" % [nm, v]))


## --moods: one frame of each face a Hero's mood data draws (WardenMood), <dir>/moods/<mood>.png.
func _moods(model: Node3D, sync: Node, clips: WardenClips, out: String) -> void:
	var dir := out.path_join("moods")
	DirAccess.make_dir_recursive_absolute(dir)
	clips.force = {"clip": "idle", "t": 0.0}
	var states := {
		"calm": {},
		"happy": {"emote": "x"},
		"angry": {"kmove": "bul_smash"},
		"determined": {"kmove": "bul_guard"},
		"sad": {"downed": true}
	}
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


## --carry: the rescue carry on the walk (<dir>/carry/fNN.png, 8 frames), a ball at the socket for the Boki; with
## --heart the Heartspark carry on the run instead, the ball at the held mote.
func _carry(model: Node3D, sync: Node, out: String) -> void:
	var dir := out.path_join("carry")
	DirAccess.make_dir_recursive_absolute(dir)
	var heart := OS.get_cmdline_user_args().has("--heart")
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	ball.scale = Vector3.ONE * (0.15 if heart else 0.3)
	holder.add_child(ball)
	(sync.get("clips") as WardenClips).force = {}  # (the state plays, not the clip the shots forced)
	var state := {"vel": Vector3(0, 0, -3.6), "face": 0.0, "grounded": true}
	if heart:
		state["heart"] = true
	else:
		state["kmove"] = WardenCarry.MOVE
		state["kmove_t"] = 1.0
	model.set_meta(WardenClips.STATE, state)
	for k in 30:
		sync.call("_process", 1.0 / 30.0)
	for i in 8:
		for k in 4:
			sync.call("_process", 1.0 / 30.0)
		ball.global_position = model.get_meta(WardenCarry.MOTE if heart else WardenCarry.SOCKET, Vector3.ZERO)
		await _grab(dir.path_join("f%02d.png" % i))
	ball.queue_free()
