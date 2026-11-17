extends RefCounted
## --cloth-shots --warden=<id> --shots-dir=<dir> [--scene=idle|run|dash|lmb] [--cam=game|orbit|side|back]
## [--fps=30] [--size=540] [--dash=pin_roll] [--lmb=arc_loose]: a Warden MOVING through the world (position advanced each frame, so a
## cloth chain feels the motion) in the game's renderer: <dir>/<scene>_<cam>/f000.png... (ffmpeg makes the MP4).
## --bench[=<n>] [--secs=<s>]: n copies (default 8) running in a ring, prints the mean frame time and the engine's
## mean process time (needs a real GPU for the frame time; compare a tree with the cloth bones against one without).
## Scenes: idle (3 s standing); run (0.5 s stand, then 4.6 m/s); dash (run, then the dash kit move, run on);
## lmb (run, an LMB kit move mid-way).

const ClipShots := preload("res://tools/clip_shots.gd")
const RUN := 4.6
const DASH := 5.8

var tree: SceneTree
var shots := ClipShots.new()
var fps := 30.0

func run(main: Node) -> void:
	tree = main.get_tree()
	var id := "archer"
	var out := "/tmp/cloth_shots"
	var scene := "run"
	var cam_kind := "game"
	var size := 540
	var bench := 0
	var secs := 6.0
	var dash_move := "pin_roll"
	var lmb_move := "arc_loose"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--warden="):
			id = a.substr(9)
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--scene="):
			scene = a.substr(8)
		if a.begins_with("--cam="):
			cam_kind = a.substr(6)
		if a.begins_with("--fps="):
			fps = float(a.substr(6))
		if a.begins_with("--size="):
			size = int(a.substr(7))
		if a == "--bench":
			bench = 8
		if a.begins_with("--bench="):
			bench = int(a.substr(8))
		if a.begins_with("--secs="):
			secs = float(a.substr(7))
		if a.begins_with("--dash="):
			dash_move = a.substr(7)
		if a.begins_with("--lmb="):
			lmb_move = a.substr(6)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	shots.frame_px = size
	shots.tree = tree
	shots._stage(main)
	if bench > 0:
		main.get_window().size = Vector2i(size, size)
		main.get_viewport().size = main.get_window().size
		await _bench(id, bench, secs)
		tree.quit()
		return
	for sc in scene.split(",", false):
		for ck in cam_kind.split(",", false):
			var wide := Vector2i(size * 16 / 9, size) if ck == "game" else Vector2i(size, size)
			main.get_window().size = wide
			main.get_viewport().size = wide
			await _one(id, sc, ck, out.path_join("%s_%s" % [sc, ck]), dash_move, lmb_move)
	print("CLOTH_SHOTS_DONE ", out)
	tree.quit()

func _one(id: String, scene: String, cam_kind: String, dir: String, dash_move: String, lmb_move: String) -> void:
	var model := _spawn(id)
	shots.holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 30:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	DirAccess.make_dir_recursive_absolute(dir)
	var state := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
	model.set_meta(WardenClips.STATE, state)
	var length := {"idle": 3.0, "run": 3.0, "dash": 3.4, "lmb": 3.0}[scene] as float
	for k in 45:      # (settle: the cloth hangs, the clips fade in)
		sync.call("_process", 1.0 / fps)
	var data := WardenClips.data(WardenGlb.art(id))
	var n := int(length * fps)
	var clips: WardenClips = sync.get("clips")
	for i in n:
		var t := float(i) / fps
		var speed := 0.0
		state.erase("kmove")
		match scene:
			"run":
				speed = RUN if t >= 0.5 else 0.0
			"dash":
				speed = RUN if t >= 0.3 else 0.0
				var dl := clips.lib.get_animation(String(data["kmoves"][dash_move]["clip"])).length
				if t >= 1.4 and t < 1.4 + dl:
					state["kmove"] = dash_move
					state["kmove_t"] = t - 1.4
					speed = DASH
			"lmb":
				speed = RUN if t >= 0.3 else 0.0
				var ll := clips.lib.get_animation(String(data["kmoves"][lmb_move]["clip"])).length
				if t >= 1.2 and t < 1.2 + ll:
					state["kmove"] = lmb_move
					state["kmove_t"] = t - 1.2
		state["vel"] = Vector3(0, 0, -speed)
		model.position.z -= speed / fps
		sync.call("_process", 1.0 / fps)
		_camera(model, cam_kind, t / length)
		await shots._grab(dir.path_join("f%03d.png" % i))
	model.queue_free()

func _spawn(id: String) -> Node3D:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	return model

func _camera(model: Node3D, kind: String, u: float) -> void:
	var c := shots.cam
	var at := model.position + Vector3(0, 0.8, 0)
	match kind:
		"game":      # (the game's camera: 23 m out at 66 degrees, fov 32, following)
			c.fov = 32.0
			c.position = model.position + Vector3(0, 23.0 * sin(deg_to_rad(66.0)), 23.0 * cos(deg_to_rad(66.0)))
		"side":
			c.fov = 30.0
			c.position = at + Vector3(2.6, 0.1, 0)
		"back":
			c.fov = 30.0
			c.position = at + Vector3(0, 0.1, 2.6)
		_:      # orbit: once round her over the clip, 2.4 m out, a little above
			c.fov = 30.0
			var a := TAU * u + PI * 0.5
			c.position = at + Vector3(cos(a) * 2.4, 0.35, sin(a) * 2.4)
	c.look_at(at if kind != "game" else model.position + Vector3(0, 0.8, 0))

## --bench: n hunters running in a ring for secs, each moved on its own Sync: prints the mean frame ms and the
## engine's mean process ms (the Sync steps and the cloth modifiers are inside it).
func _bench(id: String, n: int, secs: float) -> void:
	var models: Array = []
	for i in n:
		var m := _spawn(id)
		shots.holder.add_child(m)
		m.position = Vector3(cos(TAU * i / n) * 3.0, 0, sin(TAU * i / n) * 3.0)
		var ring := m.get_node_or_null("TeamRing") as Node3D
		if ring:
			ring.visible = false
		m.set_meta(WardenClips.STATE, {"vel": Vector3(0, 0, -RUN), "face": 0.0, "grounded": true})
		models.append(m)
	shots.cam.fov = 40.0
	shots.cam.position = Vector3(0, 5.0, 7.0)
	shots.cam.look_at(Vector3(0, 0.8, 0))
	for k in 60:
		await tree.process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var t0 := Time.get_ticks_usec()
	var frames := 0
	var proc := 0.0
	while float(Time.get_ticks_usec() - t0) / 1e6 < secs:
		await tree.process_frame
		frames += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		for m in models:      # (they run in place: the circle's heading changes, the speed stays)
			(m as Node3D).rotation.y += 0.02
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("CLOTH_BENCH n=%d frames=%d frame_ms=%.3f process_ms=%.3f" % [n, frames, ms, proc * 1000.0 / frames])
