extends RefCounted
## Kael, owner playtest 11-08 item 11 (the tap strike while the Smash rests is not ported: main's --cd-gate-check
## keeps a slot on cooldown silent): RMB aims anywhere once E has hooked, a Lunge carried past the chain's length
## breaks it, and the Gilded Riposte keeps his momentum (a run carries on, a rise gets a lift, a ledge rise hands over).
## Runs inside --juggernaut-combo-check (tools/zedran_feel_check.gd). A is tools/archetype_check.gd.

const AKCheck := preload("res://tools/archetype_check.gd")
var a_v: AKCheck
var m: Match
var p: Hunter
var t: Hunter
var t2: Hunter
var k: JuggernautKit
var home: Vector3


func run(a) -> void:
	a_v = a
	var r := a_v.setup("juggernaut", 20.0, "", true)
	m = r[0]
	p = r[1]
	t = r[2]
	t2 = r[3]
	home = r[4]
	k = p.ak
	aim_after_hook()
	ult_momentum()
	ult_rise()
	tether_break()
	await a_v.done(m)


func _fresh() -> void:
	a_v.step(m, 0.7)
	k.warchain.snap(true)
	k.riposte.drop()
	k.lunge = {}
	a_v.step(m, 0.1)
	p.teleport(home)
	p.vel = Vector3.ZERO
	for s in ["e", "rmb", "x", "air"]:
		k.cd[s] = 0.0
	k.ch_rmb = float(k.rmb_charges())
	for f in [t, t2]:
		a_v.fresh(f)
		f.teleport(home + Vector3(0, 0, 9.0 if f == t else -9.0))  # parked off the strip's middle
	m.step(a_v.DT)


func _hook(at: Vector3) -> void:
	t.teleport(at)
	a_v.aim_at(p, at)
	k.use_e()
	a_v.step(m, 0.4)
	k.warchain.tether_t = 5.0


func aim_after_hook() -> void:
	for off in [Vector3(0, 0, -2.5), Vector3(-2.5, 0, 0)]:
		_fresh()
		_hook(home + Vector3(6.0, 0, 0))
		t2.teleport(home + off)
		a_v.aim_at(p, t2.pos)
		a_v.tap(m, p)
		a_v.step(m, float(k.rmb_def()["windup"]) + 0.1)
		a_v.ok(
			(
				"jug item 11: hooked east, a tap aimed %.0f deg off the chain strikes there; the chain holds"
				% rad_to_deg(Vector2(1, 0).angle_to(Vector2(off.x, off.z)))
			),
			a_v.dmg(t2) >= 20.0 and k.warchain.hooked(),
			"took %.0f hooked %s" % [a_v.dmg(t2), k.warchain.hooked()]
		)


func ult_momentum() -> void:
	var xd := k.x_def()
	_fresh()
	p.vel = Vector3(6.0, 0, 0)
	k.riposte.start()
	var sp := Vector2(p.vel.x, p.vel.z).length()
	a_v.ok(
		"jug X keeps momentum: the run carries into the guard",
		absf(sp - 6.0 * float(xd["carry_k"])) < 0.1,
		"before %s after %s" % [k.riposte.vel_before, k.riposte.vel_after]
	)
	var p0 := p.pos
	a_v.step(m, 0.1)
	a_v.ok(
		"jug X keeps momentum: still moving 0.1s into the guard",
		Vector2(p.vel.x, p.vel.z).length() > 1.0 and p.pos.x - p0.x > 0.2,
		"moved %.2f" % (p.pos.x - p0.x)
	)
	k.riposte.drop()
	# E in the guard: the pull takes his motion over from the carry
	_fresh()
	_hook(home + Vector3(8.0, 0, 0))
	p.vel = Vector3(0, 0, 6.0)
	k.riposte.start()
	k.use_e()
	a_v.ok(
		"jug X: E in the guard pulls him in, the carry handed to the pull",
		k.warchain.pulling() and k.riposte.st.get("carry", Vector2.ONE) == Vector2.ZERO
	)


