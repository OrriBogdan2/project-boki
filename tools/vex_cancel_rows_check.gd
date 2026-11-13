extends RefCounted
## Vex's Cancels table (docs/heroes/gunslinger.md, "Cancels"), one assert per row the 11-09 pass left unsettled.
## No data, frame or wiki line shows these pairs, so each follows DECISIONS "every interaction is chainable" and
## DashFlow's default (a missing row combines): the second press goes now and the first runs on. Run inside
## --gunslinger-combo-check through tools/venator_parity_check.gd.
const MAG := 30              # rounds in the drum
const RECOIL_S := 0.4         # s the beam's recoil shove keeps the glider shut (Hunter: a shove waits 0.4 s)
const LIFT := 4.0            # m she is lifted before opening a glider, so it stays open through a row
var C                        # the combo check (ok, ac, helpers)
var m: Match
var P: Hunter
var K: GunslingerKit
var T: Hunter
var home: Vector3


func _init(check) -> void:
	C = check


func run(match_: Match, p: Hunter, k: GunslingerKit, t: Hunter, at: Vector3) -> void:
	m = match_
	P = p
	K = k
	T = t
	home = at
	P.lvl = maxi(P.lvl, int(Hunter.ULT_AT[0]))
	_needle_rows()
	_needle_recovery()
	_ult_then()
	_string_rows()
	_glide_rows()
	P.inp["fire"] = false
	P.inp["glide"] = false
	C.ac.step(m, 1.0)


## Back on her spot with every slot ready and the dummy on the line 8 m east.
func _ready_all() -> void:
	P.inp["fire"] = false
	P.inp["glide"] = false
	P.gliding = false
	C.ac.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(8.0, 0, 0))
	C.ac.step(m, 0.6)
	T.inv_t = 0.0
	C.ac.aim_at(P, T.pos)
	P.ammo = MAG
	P.fire_cd = 0.0
	for sl in ["rmb", "e", "x"]:
		K.cd[sl] = 0.0
	K.ch_rmb = 1.0


## Runs `second` 0.2 s into the Longneedle's charge; true when the charge was still on then and the beam fired.
func _in_charge(second: Callable) -> bool:
	_ready_all()
	K.needle_dir = Vector2.ZERO
	K.use_e()
	C.ac.step(m, 0.2)
	var charging := not K.needle.is_empty()
	second.call()
	C.ac.step(m, 0.6)
	return charging and K.needle.is_empty() and K.needle_dir != Vector2.ZERO


func _needle_rows() -> void:
	var n := {"shots": 0, "burrs": 0, "air": false, "ult": 0, "glide": false}
	var beam := _in_charge(func():
		var s0 := P.shot_n
		P.inp["fire"] = true
		C.ac.step(m, 0.3)
		P.inp["fire"] = false
		n["shots"] = P.shot_n - s0)
	C.ok("Vex cancel E wind-up + LMB: both (rule), rounds leave in the charge and the beam goes",
			beam and int(n["shots"]) >= 2, "%d rounds, beam %s" % [n["shots"], beam])
	beam = _in_charge(func():
		var b0 := K.burrs.size()
		K.press_rmb()
		n["burrs"] = K.burrs.size() - b0)
	C.ok("Vex cancel E wind-up + RMB: both (rule), the Burr Charge leaves and the beam goes",
			beam and int(n["burrs"]) == 1, "burrs %d, beam %s" % [n["burrs"], beam])
	beam = _in_charge(func():
		P.do_jump()
		C.ac.step(m, 0.1)
		n["air"] = not P.grounded and not K.needle.is_empty())
	C.ok("Vex cancel E wind-up + jump: both (rule), she hops and the charge goes on", beam and bool(n["air"]))
	beam = _in_charge(func():
		var u0 := K.ult.casts
		HunterKeys.ult_pressed(P)
		n["ult"] = K.ult.casts - u0)
	C.ok("Vex cancel E wind-up + X: both (rule; was ignored), Cinderfall goes and the beam goes",
			beam and int(n["ult"]) == 1, "casts %d, beam %s" % [n["ult"], beam])
	beam = _in_charge(func():
		P.do_jump()
		C.ac.step(m, 0.08)
		P.pos.y += LIFT
		P.inp["glide"] = true
		P.do_jump()
		C.ac.step(m, 0.05)
		n["glide"] = not P.gliding and not K.needle.is_empty()
		while not K.needle.is_empty():
			n["glide"] = bool(n["glide"]) and not P.gliding
			m.step(C.DT)
		n["open"] = -1.0
		for i in int(0.6 / C.DT):
			m.step(C.DT)
			if P.gliding and float(n["open"]) < 0.0:
				n["open"] = (i + 1) * C.DT)
	var open_at := float(n["open"])
	P.inp["glide"] = false
	C.ok("Vex cancel E wind-up + glide: waits, as owner 162b asks: shut in the charge, held it opens after the recoil",
			beam and bool(n["glide"]) and open_at >= 0.0 and open_at <= RECOIL_S + 0.1,
			"shut %s, open %.2f s after the beam" % [n["glide"], open_at])


