extends "res://tools/bjorn_launch_check.gd"
## Breaker's feel pass (docs/decisions/0022-breaker-swing-lunge.md, docs/heroes/bulwark.md), run from
## --bulwark-combo-check (tools/archer_bulwark_combo_check.gd adds the counts): the 0.9 body with its hitbox
## kept, the aegis boop, the Faultline hop and wider lane, the rope's auto-return and the swing lunges.
## Prints AKCHECK lines.

const OLD_SIZE := 2.0          # the body size before the pass: he is 0.9 of it
const OLD_WIDTH := 4.5         # m: the Faultline lane before the pass
const LUNGE_SLACK := 0.3       # m: a measured lunge may miss its data distance by this (step rounding, slide)

func albert() -> void:
	await _size()
	await _boop()
	await _ult_hop()
	await _rope()
	await _lunges()

## The body is 0.9 of the old one, the plate comes down with it, the hitbox stays.
func _size() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: BulwarkKit = P.ak
	var body := float(Arch.body("bulwark").size)
	ok("albert size: the body is 0.9 of the old one", absf(body / OLD_SIZE - 0.9) < 0.001, "size %.2f" % body)
	ok("albert size: the hitbox keeps its 0.46 m (fairness, the hit radius is not the look)",
		absf(P.r - 0.46) < 0.001, "r %.2f" % P.r)
	ok("albert size: the nameplate comes down with him (about 0.9 of 2.6 m)",
		absf(HudPlate.plate_offset(P) - 2.6 * 0.9) < 0.06, "plate %.2f" % HudPlate.plate_offset(P))
	ok("albert size: the hand height (throw, FX) scales with him", absf(K.hand_at().y - P.pos.y - 0.9) < 0.001,
		"hand %.2f" % (K.hand_at().y - P.pos.y))
	await done(m)

## LMB behind the raised aegis: a thrust that shoves a foe in front, no damage, the wall back home after it.
func _boop() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var bd := K.boop.bd()
	var east := home + Vector3(6.0, 0, 0)
	step(m, 0.3)
	P.teleport(home)
	P.vel = Vector3.ZERO
	K.lock_t = 0.0
	K.cd["rmb"] = 0.0
	K.shield_hp = K.shield_max()
	T.teleport(home + FAR)
	fresh(T)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, rmb_at.bind(P, east))
	var rest := float(K.wall["dist"])
	T.teleport(home + Vector3(2.3, 0, 0))
	fresh(T)
	var x0 := T.pos.x
	var s0 := K.slams
	var t0 := K.throws
	P.inp["fire"] = true
	rmb_at(P, east)
	m.step(DT)
	var anim := K.anim_id
	var peak := 0.0
	var t := 0.0
	while t < 0.4:
		rmb_at(P, east)
		m.step(DT)
		t += DT
		peak = maxf(peak, float(K.wall.get("dist", 0.0)) - rest)
	P.inp["fire"] = false
	step(m, 0.3, rmb_at.bind(P, east))
	var span := float(bd["wind"]) + float(bd["snap"]) + float(bd["settle"])
	ok("albert boop: the thrust is 0.25-0.35 s (bul_boop)", span >= 0.25 and span <= 0.35 and anim == "bul_boop",
		"%.2f s anim %s" % [span, anim])
	ok("albert boop: the aegis snaps out and comes home", peak >= float(bd["thrust"]) * 0.9
		and absf(float(K.wall["dist"]) - rest) < 0.001, "peak +%.2f rest %.2f" % [peak, float(K.wall["dist"])])
	ok("albert boop: a foe in front is shoved back, no damage, no swing or throw",
		K.boop.booped == 1 and T.pos.x - x0 >= float(bd["push"]) * 0.8 and dmg(T) == 0.0 and K.slams == s0
		and K.throws == t0, "booped %d moved %.2f dmg %.1f" % [K.boop.booped, T.pos.x - x0, dmg(T)])
	var b0 := K.boop.boops
	for i in 6:
		P.inp["fire"] = i % 2 == 0
		step(m, 0.05, rmb_at.bind(P, east))
	P.inp["fire"] = false
	ok("albert boop: mashing waits out its cooldown", K.boop.boops - b0 == 1, "thrusts %d" % (K.boop.boops - b0))
	P.inp["sec_hold"] = false
	step(m, 0.4)
	await done(m)

