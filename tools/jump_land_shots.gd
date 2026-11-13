extends "res://tools/clip_shots.gd"
## --jump-land-shots --shots-dir=<dir> [--wardens=a,b] [--size=720]: every Hunter's plain jump at the match camera
## (23 m out at 66 degrees, fov 32, the Hunter kept centred as the game's camera does): the run-up, take-off, apex,
## fall, the landing and the recovery, every 1/30 s, <dir>/<id>/<run|still>/f000.png... plus key.json with the
## take-off, apex and landing frames. tools/jump_land_strip.py makes the strips. The arc is the game's (Hunter.JUMP_V,
## H_GRAV, run speed) fed straight to the hand-keyed clips, so what shows is the clip data alone. Needs a renderer.

const DT := 1.0 / 30.0
const RUN_UP := 0.6          # s of running before the press
const TAIL := 0.8            # s on the ground after the landing

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	frame_px = 720
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 32.0
	cam.position = Vector3(0, 23.0 * sin(deg_to_rad(66.0)), 23.0 * cos(deg_to_rad(66.0)))
	cam.look_at(Vector3(0, 0.8, 0))
	for id in ids:
		if WardenClips.data(WardenGlb.art(String(id))).is_empty():
			continue
		await _hunter(String(id), out.path_join(String(id)))
	print("JUMP_LAND_SHOTS_DONE")
	tree.quit()

## The plain jump's state at t s after the press: {grounded, y, vel}. Running: the run speed forward (the camera
## follows, so the model stays put and only rises). Shared with --clip-check's jump/land timing.
static func arc(t: float, running: bool) -> Dictionary:
	var air := 2.0 * Hunter.JUMP_V / Hunter.H_GRAV
	var up := t >= 0.0 and t < air
	var vy := Hunter.JUMP_V - Hunter.H_GRAV * t if up else 0.0
	var y := maxf(Hunter.JUMP_V * t - 0.5 * Hunter.H_GRAV * t * t, 0.0) if up else 0.0
	var fwd := float(HunterMove.of("default")["speed"]) if running else 0.0
	return {"grounded": not up, "y": y, "vel": Vector3(0, vy, -fwd), "face": 0.0, "fired": 99.0}

func _hunter(id: String, dir: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var air := 2.0 * Hunter.JUMP_V / Hunter.H_GRAV
	for variant: String in ["run", "still"]:
		var sub := dir.path_join(variant)
		DirAccess.make_dir_recursive_absolute(sub)
		var running := variant == "run"
		var i := 0
		var t := -RUN_UP
		while t < air + TAIL:
			var s := arc(t, running)
			model.position.y = float(s["y"])
			model.set_meta(WardenClips.STATE, s)
			sync.call("_process", DT)
			await _grab(sub.path_join("f%03d.png" % i))
			i += 1
			t += DT
		var key := {"takeoff": int(round(RUN_UP / DT)), "apex": int(round((RUN_UP + air * 0.5) / DT)),
			"land": int(round((RUN_UP + air) / DT)), "fps": 30}
		var f := FileAccess.open(sub.path_join("key.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(key))
		f.close()
		print("JL %s %s takeoff=%d apex=%d land=%d" % [id, variant, key["takeoff"], key["apex"], key["land"]])
	model.queue_free()
	await tree.process_frame