## His height off a jump at its top, `ult`: cast three steps into it (still rising fast).
func _jump_peak(ult: bool) -> float:
	_fresh()
	var y0 := p.pos.y
	p.inp["jump"] = true
	m.step(a_v.DT)
	p.inp["jump"] = false
	a_v.step(m, a_v.DT * 2.0)
	if ult:
		k.riposte.start()
	var peak := y0
	for i in 50:
		m.step(a_v.DT)
		peak = maxf(peak, p.pos.y)
	k.riposte.drop()
	return peak - y0


## Cast rising, the lift takes him higher than the plain jump; cast in a ledge rise (up a two-terrace block
## carved on the strip), the rise hands over to the lift instead of rewriting his climb.
func ult_rise() -> void:
	var xd := k.x_def()
	var plain := _jump_peak(false)
	var lifted := _jump_peak(true)
	a_v.ok(
		"jug X keeps momentum: cast rising from a jump, the lift takes him higher",
		lifted - plain > 0.3,
		"peak %.2f m, the plain jump's %.2f" % [lifted, plain]
	)
	var w: World = m.world
	var x0 := int(floor(home.x))
	var z0 := int(floor(home.z))
	var lv := int(w.level[w.idx(x0, z0)])
	var carved := []
	for dz in range(-2, 3):
		for dx in range(3, 6):
			var ci := w.idx(x0 + dx, z0 + dz)
			carved.append([ci, w.level[ci]])
			w.level[ci] = lv + 2
	_fresh()
	p.teleport(Vector3(x0 + 3.0 - p.r - 0.6, home.y, home.z))  # (move_feel_check's start off the face)
	var climbing := false
	for i in 60:
		p.inp["move"] = Vector2(1, 0)
		p.inp["jump"] = i == 2
		m.step(a_v.DT)
		climbing = not p.lfloat.is_empty() and p.vel.y >= float(xd["rise_min"])
		if climbing:
			break
	p.inp["move"] = Vector2.ZERO
	p.inp["jump"] = false
	var y0 := p.pos.y
	k.riposte.start()
	a_v.step(m, 0.15)
	a_v.ok(
		"jug X mid-mantle: the ledge rise hands over to the lift",
		climbing and p.lfloat.is_empty() and p.pos.y - y0 > 0.3,
		"climbing %s, rose %.2f vy %.2f" % [climbing, p.pos.y - y0, p.vel.y]
	)
	k.riposte.drop()
	for c in carved:
		w.level[c[0]] = c[1]


## The chain hooked 20 m off: a Lunge sideways stays inside 24 m and keeps it; one backward carries him past
## the length and breaks it: no clamp, no snap back. Walking back holds taut (zedran_feel_check).
func tether_break() -> void:
	_fresh()
	_hook(home + Vector3(6.0, 0, 0))
	t.teleport(home + Vector3(20.0, 0, 0))
	a_v.aim_at(p, home + Vector3(0, 0, -6.0))
	k._lunge(1.0, false)
	a_v.step(m, 0.4)
	var kept := k.warchain.hooked()
	k.lunge = {}
	p.vel = Vector3.ZERO
	var b0 := k.warchain.breaks
	a_v.ok("jug item 11: a Lunge sideways within the chain's length keeps it", kept, "dist %.1f" % p.flat_dist(t))
	a_v.aim_at(p, p.pos + Vector3(-6.0, 0, 0))
	k._lunge(1.0, false)
	a_v.step(m, 0.6)
	a_v.ok(
		"jug item 11: a Lunge backward past the chain's length breaks it",
		not k.warchain.hooked() and k.warchain.breaks == b0 + 1,
		"breaks %d dist %.1f" % [k.warchain.breaks - b0, p.flat_dist(t)]
	)