## The cast ends at the beam: the very next step takes a jump, a Burr Charge and a round.
func _needle_recovery() -> void:
	_ready_all()
	K.use_e()
	var t := 0.0
	while not K.needle.is_empty() and t < 1.0:
		m.step(C.DT)
		t += C.DT
	var s0 := P.shot_n
	var b0 := K.burrs.size()
	P.do_jump()
	K.press_rmb()
	P.inp["fire"] = true
	C.ac.step(m, 0.1)
	P.inp["fire"] = false
	var went := not P.grounded and K.burrs.size() > b0 and P.shot_n > s0
	C.ok("Vex cancel E recovery + any: no lock, as owner item 51 asks: jump, RMB, LMB go within 0.1 s of the beam",
			K.needle.is_empty() and went, "air %s burrs +%d rounds +%d" % [not P.grounded, K.burrs.size() - b0,
			P.shot_n - s0])


func _ult_then() -> void:
	_ready_all()
	var u0 := K.ult.casts
	HunterKeys.ult_pressed(P)
	var b0 := K.burrs.size()
	K.press_rmb()
	K.use_e()
	var both := K.ult.casts > u0 and K.burrs.size() > b0 and not K.needle.is_empty()
	C.ac.step(m, 1.0)
	C.ok("Vex cancel X + E, RMB: both (rule), the Burr Charge and the Longneedle go with the shell falling", both)


## The held string goes on through each press: rounds keep leaving in the 0.3 s after it.
func _string_rows() -> void:
	_ready_all()
	P.inp["fire"] = true
	C.ac.step(m, 0.3)
	var gaps := []
	var presses := [func(): K.press_rmb(), func(): K.use_e(), func(): HunterKeys.ult_pressed(P)]
	var went := []
	for press in presses:
		var s0 := P.shot_n
		var before := [K.burrs.size(), K.needle.is_empty(), K.ult.casts]
		press.call()
		went.append(K.burrs.size() > int(before[0]) or (bool(before[1]) and not K.needle.is_empty())
				or K.ult.casts > int(before[2]))
		C.ac.step(m, 0.3, func(): P.ammo = MAG)
		gaps.append(P.shot_n - s0)
	C.ac.step(m, 0.7)
	C.ok("Vex cancel LMB held + RMB, E, X: both (rule), each goes and the string goes on",
			went.all(func(w: bool) -> bool: return w) and gaps.all(func(g: int) -> bool: return g >= 2),
			"went %s, rounds %s" % [str(went), str(gaps)])
	var s1 := P.shot_n
	P.do_jump()
	var air := false
	for i in int(0.3 / C.DT):
		m.step(C.DT)
		air = air or not P.grounded
	P.inp["fire"] = false
	C.ok("Vex cancel LMB held + jump: both (rule), the string goes on through the hop",
			air and P.shot_n - s1 >= 2, "%d rounds" % (P.shot_n - s1))


## Opens a glider 4 m up and holds it open.
func _open_glide() -> void:
	_ready_all()
	P.do_jump()
	C.ac.step(m, 0.08)
	P.pos.y += LIFT
	P.inp["glide"] = true
	P.do_jump()
	C.ac.step(m, 0.05)


func _glide_rows() -> void:
	_open_glide()
	var s0 := P.shot_n
	P.inp["fire"] = true
	C.ac.step(m, 0.3)
	P.inp["fire"] = false
	C.ok("Vex cancel glide + LMB: both (rule; was ignored), the rifle fires and the glider stays open",
			P.gliding and P.shot_n - s0 >= 2, "%d rounds, gliding %s" % [P.shot_n - s0, P.gliding])
	_open_glide()
	var b0 := K.burrs.size()
	var air_variant := K.air_rmb()
	K.press_rmb()
	var rmb := K.burrs.size() > b0 and air_variant
	_open_glide()
	K.use_e()
	var e := not K.needle.is_empty()
	C.ac.step(m, 0.8)
	_open_glide()
	var u0 := K.ult.casts
	HunterKeys.ult_pressed(P)
	var x := K.ult.casts > u0
	C.ok("Vex cancel glide + RMB, E, X: both (rule), each goes from the glide (RMB as its air variant)",
			rmb and e and x, "RMB %s E %s X %s" % [rmb, e, x])
