extends RefCounted
## Venator's parity pass (docs/heroes/gunslinger.md, "Parity pass"), run inside --gunslinger-combo-check
## (tools/hero_combo_check.gd): the rifle's cadence, how its rounds track the cursor while he walks, the 30-round
## drum that refills whenever the trigger rests, the firing brackets, the shouldered recoil pose, and the Burr
## Charge's side toss (the owner's call over the footage's overhand) with him walking through the hold.

const ROUND_GAP := 0.12      # s between rounds held
const MAG := 30              # rounds in the drum (game data: a 30-round magazine)
const REFILL_BY := 1.2       # s of rest that brings a drum back from 18 to full ("rapidly reloads when not firing")
const TURN_180 := 0.2        # s: the body turns 180 degrees to a new cursor (the source's 1280 deg/s: 0.14s)
const WALK_KEEP := 0.85      # share of his walk he keeps while firing or holding the grenade
const SWEEP := 6.0           # rad/s the cursor swings round him (a round a step late would be 5.7 degrees off)
var C                        # the combo check (ok, ac, helpers)

func _init(check) -> void:
	C = check

func run(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	_rounds(m, P, home)
	_tracking(m, P, home)
	_drum(m, P, K, home)
	_brackets(m, P, home)
	_rifle_pose()
	_side_toss(m, P, K, T, home)
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	C.ac.step(m, 0.5)

func _rounds(m: Match, P: Hunter, home: Vector3) -> void:
	P.teleport(home)
	P.reload_t = 0.0
	P.ammo = MAG
	P.fire_cd = 0.0
	var rec := {"t": 0.0, "n": P.shot_n, "at": []}
	C.ac.step(m, 1.0, func():
		C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
		P.inp["fire"] = true
		if P.shot_n > int(rec["n"]):
			rec["n"] = P.shot_n
			(rec["at"] as Array).append(rec["t"])
		rec["t"] = float(rec["t"]) + C.DT)
	P.inp["fire"] = false
	var at: Array = rec["at"]
	var even := at.size() >= 7
	for i in range(1, at.size()):
		even = even and absf(float(at[i]) - float(at[i - 1]) - ROUND_GAP) <= C.DT * 1.5
	C.ok("Venator parity LMB: held, a round every 0.12s", even, "%d rounds" % at.size())

## Walking while the cursor sweeps round him: every round leaves along the aim of its own step, and a cursor
## swung behind him turns his body round at the source's rate.
func _tracking(m: Match, P: Hunter, home: Vector3) -> void:
	C.ac.step(m, 0.5)
	P.teleport(home)
	P.ammo = MAG
	var sweep := {"a": 0.0, "worst": 0.0, "n": P.shot_n, "rounds": 0}
	P.inp["move"] = Vector2(0, 1)
	var p0 := P.pos
	C.ac.step(m, 0.9, func():
		var sd: Dictionary = C._last_shot(m, P)
		if P.shot_n > int(sweep["n"]) and not sd.is_empty():
			sweep["n"] = P.shot_n
			sweep["rounds"] = int(sweep["rounds"]) + 1
			var off := absf((sd["vel"] as Vector2).angle_to(P.aim_dir()))
			sweep["worst"] = maxf(float(sweep["worst"]), rad_to_deg(off))
		sweep["a"] = float(sweep["a"]) + SWEEP * C.DT
		var aim := Vector2.from_angle(float(sweep["a"]))
		P.inp["aim"] = P.pos + Vector3(aim.x * 6.0, 0.9, aim.y * 6.0)
		P.inp["fire"] = true)
	var walked := P.flat_dist(p0) / 0.9
	P.inp["fire"] = false
	var plain := _walk_speed(m, P)
	C.ok("Venator parity LMB: walking with the cursor sweeping round, every round leaves on the aim",
			int(sweep["rounds"]) >= 6 and float(sweep["worst"]) < rad_to_deg(float(P.wpn["spread"])) + 2.0,
			"%d rounds, worst %.1f degrees, walked %.2f m/s" % [sweep["rounds"], sweep["worst"], walked])
	C.ok("Venator parity LMB: he keeps walking while he fires (85% of his walk or more)",
			walked >= plain * WALK_KEEP, "%.2f of %.2f m/s" % [walked, plain])
	P.inp["move"] = Vector2.ZERO
	C.ac.step(m, 0.3)
	C.ac.aim_at(P, P.pos + Vector3(5.0, 0, 0))
	C.ac.step(m, 0.3)
	C.ac.aim_at(P, P.pos + Vector3(-5.0, 0, 0))
	var turn := {"t": C.DT, "done": -1.0}
	C.ac.step(m, 0.4, func():
		if float(turn["done"]) < 0.0 and absf(wrapf(P.face - PI * 0.5, -PI, PI)) < deg_to_rad(10.0):
			turn["done"] = turn["t"]
		turn["t"] = float(turn["t"]) + C.DT)
	C.ok("Venator parity LMB: the body turns 180 degrees to the cursor inside 0.2s (source 1280 deg/s)",
			float(turn["done"]) > 0.0 and float(turn["done"]) <= TURN_180, "%.2f s" % turn["done"])

## The drum: 30 rounds; resting refills it fast (none in the first beat of a pause), running it dry is the normal
## reload, which nothing refills early.
func _drum(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	P.teleport(home)
	P.reload_t = 0.0
	P.ammo = MAG
	C.ac.step(m, 0.5)
	P.fire_cd = 0.0
	var s0 := P.shot_n
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	for i in 200:
		if P.shot_n - s0 >= 12:
			break
		P.inp["fire"] = true
		m.step(C.DT)
	P.inp["fire"] = false
	var after12 := P.ammo
	var t_full := {"t": 0.0, "at": -1.0, "early": P.ammo}
	C.ac.step(m, 0.25)
	t_full["early"] = P.ammo
	C.ac.step(m, 2.0, func():
		if float(t_full["at"]) < 0.0 and P.ammo >= MAG:
			t_full["at"] = t_full["t"]
		t_full["t"] = float(t_full["t"]) + C.DT)
	C.ok("Venator parity LMB: a 30-round drum that refills fast once the trigger rests (none in the first beat)",
			int(P.wpn["mag"]) == MAG and after12 == MAG - 12 and int(t_full["early"]) == MAG - 12
			and float(t_full["at"]) > 0.0 and float(t_full["at"]) <= REFILL_BY,
			"after 12: %d, after 0.25s rest: %d, full at %.2f s" % [after12, t_full["early"], t_full["at"]])
	C.ac.step(m, 6.0, func():
		C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
		P.inp["fire"] = P.ammo > 0 and P.reload_t <= 0.0)
	P.inp["fire"] = false
	P.ammo = 0
	P.start_reload()
	C.ac.step(m, 0.8)
	C.ok("Venator parity LMB: run dry, it's the normal reload, and the rest doesn't refill it early",
			P.reload_t > 0.0 and P.ammo == 0 and K.refill_part == 0.0, "reload %.2f ammo %d" % [P.reload_t, P.ammo])
	C.ac.step(m, 1.5)

## The firing brackets: two arcs either side of him while he fires (your screen only), gone soon after.
func _brackets(m: Match, P: Hunter, home: Vector3) -> void:
	P.teleport(home)
	P.reload_t = 0.0
	P.ammo = MAG
	C.ac.step(m, 0.4, func():
		C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
		P.inp["fire"] = true)
	var e := AimKit.entry(P, "lmb_bracket1")
	var on := AimKit.shown(P, "lmb_bracket1") and AimKit.shown(P, "lmb_bracket-1") and not bool(e.get("all", true))
	P.inp["fire"] = false
	C.ac.step(m, 0.4)
	C.ok("Venator parity LMB: firing brackets either side of him while he fires (yours only), gone after",
			on and absf(float(e.get("radius", 0.0)) - GunslingerKit.BRACKET_R) < 0.01
			and not AimKit.shown(P, "lmb_bracket1"))

## The rifle's pose: each round kicks the gun (stock back, muzzle up) by 0.025s and is back on the shouldered
## pose by 0.09, before the next round; the legs are a stance (walking, they keep walking).
func _rifle_pose() -> void:
	var mv: Dictionary = KMovesVV.MOVES["gunslinger_lmb"]
	var a := HunterAnim.km_sample("gunslinger_lmb", 0.0)
	var b := HunterAnim.km_sample("gunslinger_lmb", 0.09)
	var kick := HunterAnim.km_sample("gunslinger_lmb", 0.025)
	var same := is_equal_approx(a["p"], b["p"]) and is_equal_approx(a["gp"], b["gp"]) \
			and (a["wo"] as Vector3).is_equal_approx(b["wo"])
	C.ok("Venator parity LMB: each round kicks the gun by 0.025s, back on the shoulder by 0.09 (rounds 0.12 apart)",
			same and float(kick["gp"]) > 0.15 and absf(float(kick["p"]) - float(a["p"])) < 0.15
			and bool(mv.get("stance", false)),
			"gp %.2f, torso %.2f -> %.2f" % [kick["gp"], a["p"], kick["p"]])

## The Burr Charge, the owner's side toss rather than overhead: held low at the hip with little wind-up while he
## walks, flicked sidearm on release, leaving from the hip.
func _side_toss(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	var hold := HunterAnim.km_sample("gunslinger_rmb_hold", 0.6)
	var release := HunterAnim.km_sample("gunslinger_rmb", 0.05)
	var low := (hold["fl"] as Vector3).y < 0.0 and (hold["fl"] as Vector3).x < -0.3
	var flick := (release["fl"] as Vector3).z < -0.5 and (release["fl"] as Vector3).y < 0.1
	var stance := bool(KMovesVV.MOVES["gunslinger_rmb_hold"].get("stance", false)) \
			and bool(KMovesVV.MOVES["gunslinger_rmb"].get("stance", false))
	T.teleport(home + Vector3(30, 0, 8))
	P.teleport(home)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	var plain := _walk_speed(m, P)
	var p0 := P.pos
	P.inp["sec_hold"] = true
	K.press_rmb()
	C.ac.step(m, 0.6, func(): P.inp["sec_hold"] = true)
	var walked := P.flat_dist(p0) / 0.6
	var n0 := K.burrs.size()
	P.inp["sec_hold"] = false
	m.step(C.DT)
	var b: Dictionary = K.burrs[-1] if K.burrs.size() > n0 else {}
	P.inp["move"] = Vector2.ZERO
	var y := float(b.get("y0", 9.0)) - float(b.get("g0", 0.0))
	C.ok("Venator parity RMB: a side toss, held low at the hip, flicked sidearm at 0.05s, leaving from the hip",
			low and flick and stance and absf(y - GunslingerKit.TOSS_Y) < 0.2,
			"hand %s -> %s, leaves %.2f m up" % [hold["fl"], release["fl"], y])
	C.ok("Venator parity RMB: he keeps walking through the hold (85% of his walk or more)",
			walked >= plain * WALK_KEEP, "%.2f of %.2f m/s" % [walked, plain])
	C.ac.step(m, 1.5)

## His plain walk (move held down the screen, not firing), in m/s; he is still walking when it returns.
func _walk_speed(m: Match, P: Hunter) -> float:
	P.inp["move"] = Vector2(0, 1)
	C.ac.step(m, 0.3)
	var p0 := P.pos
	C.ac.step(m, 0.6)
	return P.flat_dist(p0) / 0.6
