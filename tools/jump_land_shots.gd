extends "res://tools/clip_shots.gd"
## --jump-land-shots --shots-dir=<dir> [--wardens=a,b] [--size=720] [--no-heavy-land]
## [--way=jump|drop|long|plunge|glide|kerb]: each Hunter's
## plain jump (or the other ways down) at the match camera (23 m out at 66 degrees, fov 32, the Hunter kept centred as
## the game's camera does): the run-up, take-off, apex, fall, the landing and the recovery, every 1/30 s,
## <dir>/<id>/<run|still>/f000.png... (<way>_run, <way>_still for the other ways) plus key.json with the take-off,
## apex and landing frames. tools/jump_land_strip.py makes the strips. The arc is the game's (Hunter.JUMP_V, H_GRAV,
## run speed) fed straight to the hand-keyed clips, so what shows is the clip data alone. Needs a renderer.

const DT := 1.0 / 30.0
const RUN_UP := 0.6  # s of running before the press
const TAIL := 0.8  # s on the ground after the landing
const DROP_H := 3.0  # m: the terrace drop (lands at 9.4 m/s: HunterAnim's deep tier)
const LONG_H := 6.0  # m: a long drop (lands at 13.3 m/s: HunterAnim's heavy landing starts)
const PLUNGE_H := 12.0  # m: a plunge (18.8 m/s: the dive's speed)
const KERB_H := 0.3  # m: a step down (3 m/s: no landing to play)
const GLIDE_T := 0.6  # s of gliding at the canopy's sink before the ground

var heavy := true  # --no-heavy-land: the plain terrace-drop crouch at every height (the "before")


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	var way := "jump"
	heavy = not OS.get_cmdline_user_args().has("--no-heavy-land")
	frame_px = 720
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--way="):
			way = a.substr(6)
		if a.begins_with("--wardens="):
			ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
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
		await _hunter(String(id), out.path_join(String(id)), way)
	print("JUMP_LAND_SHOTS_DONE")
	tree.quit()


## m a way down falls: the terrace drop, the long drop, the plunge, else the kerb.
static func fall_h(way: String) -> float:
	return {"drop": DROP_H, "long": LONG_H, "plunge": PLUNGE_H}.get(way, KERB_H)


## s in the air for a way down: the plain jump, the terrace drop, the kerb (both a free fall) or the glide's end.
static func air_time(way: String) -> float:
	match way:
		"drop", "long", "plunge":
			return sqrt(2.0 * fall_h(way) / Hunter.H_GRAV)
		"kerb":
			return sqrt(2.0 * KERB_H / Hunter.H_GRAV)
		"glide":
			return GLIDE_T
	return 2.0 * Hunter.JUMP_V / Hunter.H_GRAV


## The state t s after the press (or the step off, or GLIDE_T before a glide's touchdown): {grounded, gliding, y, vel}.
## Running: the run speed forward (the camera follows, so the model stays put and only rises). Shared with
## --clip-check's landing timing.
static func arc(t: float, running: bool, way: String) -> Dictionary:
	var air := air_time(way)
	var up := t >= 0.0 and t < air
	var vy := 0.0
	var y := 0.0
	if up:
		match way:
			"jump":
				vy = Hunter.JUMP_V - Hunter.H_GRAV * t
				y = Hunter.JUMP_V * t - 0.5 * Hunter.H_GRAV * t * t
			"glide":
				vy = -HunterMove.glide_sink
				y = HunterMove.glide_sink * (air - t)
			_:
				vy = -Hunter.H_GRAV * t
				y = fall_h(way) - 0.5 * Hunter.H_GRAV * t * t
	var fwd := float(HunterMove.of("default")["speed"]) if running else 0.0
	return {
		"grounded": not up,
		"gliding": up and way == "glide",
		"y": maxf(y, 0.0),
		"vel": Vector3(0, vy, -fwd),
		"face": 0.0,
		"fired": 99.0
	}


func _hunter(id: String, dir: String, way: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	if not heavy:
		sync.heavy_land = null
	var air := air_time(way)
	for variant: String in ["run", "still"]:
		var sub := dir.path_join(variant if way == "jump" else way + "_" + variant)
		DirAccess.make_dir_recursive_absolute(sub)
		var running := variant == "run"
		var i := 0
		var t := -RUN_UP
		while t < air + TAIL:
			var s := arc(t, running, way)
			model.position.y = float(s["y"])
			model.set_meta(WardenClips.STATE, s)
			sync.call("_process", DT)
			await _grab(sub.path_join("f%03d.png" % i))
			i += 1
			t += DT
		var key := {
			"takeoff": int(round(RUN_UP / DT)),
			"apex": int(round((RUN_UP + air * 0.5) / DT)),
			"land": int(round((RUN_UP + air) / DT)),
			"fps": 30
		}
		var f := FileAccess.open(sub.path_join("key.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(key))
		f.close()
		print("JL %s %s takeoff=%d apex=%d land=%d" % [id, variant, key["takeoff"], key["apex"], key["land"]])
	model.queue_free()
	await tree.process_frame
