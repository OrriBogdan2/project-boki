extends "res://tools/pin_bjorn_owner_check.gd"
## Owner items #48, #49, #51 and #59 for Breaker (briefs/OWNER_REVIEW_1103.md), run from --bulwark-combo-check
## (tools/archer_bulwark_combo_check.gd adds the counts): the Faultline plants him only for the wind-up and
## the slam, the held swing's perfect window launches him, into a glide off a ledge, and the hold pairs with a
## jump and a Shift dash (a perfect release out of either still launches); plus the LMB parity pass with the
## source (hero sheet bjorn.md): tracking in the hold, the throw's wind-up, the swing's timing. Prints AKCHECK
## lines.

const FAR := Vector3(30.0, 0, 6.0)      # the dummy parked out of the way
## s after the plant ends from which he must be at 90% of his run speed: a frame for the plant to lift, then
## the shared ground acceleration (Hunter.GROUND_ACCEL, ~0.055 s from a stand)
const FULL_STRIDE := 0.12

func bjorn() -> void:
	await _ult_walk()
	await _window()
	await _launch_flat()
	await _launch_glide()
	await _combo_moves()
	await _lmb_parity()
	await _hold_spin()
	await _audit()

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
	step(m, 2.0, press_at.bind(P, home + Vector3(9.0, 0, 0)))
	var held_on := K.slams == 0 and K.lmb_t > full + 2.0
	P.inp["fire"] = false
	step(m, 0.5)
	ok("bjorn #49 window: held past it nothing goes off by itself (sheet: a 2.6 s hold); let go, a normal swing",
		held_on and K.lmb_t < 0.0 and K.launch.launches == 0 and K.slams == 1,
		"held on %s launches %d slams %d" % [held_on, K.launch.launches, K.slams])
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

# ------------------------------------------------------------------ #51: the hold with a jump and a Shift dash
const ACT_S := 0.1             # s: owner #51, a jump or Shift out of the swing's step or launch acts within this

## One step with `key` pressed (a jump or a Shift), the swing still held on `at`.
func _tap_key(m: Match, P: Hunter, key: String, at: Vector3) -> void:
	P.inp[key] = true
	press_at(P, at)
	m.step(DT)
	P.inp[key] = false

## #51: the held swing keeps charging through a jump and a Shift dash and swings on the release there (in the
## air keeping his speed); a perfect release out of a jump or a dash still launches him; a jump or Shift in
## the swing's step or the launch acts within ACT_S.
func _combo_moves() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var at := home + Vector3(9.0, 0, 0)
	var full := float(K.lmb_def()["full"])
	var hold := press_at.bind(P, at)
	# a jump: still charging at the top, let go in the air it swings and he keeps his speed
	_ready_swing(m, P, T, home)
	P.inp["move"] = Vector2(1, 0)
	step(m, 0.6, hold)
	var t0 := K.lmb_t
	_tap_key(m, P, "jump", at)
	step(m, 0.2, hold)
	var charged := K.lmb_t - t0
	var up := not P.grounded
	var v0 := _planar(P)
	var s0 := K.slams
	P.inp["fire"] = false
	step(m, 0.05)
	ok("bjorn #51 hold > jump: it charges on through the jump and swings on the release in the air, keeping speed",
		up and charged >= 0.18 and K.slams == s0 + 1 and not P.grounded and _planar(P) >= v0 * 0.9,
		"charged %.2f in air %s slams %d speed %.1f -> %.1f" % [charged, up, K.slams - s0, v0, _planar(P)])
	# a Shift dash: the short dash goes, the swing charges on through it, and a release in the dash swings there
	_ready_swing(m, P, T, home)
	step(m, 0.6, hold)
	_tap_key(m, P, "dash", at)
	var short := String(K.st.get("last_dash")) == "short" and K.in_dash()
	m.step(DT)
	s0 = K.slams
	P.inp["fire"] = false
	m.step(DT)
	ok("bjorn #51 hold > Shift: the short dash goes, the swing charges on in it, let go there it swings at once",
		short and K.lmb_t < 0.0 and K.slams == s0 + 1, "short %s slams %d" % [short, K.slams - s0])
	P.inp["move"] = Vector2.ZERO
	# a perfect release out of a jump and out of a Shift dash: he launches from there
	for key in ["jump", "dash"]:
		_ready_swing(m, P, T, home)
		step(m, full - 0.3, hold)
		_tap_key(m, P, key, at)
		while K.lmb_t < full + 0.06:
			press_at(P, at)
			m.step(DT)
		var x0 := P.pos.x
		var air := not P.grounded
		var l0 := K.launch.launches
		P.inp["fire"] = false
		step(m, 0.6)
		ok("bjorn #51 perfect out of a %s: let go in the window %s, he launches >= 3.5 m" % [key,
				"in the air" if air else "after it"],
			K.launch.launches == l0 + 1 and P.pos.x - x0 >= 3.5 and (key == "dash" or air),
			"launches %d moved %.2f air %s" % [K.launch.launches - l0, P.pos.x - x0, air])
	# a jump or Shift in the swing's step or the launch acts within ACT_S
	for perfect in [false, true]:
		for key in ["jump", "dash"]:
			_ready_swing(m, P, T, home)
			K.st["last_dash"] = ""
			step(m, full + (0.06 if perfect else 0.3), hold)
			P.inp["fire"] = false
			m.step(DT)
			var stepping := P.roll_t > 0.0
			P.inp[key] = true
			var took := -1.0
			for i in 12:
				m.step(DT)
				P.inp[key] = false
				var went := P.vel.y > 0.5 if key == "jump" else String(K.st.get("last_dash")) != ""
				if went:
					took = (i + 1) * DT
					break
			ok("bjorn #51 %s in the %s acts within %.1f s" % ["a jump" if key == "jump" else "Shift",
					"perfect launch" if perfect else "swing's step", ACT_S],
				stepping and took > 0.0 and took <= ACT_S + 0.001, "in it %s took %.2f s" % [stepping, took])
	await done(m)

