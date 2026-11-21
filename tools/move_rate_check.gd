extends "res://tools/move_feel_check.gd"
## --move-rate-check (docs/MOVEMENT_PARITY.md, docs/decisions/0048): the Hunter moves the same whatever the
## display's frame rate, in a match and on the farm. Each trial runs drawn frames of 1/30, 1/60 and 1/144 s
## through the real frame loops (Match._process, the farm's FarmStep.run) with real key presses, and measures:
## run speed and the distance of a 1 s run, the stop (and the stop from each Hunter's run speed, inside the
## source's band: UE's walking brake drawn at 30 to 144 fps), the jump's apex and air time, a dash (press to its
## end, run speed held), and the two jump
## graces (coyote: the latest press after the ground goes that still jumps; buffer: the earliest press before
## a landing that still jumps). Every number has to agree with its 60 fps value, and the graces with their
## data rows (content/rules/hunter_move.json).
## Prints "MRATE <match|farm> <key> 30=.. 60=.. 144=.. ok|FAIL" and "MOVE RATE CHECK DONE, failures: N".

const RATES := [30, 60, 144]
const GRACE_STEPS := 12  # press delays tried for each jump grace, one sim step apart (to 0.2 s)
const DROP_M := 1.0  # m: the buffer trial's fall (every press in its last 0.2 s counts as "about to land")
const LIFT_M := 3.0  # m: how far the coyote trial's ground drops away
## key: [allowed difference from the 60 fps value, unit]. A drawn frame holds 2 steps at 30 fps, so whatever
## is read "after N seconds of frames" may be a step or two of running apart; the arcs themselves are exact.
const TOL := {
	"run_speed": [0.01, "m/s"],
	"run_1s": [0.2, "m"],
	"stop": [0.01, "m"],
	"jump_apex": [0.005, "m"],
	"jump_air": [0.05, "s"],
	"dash": [0.2, "m"],
	"dash_time": [0.05, "s"],
	"coyote": [0.05, "s"],
	"buffer": [0.05, "s"],
}

var tree: SceneTree
var hm = null  # the farm (Home), once the match trials are done
var farm_at := Vector3.ZERO  # the start of the farm's clear lane
var got := {}  # key -> {fps: value}


## One drawn frame of `delta` seconds.
func _frame(delta: float) -> void:
	if hm:
		hm.mover.run(delta, hm.player, hm._move_player)
	else:
		m._process(delta)
	await tree.process_frame


func _frames(secs: float, delta: float) -> void:
	for i in int(round(secs / delta)):
		await _frame(delta)


## A key pressed for one drawn frame.
func _tap(action: String, delta: float) -> void:
	Input.action_press(action)
	await _frame(delta)
	Input.action_release(action)


func _at() -> Vector3:
	return Vector3(hm.ppos.x, hm.py, hm.ppos.z) if hm else P.pos


func _vy() -> float:
	return hm.pvy if hm else P.vel.y


func _speed() -> float:
	return Vector2(hm.pvel.x, hm.pvel.z).length() if hm else _hv(P).length()


func _floor_y() -> float:
	return hm._ground_h(hm.ppos.x, hm.ppos.z) if hm else P.ground()


func _dashing() -> bool:
	return hm.dash_t > 0.0 if hm else P.roll_t > 0.0


func _in_air() -> bool:
	return _at().y > _floor_y() + 0.001 or _vy() > 0.0


## Standing still at the trial's start, with a full dash.
func _stand() -> void:
	Input.action_release("right")
	if not hm:
		_reset(flat + Vector3(-3.0, 0, 0))
		m.acc = 0.0
		return
	hm.ppos = farm_at
	hm.py = hm._ground_h(farm_at.x, farm_at.z)
	hm.pvy = 0.0
	hm.pvel = Vector3.ZERO
	hm.gliding = false
	hm.dash_t = 0.0
	hm.dash.charges = float(hm._dodge()["charges"])
	hm.lfl = {}
	hm.mover = FarmStep.new()


