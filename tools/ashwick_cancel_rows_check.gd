extends RefCounted
## Cinder's Cancels table (docs/heroes/ashwick.md, "Cancels"), one assert per row the 11-09 pass left unsettled.
## No data, frame or wiki line shows these pairs. The flight rows follow the owner (DECISIONS Nov 5: in Flue Flight
## only E works); the rest follow DECISIONS 11-07 "every interaction is chainable": the second press goes now and
## the first runs on. Run inside --ashwick-combo-check.
const LIFT := 4.0            # m he is lifted before opening a glider, so it stays open through a row
const IN_FLARE := 0.1        # s into the cloak's 0.24 s arms-out flare (as_cloak) the second press comes
const LIGHT := 0.4           # s of held LMB: the 0.2 s pilot, then the roar
var ak                       # the archetype check (setup, step, aim_at)
var ok_fn: Callable
var m: Match
var P: Hunter
var K: AshwickKit
var T: Hunter
var home: Vector3


func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb


func run() -> void:
	var r: Array = ak.setup("ashwick", 8.0)
	m = r[0]
	P = r[1]
	T = r[2]
	home = r[4]
	K = P.ak
	_lance_rows()
	_shot_row()
	_cloak_row()
	_flight_rows()
	_glide_rows()
	_ready_all()


## Back on his spot, every slot ready, no flight, glider or hose, the dummy 8 m east.
func _ready_all() -> void:
	P.inp["fire"] = false
	P.inp["glide"] = false
	P.inp["glide_btn"] = false
	if K.jet.running():
		K.jet.drop()
	P.gliding = false
	P.teleport(home)
	T.teleport(home + Vector3(8.0, 0, 0))
	ak.step(m, 0.6)
	ak.aim_at(P, T.pos)
	for sl in ["rmb", "e", "x"]:
		K.cd[sl] = 0.0
	K.ch_rmb = float(K.rmb_charges())
	K.relight_t = 0.0


func _hold_fire() -> void:
	P.inp["fire"] = true
	ak.aim_at(P, T.pos)


## A tap of RMB (pressed, let go the next step); true when a charge was spent on it.
func _tap_rmb() -> bool:
	var ch := K.ch_rmb
	K.press_rmb()
	m.step(ak.DT)
	return K.ch_rmb < ch


func _lance_rows() -> void:
	_ready_all()
	ak.step(m, LIGHT, _hold_fire)
	var e0: int = K.hose.emitted
	var bolt := _tap_rmb()
	ak.step(m, 0.2, _hold_fire)
	ok_fn.call("Cinder cancel LMB held + RMB: both (rule), the bolt leaves and the hose keeps burning",
			bolt and K.was_held and K.hose.emitted > e0 + 4, "bolt %s, puffs +%d" % [bolt, K.hose.emitted - e0])
	var c0 := K.cloaks
	e0 = K.hose.emitted
	K.use_e()
	ak.step(m, 0.2, _hold_fire)
	ok_fn.call("Cinder cancel LMB held + E: both (rule), the cloak blasts and the hose keeps burning",
			K.cloaks == c0 + 1 and K.was_held and K.hose.emitted > e0 + 4, "cloaks +%d" % (K.cloaks - c0))
	var f0 := K.jet.flights
	HunterKeys.ult_pressed(P)
	ak.step(m, 0.05, _hold_fire)
	e0 = K.hose.emitted
	ak.step(m, 0.3, _hold_fire)
	ok_fn.call("Cinder cancel LMB held + X: the flight goes at once (rule), the hose goes out for it [O] Nov 5",
			K.jet.flights == f0 + 1 and K.jet.running() and not K.was_held and K.hose.emitted == e0,
			"flights +%d, puffs +%d" % [K.jet.flights - f0, K.hose.emitted - e0])


## RMB, then LMB and E the very next step: the hose lights and the cloak blasts.
func _shot_row() -> void:
	_ready_all()
	var bolt := _tap_rmb()
	var c0 := K.cloaks
	K.use_e()
	m.step(ak.DT)
	_hold_fire()
	m.step(ak.DT)
	ok_fn.call("Cinder cancel RMB + LMB, E: both (rule), the lance lights and the cloak blasts at once",
			bolt and K.cloaks == c0 + 1 and K.was_held,
			"bolt %s, cloaks +%d, lance %s" % [bolt, K.cloaks - c0, K.was_held])


## Inside the cloak's flare (no 0.2 s ring: owner item 11), LMB, RMB and X each go the step they are pressed.
func _cloak_row() -> void:
	var went := []
	for second in ["lmb", "rmb", "x"]:
		_ready_all()
		K.use_e()
		ak.step(m, IN_FLARE)
		var flaring := K.anim_id == "as_cloak"
		var f0 := K.jet.flights
		var hit := false
		match second:
			"lmb":
				_hold_fire()
				m.step(ak.DT)
				hit = K.was_held
			"rmb":
				hit = _tap_rmb()
			"x":
				HunterKeys.ult_pressed(P)
				hit = K.jet.flights == f0 + 1
		went.append(flaring and hit)
	ok_fn.call("Cinder cancel E flare + LMB, RMB, X: both [O] item 11 no ring wait, rule, each goes at once",
			went.all(func(w: bool) -> bool: return w), "lmb, rmb, x %s" % str(went))


## Owner Nov 5: in Flue Flight only E works. LMB is ignored (a deny tick) and the glider stays shut.
func _flight_rows() -> void:
	_ready_all()
	HunterKeys.ult_pressed(P)
	ak.step(m, 0.1)
	var d0 := K.lmb_denied
	var e0: int = K.hose.emitted
	ak.step(m, 0.3, _hold_fire)
	P.inp["fire"] = false
	ok_fn.call("Cinder cancel X flight + LMB: ignored [O] Nov 5, a deny tick, no flame, the flight goes on",
			K.jet.running() and K.lmb_denied == d0 + 1 and K.hose.emitted == e0, "denied +%d" % (K.lmb_denied - d0))
	var shut := true
	for i in int(0.3 / ak.DT):
		P.inp["glide"] = true
		P.inp["glide_btn"] = i % 2 == 0
		m.step(ak.DT)
		shut = shut and not P.gliding
	ok_fn.call("Cinder cancel X flight + glide: ignored [O] Nov 5, the glider stays shut, the flight goes on",
			shut and K.jet.running())


## Opens a glider 4 m up and holds it open.
func _open_glide() -> void:
	_ready_all()
	P.do_jump()
	ak.step(m, 0.08)
	P.pos.y += LIFT
	P.inp["glide"] = true
	P.do_jump()
	ak.step(m, 0.05)


func _glide_rows() -> void:
	_open_glide()
	var e0: int = K.hose.emitted
	ak.step(m, LIGHT, _hold_fire)
	P.inp["fire"] = false
	ok_fn.call("Cinder cancel glide + LMB: both (rule; was ignored), the hose roars and the glider stays open",
			P.gliding and K.hose.emitted > e0 + 4, "puffs +%d, gliding %s" % [K.hose.emitted - e0, P.gliding])
	_open_glide()
	var rmb := _tap_rmb()
	_open_glide()
	var c0 := K.cloaks
	K.use_e()
	var e := K.cloaks == c0 + 1
	_open_glide()
	var f0 := K.jet.flights
	HunterKeys.ult_pressed(P)
	var x := K.jet.flights == f0 + 1
	ok_fn.call("Cinder cancel glide + RMB, E, X: both (rule), each goes from the glide",
			rmb and e and x, "RMB %s E %s X %s" % [rmb, e, x])
