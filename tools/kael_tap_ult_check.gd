extends RefCounted
## Kael, owner playtest 11-08 item 11: a tap of RMB is always an overhead strike (lighter, on its own cooldown,
## while the Smash rests), RMB aims anywhere once E has hooked, a Lunge carried past the chain's length breaks it,
## and the Gilded Riposte keeps his momentum (a run carries on, a rise gets a lift, a ledge rise hands over).
## Runs inside --juggernaut-combo-check (tools/zedran_feel_check.gd). A is tools/archetype_check.gd.

const AKCheck := preload("res://tools/archetype_check.gd")
var A: AKCheck
var m: Match
var P: Hunter
var T: Hunter
var T2: Hunter
var K: JuggernautKit
var home: Vector3

func run(a) -> void:
	A = a
	var r := A.setup("juggernaut", 20.0, "", true)
	m = r[0]
	P = r[1]
	T = r[2]
	T2 = r[3]
	home = r[4]
	K = P.ak
	tap_strike()
	aim_after_hook()
	ult_momentum()
	ult_rise()
	tether_break()
	await A.done(m)

func _fresh() -> void:
	A.step(m, 0.7)
	K.warchain.snap("")
	K.riposte.drop()
	K.lunge = {}
	A.step(m, 0.1)
	P.teleport(home)
	P.vel = Vector3.ZERO
	for s in ["e", "rmb", "x", "air", "tap"]:
		K.cd[s] = 0.0
	K.ch_rmb = float(K.rmb_charges())
	for f in [T, T2]:
		A.fresh(f)
		f.teleport(home + Vector3(0, 0, 9.0 if f == T else -9.0))     # parked off the strip's middle
	m.step(A.DT)

func _hook(at: Vector3) -> void:
	T.teleport(at)
	A.aim_at(P, at)
	K.use_e()
	A.step(m, 0.4)
	K.warchain.tether_t = 5.0

func tap_strike() -> void:
	_fresh()
	var ts: Dictionary = K.rmb_def()["tap_strike"]
	var sl: Dictionary = K.rmb_def()["slam"]
	T.teleport(home + Vector3(1.0, 0, 0))
	A.aim_at(P, T.pos)
	K.ch_rmb = 0.0
	K.cd["rmb"] = 99.0
	A.tap(m, P)
	var drawn := float(AimKit.entry(P, "slam").get("len", 0.0))
	A.ok("jug tap strike: the Smash resting, a tap still winds up an overhead strike, its cone drawn at the reach",
			not K.slam_w.is_empty() and absf(drawn - float(sl["radius"]) * float(ts["reach_k"])) < 0.05,
			"len %.2f" % drawn)
	A.step(m, float(ts["windup"]) + 0.1)
	var full := float(sl["dmg"])
	A.ok("jug tap strike: it lands lighter than the Slam and spends no charge",
			A.dmg(T) > 1.0 and A.dmg(T) < full * 0.95 and K.ch_rmb < 1.0, "took %.1f of %.0f" % [A.dmg(T), full])
	A.tap(m, P)
	A.step(m, 0.1)
	A.ok("jug tap strike: its own cooldown holds a second tap", K.slam_w.is_empty() and float(K.cd["tap"]) > 0.0,
			"tap cd %.2f" % float(K.cd["tap"]))

## The Warchain hooked east, a tap aimed 90 and 180 degrees off it strikes where the cursor is; the chain stays.
func aim_after_hook() -> void:
	for off in [Vector3(0, 0, -2.5), Vector3(-2.5, 0, 0)]:
		_fresh()
		_hook(home + Vector3(6.0, 0, 0))
		T2.teleport(home + off)
		A.aim_at(P, T2.pos)
		A.tap(m, P)
		A.step(m, float(K.rmb_def()["windup"]) + 0.1)
		A.ok("jug item 11: hooked east, a tap aimed %.0f deg off the chain strikes there; the chain holds"
				% rad_to_deg(Vector2(1, 0).angle_to(Vector2(off.x, off.z))),
				A.dmg(T2) >= 20.0 and K.warchain.hooked(), "took %.0f hooked %s" % [A.dmg(T2), K.warchain.hooked()])