## The ground gone from under the feet: `up` metres of air, no speed.
func _lift(up: float) -> void:
	if hm:
		hm.py += up
	else:
		P.pos.y += up


func _run_stop(fps: int) -> void:
	var delta := 1.0 / fps
	_stand()
	await _frames(0.1, delta)
	var x0 := _at().x
	Input.action_press("right")
	await _frames(1.0, delta)
	_put("run_speed", fps, _speed())
	_put("run_1s", fps, _at().x - x0)
	Input.action_release("right")
	var x1 := _at().x
	await _frames(0.5, delta)
	_put("stop", fps, _at().x - x1)


## Each Hunter's run speed let go after half a second: the slide, read as "stop_<speed>".
func _hunter_stops(fps: int) -> void:
	var delta := 1.0 / fps
	var arch_was = Save.d.get("arch", "")
	var speeds := run_speeds()
	for v in speeds:
		_stand()
		if hm:
			Save.d["arch"] = speeds[v][0]
		else:
			P.base_speed = v
		Input.action_press("right")
		await _frames(0.5, delta)
		Input.action_release("right")
		var x1 := _at().x
		await _frames(0.5, delta)
		_put("stop_%.2f" % v, fps, _at().x - x1)
	if hm:
		Save.d["arch"] = arch_was
	else:
		HunterMove.apply(P)


func _jump_arc(fps: int) -> void:
	var delta := 1.0 / fps
	_stand()
	await _frames(0.1, delta)
	var y0 := _at().y
	var apex := 0.0
	var air := 0.0
	await _tap("jump", delta)
	for i in int(round(1.5 / delta)):
		apex = maxf(apex, _at().y - y0)
		if _in_air():
			air += delta
		await _frame(delta)
	_put("jump_apex", fps, apex)
	_put("jump_air", fps, air)


func _dash(fps: int) -> void:
	var delta := 1.0 / fps
	_stand()
	await _frames(0.1, delta)
	Input.action_press("right")
	await _frames(0.5, delta)
	var x0 := _at().x
	var secs := 0.0
	await _tap("dash", delta)
	while secs < 1.5 and (secs < 0.1 or _dashing()):
		await _frame(delta)
		secs += delta
	_put("dash", fps, _at().x - x0)
	_put("dash_time", fps, secs)
	Input.action_release("right")


## Whether a jump pressed `wait` frames after the ground goes still jumps.
func _coyote_jumps(wait: int, delta: float) -> bool:
	_stand()
	await _frames(0.1, delta)
	_lift(LIFT_M)
	for i in wait:
		await _frame(delta)
	await _tap("jump", delta)
	await _frame(delta)
	return _vy() > 1.0


## Whether a jump pressed `lead` frames before the landing (`fall` frames into the drop) jumps as you land.
func _buffer_jumps(lead: int, fall: int, delta: float) -> bool:
	_stand()
	await _frames(0.1, delta)
	_lift(DROP_M)
	for i in fall - lead:
		await _frame(delta)
	await _tap("jump", delta)
	var rose := false
	for i in lead + int(round(0.2 / delta)):
		await _frame(delta)
		rose = rose or _vy() > 1.0
	return rose


## Frames a DROP_M fall takes to land.
func _fall_frames(delta: float) -> int:
	_stand()
	await _frames(0.1, delta)
	_lift(DROP_M)
	var n := 0
	while n < 400:
		await _frame(delta)
		n += 1
		if not _in_air():
			break
	return n


func _graces(fps: int) -> void:
	var delta := 1.0 / fps
	var fall: int = await _fall_frames(delta)
	var coyote := 0.0
	var buffer := 0.0
	var tried := {}
	for k in range(1, GRACE_STEPS + 1):
		var n := maxi(1, int(round(k * DT / delta)))
		if tried.has(n):
			continue
		tried[n] = true
		if await _coyote_jumps(n, delta):
			coyote = maxf(coyote, n * delta)
		if await _buffer_jumps(n, fall, delta):
			buffer = maxf(buffer, n * delta)
	_put("coyote", fps, coyote)
	_put("buffer", fps, buffer)