# ------------------------------------------------------------------ LMB parity with the source (bjorn.md)
## rad/s the cursor sweeps round him in the hold (sheet 0102-0108: about 1.5 turns in 1.2 s)
const SWEEP := 7.85
## rad: the most his facing may trail a cursor sweeping at SWEEP (he "turns with it")
const TRACK_LAG := deg_to_rad(25.0)

## The hold tracks the cursor (standing and walking), and the swing goes where the cursor is on the release,
## even straight behind him; the throw leaves the hand after one frame of wind-up; the swing lands on the
## release step and recovers in about 0.6 s (one frame of sweep plus ~0.4 s of recovery in the sheet).
func _lmb_parity() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	for walking in [false, true]:
		_ready_swing(m, P, T, home)
		step(m, 0.3, press_at.bind(P, home + Vector3(6.0, 0, 0)))
		var worst := 0.0
		var a := 0.0
		for i in int(0.7 / DT):
			a += SWEEP * DT
			P.inp["move"] = Vector2(0, 1) if walking else Vector2.ZERO
			press_at(P, P.pos + Vector3(cos(a), 0, sin(a)) * 5.0)
			m.step(DT)
			if i >= 9:
				var ad := P.aim_dir()
				worst = maxf(worst, absf(angle_difference(P.face, atan2(-ad.x, -ad.y))))
		P.inp["move"] = Vector2.ZERO
		ok("bjorn parity LMB: in the hold he turns with a cursor sweeping 1.25 turns a second%s (trails <= 25 deg)" %
				(", walking" if walking else ""),
			worst <= TRACK_LAG and K.lmb_t > 0.5 and not K.launch.in_window(K.lmb_t),
			"worst %.0f deg hold %.2f" % [rad_to_deg(worst), K.lmb_t])
	# let go with the cursor straight behind him: the swing goes there, on the release step
	T.teleport(P.pos + Vector3(-2.2, 0, 0))
	fresh(T)
	press_at(P, T.pos)
	m.step(DT)
	var s0 := K.slams
	P.inp["fire"] = false
	m.step(DT)
	var swung := K.slams == s0 + 1
	var recover := P.fire_cd
	step(m, 0.1)
	var hit_at_once := dmg(T) > 0.0 and swung
	ok("bjorn parity LMB: let go, the swing goes on the release step at the cursor (behind him), the hit within 0.1 s",
		hit_at_once and K.anim_id == "bul_smash", "took %.0f anim %s" % [dmg(T), K.anim_id])
	ok("bjorn parity LMB: the swing recovers in ~0.6 s (sheet: one frame of sweep, ~0.4 s of recovery)",
		absf(recover - float(K.lmb_def()["smash_rate"])) < 0.03 and recover >= 0.5 and recover <= 0.7,
		"fire_cd %.2f" % recover)
	# the throw: the arm cocks back, the hammer leaves the hand THROW_WIND s after the press
	_ready_swing(m, P, T, home)
	K.mace = {}
	P.fire_cd = 0.0
	press_at(P, home + Vector3(6.0, 0, 0))
	var t0: float = m.time
	m.step(DT)
	P.inp["fire"] = false
	var left_at := -1.0
	var cadence := 0.0
	for i in 20:
		m.step(DT)
		if left_at < 0.0 and String(K.mace.get("st", "")) == "fly":
			left_at = m.time - t0
			cadence = P.fire_cd
	var wind := BulwarkKit.THROW_WIND
	ok("bjorn parity LMB: the throw's wind-up, the hammer leaves his hand %.2f-0.15 s after the press (one frame)" %
			wind, left_at >= wind and left_at <= 0.15 + 0.001 and K.anim_id == "bul_throw",
		"left at %.3f anim %s" % [left_at, K.anim_id])
	ok("bjorn parity LMB: the throw's cadence is the source card's 0.45 s (sheet: 175 out, 175 back)",
		absf(float(K.lmb_def()["throw_rate"]) - 0.45) < 0.001 and cadence > 0.30 and cadence <= 0.45 + 0.001,
		"throw_rate %s fire_cd %.3f" % [K.lmb_def()["throw_rate"], cadence])
	await _rmb_parity(m, P, K, home)
	await done(m)

