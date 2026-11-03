extends "res://tools/pin_bjorn_owner_check.gd"
## Owner items #48, #49 and #51 for Bjorn (briefs/OWNER_REVIEW_1103.md), run from --bulwark-combo-check
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
	for i in 20:
		m.step(DT)
		if left_at < 0.0 and String(K.mace.get("st", "")) == "fly":
			left_at = m.time - t0
	var wind := BulwarkKit.THROW_WIND
	ok("bjorn parity LMB: the throw's wind-up, the hammer leaves his hand %.2f-0.15 s after the press (one frame)" %
			wind, left_at >= wind and left_at <= 0.15 + 0.001 and K.anim_id == "bul_throw",
		"left at %.3f anim %s" % [left_at, K.anim_id])
	await _rmb_parity(m, P, K, home)
	await done(m)

## RMB (sheet 0179-0200, data Brightshield 0.1 s): the aegis is up 0.1 s into the hold and sweeps round with
## the cursor at once.
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