func _put(key: String, fps: int, v: float) -> void:
	if not got.has(key):
		got[key] = {}
	got[key][fps] = v


func _ok(cond: bool, what: String) -> void:
	print("MRATE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _trials(where: String) -> void:
	got = {}
	for fps in RATES:
		await _run_stop(fps)
		await _hunter_stops(fps)
		await _jump_arc(fps)
		await _dash(fps)
		await _graces(fps)
	for key in TOL:
		var v: Dictionary = got[key]
		var tol: float = TOL[key][0]
		var same := absf(v[30] - v[60]) <= tol and absf(v[144] - v[60]) <= tol
		var line := "%s %s 30=%.3f 60=%.3f 144=%.3f %s" % [where, key, v[30], v[60], v[144], TOL[key][1]]
		_ok(same, "%s (within %s of 60 fps)" % [line, tol])
	_ok(
		float(got["run_speed"][60]) > 4.0 and float(got["jump_apex"][60]) > 1.0 and float(got["dash"][60]) > 2.5,
		"%s: the trials ran, jumped and dashed" % where
	)
	var speeds := run_speeds()
	for v in speeds:
		var band := ue_band(v)
		var got_v: Dictionary = got["stop_%.2f" % v]
		var inside := got_v.values().all(func(x: float) -> bool: return x >= band.x and x <= band.y)
		var line := "%s stop from %.2f m/s 30=%.3f 60=%.3f 144=%.3f m in the source's %.3f-%.3f (%s)"
		_ok(inside, line % [where, v, got_v[30], got_v[60], got_v[144], band.x, band.y, ", ".join(speeds[v])])
	for g in [["coyote", HunterMove.coyote_s], ["buffer", HunterMove.jump_buffer_s]]:
		var v60: float = got[g[0]][60]
		var what := "%s %s at 60 fps %.3f s is its data row %.2f s" % [where, g[0], v60, g[1]]
		_ok(absf(v60 - float(g[1])) <= 2.0 * DT, what)


## A straight, level, open lane on the farm: the avatar can run `length` metres toward +x from it.
func _farm_lane(length: float) -> Vector3:
	for ring in range(0, 30):
		for i in 12:
			var a := TAU * i / 12.0
			var c: Vector3 = hm.ppos + Vector3(cos(a), 0, sin(a)) * float(ring)
			var y0: float = hm._ground_h(c.x, c.z)
			var clear := y0 > World.VOID + 1.0
			for s in int(length / 0.25) + 1:
				var x := c.x - 1.0 + s * 0.25
				clear = clear and absf(hm._ground_h(x, c.z) - y0) < 0.01 and hm.water.depth(x, c.z) == 0
				clear = clear and hm.world.occupy(x, c.z, 0.6, y0, true) == 0.0
			if clear:
				return Vector3(c.x, 0, c.z)
	return hm.ppos


func _open_farm(main: Node) -> void:
	var pk := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(pk)
	Save.d["active"] = pk["uid"]
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	Econ.ensure()
	hm = load("res://scripts/home/home.gd").new()
	main.add_child(hm)
	await tree.process_frame
	while hm.building:  # with a display the farm builds under the ink wipe, over several frames
		await tree.process_frame
	await tree.process_frame
	hm.set_process(false)
	farm_at = _farm_lane(12.0)


func run(main: Node) -> void:
	tree = main.get_tree()
	RenderingServer.render_loop_enabled = false  # thousands of frames, none looked at (a soft renderer is slow)
	_begin(main)
	m.paused = false
	await _trials("match")
	m.queue_free()
	await _open_farm(main)
	await _trials("farm")
	print("MOVE RATE CHECK DONE, failures: ", bad)
	tree.quit()