## RMB (sheet 0179-0200, data Brightshield 0.1 s): the aegis is up 0.1 s into the hold and sweeps round with
## the cursor at once.
## Item 59: the hold whirls the hammer round him, at least MIN_TURNS turns a second in every stretch of it, right
## through full charge, the perfect window and past it; he walks at the hold speed meanwhile; the whirl itself
## hurts nobody; a jump and Shift keep it; the release puts the hammer back and still slams at the cursor.
const MIN_TURNS := 1.0
const SPIN_STRETCH := 0.25     # s: the turn rate is measured over each of these

## The hammer's head round the circle's centre (rad, world), with the effect brought up to date.
func _head_angle(K: BulwarkKit) -> float:
	K.fx._tick_hold(DT)
	var gun := (K.fx._pivot() as Node3D).get_parent() as Node3D
	var at: Vector3 = K.fx._head_world() - gun.global_position
	return atan2(at.x, at.z)

## Holds on `at` for `secs`; the hammer's turns over it (it runs one way, a step is under half a turn).
func _spun(m: Match, P: Hunter, K: BulwarkKit, at: Vector3, secs: float, each := Callable()) -> float:
	var a := _head_angle(K)
	var total := 0.0
	for i in int(round(secs / DT)):
		press_at(P, at)
		if each.is_valid(): each.call()
		m.step(DT)
		var b := _head_angle(K)
		total += angle_difference(a, b)
		a = b
	return absf(total) / TAU