## R: a 1-1.5 m hop with the hammer up, the slam on the old 0.4 s, back on the ground; a 22% wider lane.
func _ult_hop() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var xd: Dictionary = K.d["x"]
	var wind := float(xd["windup"])
	var width := float(xd["width"])
	ok("albert ult: the lane is 20-25% wider (telegraph and hits read the one width)",
		width / OLD_WIDTH >= 1.2 and width / OLD_WIDTH <= 1.25, "%.1f -> %.1f m" % [OLD_WIDTH, width])
	step(m, 0.3)
	P.teleport(home)
	P.vel = Vector3.ZERO
	var y0 := P.pos.y
	# a dummy 8 m down the lane, 3 m off its line: outside the old lane, inside the new
	T.teleport(home + Vector3(8.0, 0, 3.0))
	fresh(T)
	K.cd["x"] = 0.0
	aim_at(P, home + Vector3(12.0, 0, 0))
	press_x(m, P)
	var top := 0.0
	var slam_at := -1.0
	var down_at_slam := false
	var t := DT
	while t < 1.2:
		m.step(DT)
		t += DT
		top = maxf(top, P.pos.y - y0)
		if slam_at < 0.0 and K.ult.phase == "erupt":
			slam_at = t
			down_at_slam = P.pos.y - y0 < 0.15
	ok("albert ult: he hops 1-1.5 m with the hammer up", top >= 1.0 and top <= 1.5, "top %.2f m" % top)
	ok("albert ult: the slam keeps its 0.4 s and lands him on the ground",
		absf(slam_at - wind) <= 2.0 * DT and down_at_slam and P.grounded,
		"slam at %.2f, %.2f m up" % [slam_at, P.pos.y - y0])
	ok("albert ult: a foe 3 m off the line is thrown (outside the old lane, inside the new)", dmg(T) > 0.0,
		"took %.0f" % dmg(T))
	await done(m)

## The rope: the hammer reels home past "rope.max_len" m or after "rope.max_t" s, the throw shut till the catch.
func _rope() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var rd: Dictionary = K.lmb_def()["rope"]
	# by length: thrown 6 m east, he steps 12 m west of where he stood
	_ready_swing(m, P, T, home)
	_tap_throw(m, P, home + Vector3(6.0, 0, 0))
	step(m, 0.6)
	var landed := not K.mace.is_empty() and String(K.mace["st"]) == "ground"
	var r0 := K.reels
	P.teleport(home - Vector3(float(rd["max_len"]) - 4.0, 0, 0))
	m.step(DT)
	m.step(DT)
	var reeled := K.reels == r0 + 1 and String(K.mace.get("st", "")) == "back"
	var t0 := K.throws
	_tap_throw(m, P, P.pos + Vector3(-5.0, 0, 0))
	var shut := K.throws == t0
	var t := 0.0
	while not K.mace.is_empty() and t < 3.0:
		m.step(DT)
		t += DT
	ok("albert rope: past %.0f m the hammer reels home on its own, the throw shut till the catch" % rd["max_len"],
		landed and reeled and shut and K.mace.is_empty() and not K.fx.taut,
		"landed %s reeled %s shut %s home in %.2f s" % [landed, reeled, shut, t])
	step(m, 0.3)
	_tap_throw(m, P, P.pos + Vector3(5.0, 0, 0))
	ok("albert rope: caught, it throws again", K.throws == t0 + 1, "throws %d" % (K.throws - t0))
	# by time: thrown 6 m, he stands by it
	_ready_swing(m, P, T, home)
	step(m, 1.0)
	var r1 := K.reels
	_tap_throw(m, P, home + Vector3(6.0, 0, 0))
	var out := 0.0
	while K.reels == r1 and out < float(rd["max_t"]) + 1.0:
		m.step(DT)
		out += DT
	ok("albert rope: left out %.0f s it reels home on its own" % rd["max_t"],
		K.reels == r1 + 1 and absf(out - float(rd["max_t"])) < 0.2, "after %.2f s" % out)
	step(m, 1.5)
	await done(m)

