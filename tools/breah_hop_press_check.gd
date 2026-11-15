extends "res://tools/hero_pair_check.gd"
## Rock Hop's presses, for --dolm-combo-check (docs/heroes/dolm.md "Rock Hop"): every Shift press goes through
## Hunter.do_dash as a real one-step input, at each point of a chain. A press from the first rock's crouch to the
## window's last step is the next hop (a press in the flight waits for the landing), and it leaves the skid
## running; a press in the last hop's final BUFFER_S, or after the window, is a fresh chain only with a charge up.
## The SHIFT AGAIN prompt is up exactly while a press is the next hop, and its time left is the chain's.

var m: Match
var P: Hunter
var K: DolmKit
var home: Vector3

func presses(main_node: Node) -> void:
	main = main_node
	var r := setup("dolm", 30.0)
	m = r[0]
	P = r[1]
	home = r[3]
	K = P.ak
	_in_window()
	_late_presses()
	_prompt()
	m.queue_free()

func _reset() -> void:
	K.hop.drop()
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.roll_t = 0.0
	P.dashes = P.max_dashes()
	aim_at(P, home + Vector3(30.0, 0, 0))
	step(m, float(K.hop.dd()["hop_rock_t"]) + 0.1)      # the last chain's rocks gone

## One step with Shift pressed, as the keys give it.
func _tap() -> void:
	P.inp["dash"] = true
	m.step(DT)
	P.inp["dash"] = false

func _phase() -> String:
	return String(K.hop.st.get("phase", "")) if K.hop.chaining() else ""

## Steps until `done` holds (at most 2s).
func _until(done: Callable) -> void:
	for _s in 120:
		if done.call():
			return
		m.step(DT)

func _chain_end() -> void:
	_until(func(): return not K.hop.chaining())

## A press at each point of the window is the next hop.
## In hop n's flight, its landing less than BUFFER_S away.
func _near_landing(n_at: int) -> bool:
	var to_land := K.hop._flight() - float(K.hop.st.get("t", 0.0))
	return _phase() == "air" and int(K.hop.st["n"]) == n_at and to_land < DashFlow.BUFFER_S - DT

func _in_window() -> void:
	var cases := {
		"in the first rock's crouch": func(): pass,
		"just after the take-off": func(): _until(func(): return _phase() == "air"),
		"in the last BUFFER_S before the landing": func(): _until(_near_landing.bind(1)),
		"on the landing, before skid_min": func(): _until(func(): return _phase() == "skid"),
		"on the window's last step": func(): _until(func(): return _phase() == "skid" and K.hop.left() <= DT * 1.5),
	}
	for what in cases:
		_reset()
		_tap()
		cases[what].call()
		_tap()
		var skid_on := _phase() != "skid" or P.roll_t > 0.0
		_chain_end()
		ok("hop press %s: the next hop" % what, K.hop.chain_hops == 2 and skid_on,
			"hops %d skid on %s" % [K.hop.chain_hops, str(skid_on)])

## A chain pressed on to its last hop, just taken off.
func _to_last_flight() -> void:
	_reset()
	_tap()
	for n_at in [1, 2]:
		_until(func(): return _phase() == "skid" and int(K.hop.st["n"]) == n_at)
		_tap()
	_until(func(): return _phase() == "air" and int(K.hop.st["n"]) == 3)

## The last hop's final BUFFER_S and the time after the window: a fresh chain with a charge up, nothing without.
func _late_presses() -> void:
	for charge in [1.0, 0.0]:
		_to_last_flight()
		_until(_near_landing.bind(3))
		P.dashes = charge
		var hops0 := K.hop.hops
		_tap()
		step(m, 0.45)
		var fresh := K.hop.hops > hops0
		var want := "a fresh chain" if charge else "none"
		ok("hop press in the last hop's final BUFFER_S, charge %d: %s" % [charge, want],
			fresh == (charge > 0.0) and P.dashes < maxf(charge, 0.5), "fresh %s dashes %.2f" % [str(fresh), P.dashes])
	_to_last_flight()
	P.dashes = 1.0
	_tap()
	_chain_end()
	step(m, 0.3)
	ok("hop press early in the last hop's flight: no fresh chain (not a double)",
		P.dashes >= 1.0 and not K.hop.chaining(), "dashes %.2f" % P.dashes)
	for charge in [1.0, 0.0]:
		_reset()
		_tap()
		_chain_end()
		P.dashes = charge
		_tap()
		step(m, 0.1)
		var fresh := K.hop.chaining()
		ok("hop press after the window, charge %d: %s" % [charge, "a fresh chain" if charge else "none"],
			fresh == (charge > 0.0) and P.dashes < maxf(charge, 0.5), "fresh %s dashes %.2f" % [str(fresh), P.dashes])

## SHIFT AGAIN: up from the press while hops are left, its time left the chain's to the step, gone as it ends.
func _prompt() -> void:
	_reset()
	_tap()
	var shown := 0
	var bad := 0
	var last_left := 1e9
	while K.hop.chaining():
		var w := K.recast_window()
		var open := int(K.hop.st["n"]) < int(K.hop.dd()["hops"])
		if w.is_empty() == open:
			bad += 1
		elif open:
			shown += 1
			var left := float(w["left"])
			if absf(left - K.hop.left()) > 1e-4 or left > last_left + 1e-4 or left < -1e-4:
				bad += 1
			last_left = left
		m.step(DT)
	var span := shown * DT
	var want := K.hop.CROUCH + float(K.hop.dd()["window"])
	ok("hop prompt: SHIFT AGAIN for exactly the crouch and the window, its time left the chain's",
		bad == 0 and absf(span - want) <= DT * 1.5 and last_left <= DT * 1.5,
		"up %.3fs want %.3f last %.3f bad %d" % [span, want, last_left, bad])
