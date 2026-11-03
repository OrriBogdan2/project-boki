extends "res://tools/pin_bjorn_owner_check.gd"
## Owner items #48 and #49 for Bjorn (briefs/OWNER_REVIEW_1103.md), run from --bulwark-combo-check
## (tools/archer_bulwark_combo_check.gd adds the counts): the Faultline plants him only for the wind-up and
## the slam, and the held swing's perfect window launches him, into a glide off a ledge. Prints AKCHECK lines.

const FAR := Vector3(30.0, 0, 6.0)      # the dummy parked out of the way
## s after the plant ends from which he must be at 90% of his run speed: a frame for the plant to lift, then
## the shared ground acceleration (Hunter.GROUND_ACCEL, ~0.055 s from a stand)
const FULL_STRIDE := 0.12

func bjorn() -> void:
	await _ult_walk()
	await _window()
	await _launch_flat()
	await _launch_glide()

func _planar(P: Hunter) -> float:
	return Vector2(P.vel.x, P.vel.z).length()

## Clears the swing state and stands him at `home`, the dummy parked.
func _ready_swing(m: Match, P: Hunter, T: Hunter, home: Vector3) -> void:
	var K: BulwarkKit = P.ak
	P.inp["fire"] = false
	P.inp["glide"] = false
	step(m, 1.0)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.fire_cd = 0.0
	P.dashes = P.max_dashes()
	P.glide_cd = 0.0
	K.lmb_t = -1.0
	K.hold_blocked = false
	T.teleport(home + FAR)
	fresh(T)

## Holds the swing aimed east for `secs` (from the press), lets go, and returns how far east he went in the
## next `after` s.
func _swing(m: Match, P: Hunter, home: Vector3, secs: float, after := 0.9) -> float:
	var x0 := P.pos.x
	step(m, secs, press_at.bind(P, home + Vector3(9.0, 0, 0)))
	P.inp["fire"] = false
	step(m, after)
	return P.pos.x - x0

## #48: planted (speed 0) for the 0.4 s wind-up and the slam's 0.2 s; from 0.1 s after that he walks at
## least 90% of his run speed while the lane is still erupting, and the lane erupts where it was cast.
func _ult_walk() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var xd: Dictionary = K.d["x"]
	step(m, 0.3)
	# his run speed: walking south, settled
	step(m, 0.8, func(): P.inp["move"] = Vector2(0, 1))
	var run := _planar(P)
	P.inp["move"] = Vector2.ZERO
	step(m, 0.5)
	P.teleport(home)
	P.vel = Vector3.ZERO
	T.teleport(home + Vector3(13.0, 0, 0))
	fresh(T)
	K.cd["x"] = 0.0
	aim_at(P, T.pos)
	press_x(m, P)
	var origin := K.ult.origin
	var plant_t := float(xd["windup"]) + float(xd["plant"])
	var t := DT
	var moved_planted := 0.0
	var slow_free := 99.0
	var free_samples := 0
	var off_mark := 0.0
	var walking := func():
		P.inp["move"] = Vector2(0, 1)          # walking away north-south, across the lane
		aim_at(P, T.pos)
	while K.ult.phase != "" and t < 3.0:
		walking.call()
		m.step(DT)
		t += DT
		if t < plant_t - 0.001:
			moved_planted = maxf(moved_planted, _planar(P))
		elif absf(t - plant_t - 0.05) < DT * 0.5:
			off_mark = _planar(P)
		elif t >= plant_t + FULL_STRIDE and K.ult.phase == "erupt":
			slow_free = minf(slow_free, _planar(P))
			free_samples += 1
	P.inp["move"] = Vector2.ZERO
	ok("bjorn #48 ult: planted for the wind-up and the slam (planar speed 0 for %.1f s)" % plant_t,
		moved_planted < 0.01, "speed %.2f" % moved_planted)
	ok("bjorn #48 ult: free the moment the plant ends (already moving 0.05 s after it)", off_mark > 0.5,
		"%.2f of %.2f" % [off_mark, run])
	ok("bjorn #48 ult: from ~0.1 s after the slam he walks at 90%+ of his run speed while it erupts",
		free_samples >= 10 and slow_free >= run * 0.9,
		"slowest %.2f of run %.2f over %d steps" % [slow_free, run, free_samples])
	ok("bjorn #48 ult: the lane erupts where it was cast, wherever he walks (the far dummy is thrown)",
		K.ult.origin == origin and dmg(T) > 0.0 and P.flat_dist(T) > 3.0 and absf(P.pos.z - home.z) > 2.0,
		"took %.0f, he is %.1f m off the lane" % [dmg(T), absf(P.pos.z - home.z)])
	await done(m)