func _hold_spin() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var md := K.lmb_def()
	_ready_swing(m, P, T, home)
	var at := home + Vector3(9.0, 0, 0)
	T.teleport(home + Vector3(1.2, 0, 1.2))      # inside the circle, not where the release goes
	fresh(T)
	step(m, float(md["tap"]) + 0.1, press_at.bind(P, at))
	# let the hammer ease into the circle
	for i in 12: K.fx._tick_hold(DT)
	var slowest := 99.0
	var fastest := 0.0
	var reach := 0.0
	var trail := true
	var passed_window := false
	while K.lmb_t < float(md["full"]) + 0.7:
		passed_window = passed_window or K.launch.in_window(K.lmb_t)
		var turns := await _spun(m, P, K, at, SPIN_STRETCH) / SPIN_STRETCH
		slowest = minf(slowest, turns)
		fastest = maxf(fastest, turns)
		var head: Vector3 = K.fx._head_world()
		reach = maxf(reach, Vector2(head.x - P.pos.x, head.z - P.pos.z).length())
		trail = trail and K.fx.orbit_trail.visible
	ok("bjorn #59: held, the hammer keeps turning, >= %.1f turns/s in every %.2f s, through the window and on"
			% [MIN_TURNS, SPIN_STRETCH],
		slowest >= MIN_TURNS and passed_window and K.smash_k() >= 0.99, "%.2f-%.2f turns/s" % [slowest, fastest])
	ok("bjorn #59: the whirl speeds up with the charge",
		fastest >= slowest + 0.8 and fastest <= float(md["spin_turns"][1]) + 0.1,
		"%.2f-%.2f turns/s" % [slowest, fastest])
	ok("bjorn #59: the head runs at arm's length with its trail behind it", reach >= 1.5 and trail,
		"head %.2f m out, trail %s" % [reach, trail])
	ok("bjorn #59: the whirl hurts nobody (the default for now): a foe inside its circle took nothing in 2 s",
		dmg(T) == 0.0, "took %.0f" % dmg(T))
	# walking: the hold's speed (55% of his run, kept from the source), the hammer still round
	_ready_swing(m, P, T, home)
	var run0 := P.pos.z
	step(m, 0.5, func(): P.inp["move"] = Vector2(0, 1))
	var run := absf(P.pos.z - run0) / 0.5
	P.inp["move"] = Vector2.ZERO
	_ready_swing(m, P, T, home)
	step(m, float(md["tap"]) + 0.1, press_at.bind(P, at))
	P.inp["move"] = Vector2(0, 1)
	step(m, 0.1, press_at.bind(P, at))
	var z0 := P.pos.z
	var walked := await _spun(m, P, K, at, 0.5, func(): P.inp["move"] = Vector2(0, 1)) / 0.5
	var speed := absf(P.pos.z - z0) / 0.5
	P.inp["move"] = Vector2.ZERO
	ok("bjorn #59: he walks at the hold speed while it whirls (55% of his run)",
		walked >= MIN_TURNS and absf(speed / maxf(run, 0.01) - 0.55) <= 0.1,
		"%.2f turns/s at %.1f m/s, run %.1f" % [walked, speed, run])
	# a jump and Shift keep the whirl going (item 51)
	_ready_swing(m, P, T, home)
	step(m, 0.5, press_at.bind(P, at))
	_tap_key(m, P, "jump", at)
	var jumped := await _spun(m, P, K, at, 0.3) / 0.3
	ok("bjorn #59: a jump keeps the whirl", jumped >= MIN_TURNS and K.fx.held and not P.grounded,
		"%.2f turns/s" % jumped)
	_ready_swing(m, P, T, home)
	step(m, 0.5, press_at.bind(P, at))
	_tap_key(m, P, "dash", at)
	var dashed := await _spun(m, P, K, at, 0.3) / 0.3
	ok("bjorn #59: Shift keeps the whirl", dashed >= MIN_TURNS and K.fx.held, "%.2f turns/s" % dashed)
	# the release: the hammer back in his hand, the trail gone, the slam at the cursor
	var r2 := setup("bulwark", 7.0)
	m = r2[0]
	P = r2[1]
	T = r2[2]
	home = r2[4]
	K = P.ak
	_ready_swing(m, P, T, home)
	T.teleport(home + Vector3(2.2, 0, 0))
	fresh(T)
	step(m, 0.8, press_at.bind(P, T.pos))
	K.fx._tick_hold(DT)
	var s0 := K.slams
	P.inp["fire"] = false
	m.step(DT)
	K.fx._tick_hold(DT)
	var pv := K.fx._pivot() as Node3D
	ok("bjorn #59: let go, the slam goes at the cursor, the hammer back in the hand, the trail gone",
		K.slams == s0 + 1 and pv.transform == Transform3D.IDENTITY and not K.fx.orbit_trail.visible and not K.fx.held,
		"slams +%d trail %s" % [K.slams - s0, K.fx.orbit_trail.visible])
	step(m, 0.1)
	ok("bjorn #59: the slam hits", dmg(T) > 0.0, "took %.0f" % dmg(T))