func ult_momentum() -> void:
	var xd := K.x_def()
	_fresh()
	P.vel = Vector3(6.0, 0, 0)
	K.riposte.start()
	var sp := Vector2(P.vel.x, P.vel.z).length()
	A.ok("jug X keeps momentum: the run carries into the guard", absf(sp - 6.0 * float(xd["carry_k"])) < 0.1,
			"before %s after %s" % [K.riposte.vel_before, K.riposte.vel_after])
	var p0 := P.pos
	A.step(m, 0.1)
	A.ok("jug X keeps momentum: still moving 0.1s into the guard", Vector2(P.vel.x, P.vel.z).length() > 1.0
			and P.pos.x - p0.x > 0.2, "moved %.2f" % (P.pos.x - p0.x))
	K.riposte.drop()
	# E in the guard: the pull takes his motion over from the carry
	_fresh()
	_hook(home + Vector3(8.0, 0, 0))
	P.vel = Vector3(0, 0, 6.0)
	K.riposte.start()
	K.use_e()
	A.ok("jug X: E in the guard pulls him in, the carry handed to the pull",
			K.warchain.pulling() and K.riposte.st.get("carry", Vector2.ONE) == Vector2.ZERO)

## His height off a jump at its top, `ult`: cast three steps into it (still rising fast).
func _jump_peak(ult: bool) -> float:
	_fresh()
	var y0 := P.pos.y
	P.inp["jump"] = true
	m.step(A.DT)
	P.inp["jump"] = false
	A.step(m, A.DT * 2.0)
	if ult:
		K.riposte.start()
	var peak := y0
	for i in 50:
		m.step(A.DT)
		peak = maxf(peak, P.pos.y)
	K.riposte.drop()
	return peak - y0

## Cast rising, the lift takes him higher than the plain jump; cast in a ledge rise (up a two-terrace block
## carved on the strip), the rise hands over to the lift instead of rewriting his climb.
func ult_rise() -> void:
	var xd := K.x_def()
	var plain := _jump_peak(false)
	var lifted := _jump_peak(true)
	A.ok("jug X keeps momentum: cast rising from a jump, the lift takes him higher", lifted - plain > 0.3,
			"peak %.2f m, the plain jump's %.2f" % [lifted, plain])
	var W: World = m.world
	var x0 := int(floor(home.x))
	var z0 := int(floor(home.z))
	var lv := int(W.level[W.idx(x0, z0)])
	var carved := []
	for dz in range(-2, 3):
		for dx in range(3, 6):
			var ci := W.idx(x0 + dx, z0 + dz)
			carved.append([ci, W.level[ci]])
			W.level[ci] = lv + 2
	_fresh()
	P.teleport(Vector3(x0 + 3.0 - P.r - 0.6, home.y, home.z))     # (move_feel_check's start off the face)
	var climbing := false
	for i in 60:
		P.inp["move"] = Vector2(1, 0)
		P.inp["jump"] = i == 2
		m.step(A.DT)
		climbing = not P.lfloat.is_empty() and P.vel.y >= float(xd["rise_min"])
		if climbing: break
	P.inp["move"] = Vector2.ZERO
	P.inp["jump"] = false
	var y0 := P.pos.y
	K.riposte.start()
	A.step(m, 0.15)
	A.ok("jug X mid-mantle: the ledge rise hands over to the lift", climbing and P.lfloat.is_empty()
			and P.pos.y - y0 > 0.3, "climbing %s, rose %.2f vy %.2f" % [climbing, P.pos.y - y0, P.vel.y])
	K.riposte.drop()
	for c in carved:
		W.level[c[0]] = c[1]

## The chain hooked 20 m off: a Lunge sideways stays inside 24 m and keeps it; one backward carries him past
## the length and breaks it: no clamp, no snap back. Walking back holds taut (zedran_feel_check).
func tether_break() -> void:
	_fresh()
	_hook(home + Vector3(6.0, 0, 0))
	T.teleport(home + Vector3(20.0, 0, 0))
	A.aim_at(P, home + Vector3(0, 0, -6.0))
	K._lunge(1.0, false)
	A.step(m, 0.4)
	var kept := K.warchain.hooked()
	K.lunge = {}
	P.vel = Vector3.ZERO
	var b0 := K.warchain.breaks
	A.ok("jug item 11: a Lunge sideways within the chain's length keeps it", kept, "dist %.1f" % P.flat_dist(T))
	A.aim_at(P, P.pos + Vector3(-6.0, 0, 0))
	K._lunge(1.0, false)
	A.step(m, 0.6)
	A.ok("jug item 11: a Lunge backward past the chain's length breaks it",
			not K.warchain.hooked() and K.warchain.breaks == b0 + 1, "breaks %d dist %.1f" % [K.warchain.breaks - b0,
			P.flat_dist(T)])