## #49: the window opens at full charge with the flash (ring-free) and the click, and shuts "window" s later.
func _window() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var md := K.lmb_def()
	var full := float(md["full"])
	var win := float(md["perfect"]["window"])
	_ready_swing(m, P, T, home)
	var opened := -1.0
	var shut := -1.0
	var flash_ringless := false
	var hot := false
	var held := 0.0
	while held < full + 0.38:
		press_at(P, home + Vector3(9.0, 0, 0))
		m.step(DT)
		held += DT
		var now := K.launch.in_window(K.lmb_t)
		if now and opened < 0.0:
			opened = K.lmb_t
			var ring = K.fx.flare.material_override.get_shader_parameter("ring")      # unset: the shader's 0
			flash_ringless = K.fx.flare_t > 0.0 and (ring == null or float(ring) == 0.0)
			hot = K.fx.hot
		if not now and opened >= 0.0 and shut < 0.0:
			shut = K.lmb_t
	ok("bjorn #49 window: it opens at full charge (%.2f s) with the ring-free flash and the hot glint" % full,
		absf(opened - full) < 0.03 and K.flared and flash_ringless and hot,
		"opens at %.2f flash %s hot %s" % [opened, flash_ringless, hot])
	ok("bjorn #49 window: it shuts %.2f s after full" % win, absf(shut - (full + win)) < 0.03,
		"shuts at %.2f (want %.2f)" % [shut, full + win])
	P.inp["fire"] = false
	step(m, 0.5)
	ok("bjorn #49 window: held past it, the swing goes off on its own as a normal one",
		K.lmb_t < 0.0 and K.launch.launches == 0 and K.slams == 1,
		"launches %d slams %d" % [K.launch.launches, K.slams])
	await done(m)

