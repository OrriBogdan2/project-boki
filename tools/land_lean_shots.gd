extends "res://tools/clip_shots.gd"
## --land-lean-shots --shots-dir=<dir> [--wardens=a,b] [--boki=a,b]: side-on frames (1/30 s) of each Hunter and a few
## rigged Boki standing, starting a run, stopping, jumping and landing, then coming off a glide (Hunters) or a leap
## (Boki): <dir>/<id>/f000.png... and key.json with the event frames. HunterAnim runs as in a match (its state fed
## to the clips), the Boki's own BokiRig and AnimationPlayer are stepped by hand, so a run on two trees compares
## frame for frame. tools/land_lean_strip.py lays two runs side by side. Needs a renderer.

const DT := 1.0 / 30.0
const STAND := 0.3          # s still before each move
const RUN := 0.6            # s of running before the stop
const TAIL := 0.6           # s on the ground after the stop or a landing
const STOP_T := 0.17        # s a let-go from a run takes to stop (HunterMove "brake" note)
const GLIDE_T := 0.5        # s of gliding at the canopy's sink before the ground
const LEAP_H := 1.6         # m: a Boki's grammar leap (Kin.start_leap's default height and time)
const LEAP_T := 0.45
const BOKI_RUN := 5.0       # m/s: a Boki keeping up with its Hunter

var key := {}

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	var boki: Array = ["cindle", "puddlet", "pebbit"]
	frame_px = 480
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--boki="): boki = Array(a.substr(7).split(",", false))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	for id in ids:
		if not WardenClips.data(WardenGlb.art(String(id))).is_empty():
			await _hunter(String(id), out.path_join(String(id)))
	for id in boki:
		await _boki(String(id), out.path_join("boki_" + String(id)))
	print("LAND_LEAN_SHOTS_DONE")
	tree.quit()

func _side(at_y: float, dist: float) -> void:
	cam.fov = 30.0
	cam.position = Vector3(dist, at_y + dist * 0.12, 0.0)
	cam.look_at(Vector3(0, at_y, 0))

## Ground speed t s into the routine (a run at `accel`, a let-go over STOP_T), the events noted in `key` as they pass.
## The jump starts at the time it returns as "jump".
func _plan(t: float, spd: float, accel: float, air: float) -> Dictionary:
	var marks := [["start", STAND], ["stop", STAND + RUN], ["jump", STAND * 2.0 + RUN + TAIL],
		["land", STAND * 2.0 + RUN + TAIL + air]]
	for m in marks:
		if not key.has(m[0]) and t >= float(m[1]) - 0.001:
			key[m[0]] = int(round(t / DT))
	var v := 0.0
	if t >= STAND and t < STAND + RUN:
		v = minf(spd, accel * (t - STAND))
	elif t >= STAND + RUN:
		v = maxf(0.0, spd * (1.0 - (t - STAND - RUN) / STOP_T))
	return {"v": v, "jump": float(marks[2][1])}

func _hunter(id: String, dir: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	_side(0.85, 6.5)
	for k in 20:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var anim := HunterAnim.new(model)
	var mv := HunterMove.of(id)
	var spd := float(mv["speed"])
	var air := 2.0 * Hunter.JUMP_V / Hunter.H_GRAV
	DirAccess.make_dir_recursive_absolute(dir)
	key = {}
	var i := 0
	var t := 0.0
	var end := STAND * 2.0 + RUN + TAIL * 2.0 + air + GLIDE_T + STAND
	while t < end:
		var p := _plan(t, spd, float(mv["accel"]), air)
		var t0 := float(p["jump"])
		var s := {"vel": Vector3(0, 0, -p["v"]), "face": 0.0, "grounded": true, "fired": 99.0, "air_h": 0.0}
		var u := t - t0
		if u >= 0.0 and u < air:
			s["vel"] = Vector3(0, Hunter.JUMP_V - Hunter.H_GRAV * u, 0)
			s["air_h"] = Hunter.JUMP_V * u - 0.5 * Hunter.H_GRAV * u * u
			s["grounded"] = false
		var g0 := t0 + air + TAIL
		if t >= g0 and t < g0 + GLIDE_T:
			key["glide_land"] = int(round((g0 + GLIDE_T) / DT))
			s["vel"] = Vector3(0, -Hunter.GLIDE_SINK, -spd)
			s["air_h"] = Hunter.GLIDE_SINK * (g0 + GLIDE_T - t)
			s["grounded"] = false
			s["gliding"] = true
		model.position.y = float(s["air_h"])
		anim.update(DT, s)
		sync.call("_process", DT)
		await _grab(dir.path_join("f%03d.png" % i))
		i += 1
		t += DT
	_key(dir)
	model.queue_free()
	await tree.process_frame

func _boki(id: String, dir: String) -> void:
	var k: Node3D = load("res://tools/boki_rig_shots.gd").rigged_kin(id)
	holder.add_child(k)
	_side(0.3, 3.2)
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.set_process(false)
	for n in k.find_children("*", "", true, false):
		if n is KinPuppet:
			n.set_process(false)
	rig.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var start := k.global_position
	DirAccess.make_dir_recursive_absolute(dir)
	key = {}
	var i := 0
	var t := 0.0
	var x := 0.0
	while t < STAND * 2.0 + RUN + TAIL * 2.0 + LEAP_T:
		var p := _plan(t, BOKI_RUN, BOKI_RUN / 0.25, LEAP_T)
		var u := (t - float(p["jump"])) / LEAP_T
		var y := 4.0 * LEAP_H * u * (1.0 - u) if u > 0.0 and u < 1.0 else 0.0
		x -= float(p["v"]) * DT
		k.global_position = start + Vector3(0, y, x)
		cam.position.z = x          # the camera keeps on it
		rig._process(DT)
		rig.player.advance(DT)
		await _grab(dir.path_join("f%03d.png" % i))
		i += 1
		t += DT
	_key(dir)
	k.queue_free()
	await tree.process_frame

func _key(dir: String) -> void:
	key["fps"] = 30
	var f := FileAccess.open(dir.path_join("key.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(key))
	f.close()
	print("LL %s %s" % [dir.get_file(), JSON.stringify(key)])