func _rmb_parity(m: Match, P: Hunter, K: BulwarkKit, home: Vector3) -> void:
	step(m, 1.0)
	P.teleport(home)
	K.lock_t = 0.0
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	var up_at := -1.0
	var t := 0.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	while t < 0.4 and up_at < 0.0:
		P.inp["sec_hold"] = true
		m.step(DT)
		t += DT
		if not K.wall.is_empty():
			up_at = t
	ok("bjorn parity RMB: the aegis is up 0.1 s into the hold (data: a 0.1 s cast)",
		up_at > 0.0 and up_at <= 0.1 + 2.0 * DT,
		"up at %.2f" % up_at)
	var worst := 0.0
	var a := 0.0
	for i in 30:
		a += SWEEP * DT
		P.inp["sec_hold"] = true
		aim_at(P, P.pos + Vector3(cos(a), 0, sin(a)) * 5.0)
		m.step(DT)
		if K.wall.is_empty():
			break
		var mid: Vector2 = ((K.wall["a"] as Vector2) + (K.wall["b"] as Vector2)) * 0.5 - Vector2(P.pos.x, P.pos.z)
		worst = maxf(worst, absf(angle_difference(mid.angle(), P.aim_dir().angle())))
	P.inp["sec_hold"] = false
	ok("bjorn parity RMB: the aegis faces a sweeping cursor at once (within 10 deg)",
		not K.wall.is_empty() and worst <= deg_to_rad(10.0), "worst %.1f deg" % rad_to_deg(worst))
	step(m, 0.3)