## #49 on flat ground: in the window he launches >= 3.5 m (feet up, bul_launch) with a bigger knock, a heavier
## hit-stop and shake; outside it (early or late) the step stays <= 2 m; it counts as a dash for DashFlow; a
## mantle ends it; glide pressed in it jumps him out into a glide that keeps the launch's speed.
func _launch_flat() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var full := float(K.lmb_def()["full"])
	var in_win := full + 0.08
	_ready_swing(m, P, T, home)
	var late := _swing(m, P, home, full + 0.3)
	_ready_swing(m, P, T, home)
	var early := _swing(m, P, home, 0.7)
	ok("bjorn #49: a release outside the window steps him 1.5-2 m (item 30's step)",
		late >= 1.5 and late <= 2.0 and early >= 1.4 and early <= 2.0 and K.launch.launches == 0,
		"late %.2f early %.2f" % [late, early])
	# the knock and the hit-stop: normal (late) first, then perfect, on a dummy 2.6 m ahead
	var knocks: Array = []
	var stops: Array = []
	for secs in [full + 0.3, in_win]:
		_ready_swing(m, P, T, home)
		T.teleport(home + Vector3(2.6, 0, 0))
		var t0 := T.pos.x
		step(m, secs, press_at.bind(P, home + Vector3(9.0, 0, 0)))
		P.inp["fire"] = false
		var stop := 0.0
		for i in 12:
			m.step(DT)
			stop = maxf(stop, T.freeze_t)
		step(m, 0.8)
		knocks.append(T.pos.x - t0)
		stops.append(stop)
	ok("bjorn #49: the perfect swing knocks harder and holds the hit longer",
		float(knocks[1]) > float(knocks[0]) + 0.5 and float(stops[1]) > float(stops[0]),
		"knock %.2f -> %.2f, hit-stop %.3f -> %.3f" % [knocks[0], knocks[1], stops[0], stops[1]])
	_ready_swing(m, P, T, home)
	var l0 := K.launch.launches
	var x0 := P.pos.x
	step(m, in_win, press_at.bind(P, home + Vector3(9.0, 0, 0)))
	P.inp["fire"] = false
	m.step(DT)
	m.step(DT)
	var anim_ok := K.anim_id == "bul_launch"
	var dashing := K.in_dash()
	step(m, 0.9)
	ok("bjorn #49: a release in the window launches him >= 3.5 m (bul_launch, a dash to DashFlow)",
		K.launch.launches == l0 + 1 and P.pos.x - x0 >= 3.5 and anim_ok and dashing,
		"moved %.2f anim %s dash %s" % [P.pos.x - x0, anim_ok, dashing])
	# a mantle mid-launch ends it at once
	_ready_swing(m, P, T, home)
	step(m, in_win, press_at.bind(P, home + Vector3(9.0, 0, 0)))
	P.inp["fire"] = false
	m.step(DT)
	m.step(DT)
	var live := P.roll_t > 0.0
	P.lfloat = {"lip": P.pos.y + 2.0, "n": Vector2(1, 0), "t": 0.0, "g0": false, "shove": false, "kb0": P.kb_t,
		"at": Vector2(P.pos.x, P.pos.z), "downed": false, "win": false, "tile": Vector2i(0, 0), "max_t": 5.0}
	m.step(DT)
	ok("bjorn #49: a mantle ends the launch within one frame", live and P.roll_t <= 0.0 and not K.launch.running(),
		"live %s roll %.2f" % [live, P.roll_t])
	P.lfloat = {}
	# glide pressed during the launch: out of it into a glide that keeps the launch's speed
	_ready_swing(m, P, T, home)
	step(m, in_win, press_at.bind(P, home + Vector3(9.0, 0, 0)))
	P.inp["fire"] = false
	step(m, 0.08)
	var open := _glide_open(m, P, true)
	ok("bjorn #49: glide pressed during the launch jumps him out into a glide at >= 70% of its speed",
		open >= K.launch.speed * 0.7, "glide opens at %.1f of %.1f m/s" % [open, K.launch.speed])
	await done(m)

## Steps until the glider opens (glide held when `hold`), returning his planar speed on that step (-1: never).
func _glide_open(m: Match, P: Hunter, hold: bool) -> float:
	for i in 90:
		P.inp["glide"] = hold
		P.inp["glide_btn"] = hold
		m.step(DT)
		if P.gliding:
			P.inp["glide"] = false
			P.inp["glide_btn"] = false
			return _planar(P)
	P.inp["glide"] = false
	P.inp["glide_btn"] = false
	return -1.0

## #49 off a ledge: the perfect launch carries him over the edge and the glider opens by itself at >= 70% of
## the launch's speed (the shared dash -> glide hand-off).
func _launch_glide() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var W: World = m.world
	for dz in range(-6, 7):
		for dx in range(3, 24):
			W.kind[W.idx(int(home.x) + dx, int(home.z) + dz)] = World.T_VOID
	_ready_swing(m, P, T, home)
	step(m, float(K.lmb_def()["full"]) + 0.08, press_at.bind(P, home + Vector3(9.0, 0, 0)))
	P.inp["fire"] = false
	var open := _glide_open(m, P, false)
	ok("bjorn #49: launched off a ledge he glides straight away at >= 70% of the launch's speed",
		open >= K.launch.speed * 0.7 and P.pos.x - home.x > 3.0,
		"glide opens at %.1f of %.1f m/s, %.1f m out" % [open, K.launch.speed, P.pos.x - home.x])
	await done(m)