## One LMB tap aimed at `at` (a throw when the hammer is in hand).
func _tap_throw(m: Match, P: Hunter, at: Vector3) -> void:
	P.fire_cd = 0.0
	press_at(P, at)
	m.step(DT)
	m.step(DT)
	P.inp["fire"] = false
	m.step(DT)

## The swing lunge: a part charge the short end of "lunge.d", a full one the long end, running further, in
## the air "air_k" of it; the 360 Smash's spin lunges on "spin_d" m.
func _lunges() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var ld := K.lunge.ld()
	var full := float(K.lmb_def()["full"])
	var at := home + Vector3(9.0, 0, 0)
	_ready_swing(m, P, T, home)
	step(m, float(K.lmb_def()["tap"]) + 0.05, press_at.bind(P, at))
	P.inp["fire"] = false
	step(m, 0.8)
	var part := K.lunge.last_d
	_ready_swing(m, P, T, home)
	_swing(m, P, home, full + 0.3)
	var whole := K.lunge.last_d
	var d: Array = ld["d"]
	ok("albert lunge: standing, a part charge ~%.1f m and a full one ~%.1f m (the finisher pulls more)" % [d[0], d[1]],
		absf(part - float(d[0])) < LUNGE_SLACK and absf(whole - float(d[1])) < LUNGE_SLACK and K.lunge.count >= 2,
		"part %.2f full %.2f" % [part, whole])
	# running east into the full swing: his run stacks on the pull
	_ready_swing(m, P, T, home)
	step(m, full + 0.3, func():
		press_at(P, at)
		P.inp["move"] = Vector2(1, 0))
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	step(m, 0.8)
	var run := K.lunge.last_d
	ok("albert lunge: running, the swing travels further than standing", run > whole + 0.3,
		"run %.2f standing %.2f" % [run, whole])
	# in the air: the same full swing let go at the top of a standing jump pulls "air_k" of it
	_ready_swing(m, P, T, home)
	step(m, full + 0.1, press_at.bind(P, at))
	_tap_key(m, P, "jump", at)
	step(m, 0.2, press_at.bind(P, at))
	var up := not P.grounded
	P.inp["fire"] = false
	step(m, 1.2)
	var air := K.lunge.last_d
	var want := float(d[1]) * float(ld["air_k"])
	ok("albert lunge: in the air it pulls ~%.0f%% of the ground's" % (100.0 * float(ld["air_k"])),
		up and K.lunge.last_air and absf(air - want) < LUNGE_SLACK,
		"air %.2f (want %.2f) ground %.2f" % [air, want, whole])
	# the 360 Smash: a dash then the spin, which lunges on
	_ready_swing(m, P, T, home)
	P.dashes = P.max_dashes()
	aim_at(P, at)
	P.inp["dash"] = true
	m.step(DT)
	P.inp["dash"] = false
	step(m, 1.2)
	ok("albert lunge: the 360 Smash's spin lunges him on at least %.1f m (the dash's speed stacks like a run)"
		% ld["spin_d"], K.lunge.last_kind == "spin" and K.lunge.last_d >= float(ld["spin_d"]) - 0.1
		and K.lunge.last_d <= float(ld["spin_d"]) + P.base_speed * float(ld["t"]) + LUNGE_SLACK,
		"%s %.2f m" % [K.lunge.last_kind, K.lunge.last_d])
	await done(m)