# ------------------------------------------------------------------ kit audit (Nov 3 23:40)
## The audit's fixes: the thrown hammer's knock into a wall Crushes (data: any knock into a wall), a knock
## into another foe doesn't (data: walls only), and the raised aegis takes any blow from the front, melee
## included (data: Brightshield blocks all damage from the front), not one from behind.
func _audit() -> void:
	var r := setup("bulwark", 5.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: BulwarkKit = P.ak
	T2.teleport(home + Vector3(-20.0, 0, 8.0))
	_wall_at(m, T.pos, lv, 1)
	step(m, 0.3)
	K.mace = {}
	P.fire_cd = 0.0
	var c0 := K.crushes
	press_at(P, T.pos)
	m.step(DT)
	P.inp["fire"] = false
	step(m, 0.6)
	ok("bjorn audit: the thrown hammer knocking a foe into a wall Crushes it (stun)",
		K.crushes == c0 + 1 and T.stun_t > 0.0, "crushes %d stun %.2f" % [K.crushes - c0, T.stun_t])
	_clear_wall(m, T.pos, lv, 1)
	step(m, 1.5)
	await done(m)
	r = setup("bulwark", 2.4, "", true)
	m = r[0]
	P = r[1]
	T = r[2]
	T2 = r[3]
	home = r[4]
	K = P.ak
	T2.teleport(T.pos + Vector3(1.4, 0, 0))
	step(m, 0.3)
	c0 = K.crushes
	step(m, float(K.lmb_def()["full"]) + 0.3, press_at.bind(P, T.pos))
	P.inp["fire"] = false
	step(m, 0.6)
	ok("bjorn audit: a blow that knocks a foe into another foe (no wall) doesn't Crush (data: walls only)",
		K.crushes == c0 and dmg(T) > 0.0, "crushes %d took %.0f" % [K.crushes - c0, dmg(T)])
	# the aegis: a melee blow from the front lands on it, one from behind lands on him
	step(m, 1.0)
	P.teleport(home)
	T.teleport(home + Vector3(1.6, 0, 0))
	T2.teleport(home + Vector3(-1.6, 0, 0))
	fresh(T)
	K.lock_t = 0.0
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.shield_hp = K.shield_max()
	aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	K.press_rmb()
	step(m, 0.3, rmb_at.bind(P, T.pos))
	var hp0 := P.hp
	var w0 := float(K.wall.get("hp", 0.0))
	P.hurt(20.0, T, {"src": "melee", "melee": true, "kb": Vector2(-4, 0)})
	var front_ok := P.hp == hp0 and float(K.wall.get("hp", 0.0)) <= w0 - 19.0
	P.hurt(20.0, T2, {"src": "melee", "melee": true})
	ok("bjorn audit: the raised aegis takes a melee blow from the front (data: all damage from the front)",
		not K.wall.is_empty() and front_ok, "hp %.0f -> %.0f wall %.0f -> %.0f" % [hp0, P.hp, w0,
				float(K.wall.get("hp", 0.0))])
	ok("bjorn audit: a blow from behind still lands on him", P.hp < hp0, "hp %.0f -> %.0f" % [hp0, P.hp])
	_aegis_shots(m, P, T, T2, K)
	_aegis_hooks(m, P, T, T2)
	P.inp["sec_hold"] = false
	step(m, 0.3)
	await done(m)

## A foe's shot is stopped by the raised aegis from the front (the wall takes it, he and the ally behind it
## don't), and one fired from behind him lands on him (data: Brightshield blocks all damage from the front).
func _aegis_shots(m: Match, P: Hunter, T: Hunter, T2: Hunter, K: BulwarkKit) -> void:
	var aim := Vector3(0, 1.0, 0)
	var hp0 := P.hp
	var w0 := float(K.wall.get("hp", 0.0))
	m.spawn_shot(T, T.pos + aim, Vector2(-30.0, 0.0), 20.0, 1.0, 0.3, Color.WHITE, {"src": "abil"})
	step(m, 0.4)
	ok("bjorn audit: a shot from the front is stopped by the aegis (he takes none, it takes it)",
		P.hp == hp0 and float(K.wall.get("hp", 0.0)) <= w0 - 19.0, "hp %.0f -> %.0f wall %.0f -> %.0f" % [hp0, P.hp, w0,
				float(K.wall.get("hp", 0.0))])
	hp0 = P.hp
	m.spawn_shot(T2, T2.pos + aim, Vector2(30.0, 0.0), 20.0, 1.0, 0.3, Color.WHITE, {"src": "abil"})
	step(m, 0.4)
	ok("bjorn audit: a shot from behind lands on him", P.hp < hp0, "hp %.0f -> %.0f" % [hp0, P.hp])
	var cc := {"src": "abil", "stun": 1.0, "slow": 1.0, "root": 1.0}
	P.hurt(5.0, T, cc.duplicate())
	ok("bjorn audit: a stun, slow and root riding a hit from the front are blocked with it",
		P.stun_t == 0.0 and P.slow_t == 0.0 and P.root_t == 0.0,
		"stun %.1f slow %.1f root %.1f" % [P.stun_t, P.slow_t, P.root_t])
	P.hurt(5.0, T2, cc.duplicate())
	ok("bjorn audit: the same from behind lands", P.stun_t > 0.0, "stun %.1f" % P.stun_t)
	P.stun_t = 0.0
	P.slow_t = 0.0
	P.root_t = 0.0
	P.cc_immune_t = 0.0

## A hook is a pull and a pull is a shot: Kael's chain and Grimble's hand stop on the aegis from the front
## (the chain doesn't anchor to it, the hand doesn't grab), and catch him from behind.
func _hooker(m: Match, arch: String, at: Vector3) -> Hunter:
	return m.make_hunter(arch, 5, Arch.weight(arch), arch, "idle", {}, at, {"arch": arch})

func _aegis_hooks(m: Match, P: Hunter, T: Hunter, T2: Hunter) -> void:
	var home := P.pos
	T.teleport(home + Vector3(0, 0, 14.0))          # (the hooks mustn't find the idle dummies)
	T2.teleport(home + Vector3(0, 0, -14.0))
	var kael_h := _hooker(m, "juggernaut", home + Vector3(3.0, 0, 0))
	var grim_h := _hooker(m, "dredge", home + Vector3(-30.0, 0, 6.0))
	for t in [kael_h, grim_h]:
		t.unlock_all()
		t.lvl = 6
	for i in 3: m.step(DT)
	var kael: JuggernautKit = kael_h.ak
	var grimble: DredgeKit = grim_h.ak
	aim_at(kael_h, P.pos)
	kael.warchain.press()
	step(m, 0.6)
	ok("bjorn audit: Kael's chain from the front stops on the aegis (no anchor, no pull)",
		kael.warchain.state != "hooked" and kael.warchain.hooks == 0, "state %s" % kael.warchain.state)
	kael_h.teleport(home + Vector3(0, 0, 20.0))
	grim_h.teleport(home + Vector3(3.0, 0, 0))
	aim_at(grim_h, P.pos)
	grimble.fire_rmb({})
	var thrown: bool = float(grimble.cd["rmb"]) > 0.0 or grimble.ch_rmb < 1.0
	step(m, 0.8)
	ok("bjorn audit: Grimble's hand from the front stops on the aegis (no grab)", thrown and grimble.grapples == 0,
		"thrown %s grapples %d" % [thrown, grimble.grapples])
	step(m, 1.0)
	grim_h.teleport(home + Vector3(-3.0, 0, 0))
	grimble.cd["rmb"] = 0.0
	grimble.ch_rmb = 1.0
	aim_at(grim_h, P.pos)
	grimble.fire_rmb({})
	step(m, 0.8)
	ok("bjorn audit: Grimble's hand from behind catches him", grimble.grapples == 1, "grapples %d" % grimble.grapples)
