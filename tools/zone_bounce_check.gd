extends "res://tools/archetype_check.gd"
## --zone-bounce-check (briefs/STATE_MACHINES.md bug 3.5): a Hunter standing in a zone that ticks a slow stays
## on the ground. Every slow zone in turn (Lace's Hail Wall, Vex's Cinderfall patch, Cinder's lava trail,
## Albert's fissure scar, Neve's Ice Spear field and Rimelock rink) is cast on a still Hunter, and every frame
## it stands in it is read: grounded stays true, no landing fires (a ground touch after leaving it, land_t)
## and vel.y never goes up.
## A real knock-up (a lift above 0) still launches. Prints AKCHECK lines.

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("zone_bounce_check", self)
	await _hail_wall()
	await _cinderfall()
	await _cinder_trail()
	await _scar()
	await _neve()
	await _rows()
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Steps `secs` and reads T every frame: {air: frames off the ground, land: landings, up: max vel.y, slowed}.
func _watch(m: Match, T: Hunter, secs: float, each := Callable()) -> Dictionary:
	var out := {"air": 0, "land": 0, "up": 0.0, "slowed": false}
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		var was := T.grounded
		m.step(DT)
		t += DT
		if not T.grounded: out["air"] = int(out["air"]) + 1
		if T.grounded and not was: out["land"] = int(out["land"]) + 1
		if T.land_t > 0.0: out["land"] = int(out["land"]) + 1
		out["up"] = maxf(float(out["up"]), T.vel.y)
		if T.slow_t > 0.0: out["slowed"] = true
	return out

## Puts T at `at` (fresh, still) and lets it settle on the ground first.
func _stand(m: Match, T: Hunter, at: Vector3) -> void:
	m.hunters.erase(T)      # T moves first in a step, so a zone hit later in the step shows next frame
	m.hunters.push_front(T)
	fresh(T)
	T.teleport(at)
	T.inp["move"] = Vector2.ZERO
	step(m, 0.15)

func _still(T: Hunter, r: Dictionary, what: String) -> void:
	ok("zone bounce: %s slows" % what, bool(r["slowed"]))
	var still := int(r["air"]) == 0 and int(r["land"]) == 0 and float(r["up"]) <= 0.01
	ok("zone bounce: %s keeps the Hunter grounded" % what, still,
		"air %d frames, landings %d, up %.2f" % [r["air"], r["land"], r["up"]])

func _hail_wall() -> void:
	var r := setup("archer", 5.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K = P.ak
	aim_at(P, home + Vector3(5.0, 0, 0))
	_stand(m, T, home + Vector3(5.0, 0, 0))
	K.cd["e"] = 0.0
	K.use_e()
	_still(T, _watch(m, T, 2.4), "Lace's Hail Wall")
	# a hero walking through it (another body class, its own kit)
	T.set_arch("juggernaut")
	_stand(m, T, home + Vector3(5.0, 0, -2.0))
	K.cd["e"] = 0.0
	K.use_e()
	_still(T, _watch(m, T, 2.4, func(): T.inp["move"] = Vector2(0, 0.6)), "Lace's Hail Wall walked through")
	T.inp["move"] = Vector2.ZERO
	await done(m)

func _cinderfall() -> void:
	var r := setup("gunslinger", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: GunslingerKit = P.ak
	var at := home + Vector3(6.0, 0, 0)
	aim_at(P, at)
	HunterKeys.ult_pressed(P)
	step(m, float(K.x_def()["delay"]) + 0.3)      # the shell lands (its own blast is a real knock)
	_stand(m, T, at)
	_still(T, _watch(m, T, 1.5), "Vex's Cinderfall patch")
	await done(m)

func _cinder_trail() -> void:
	var r := setup("ashwick", 16.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: AshwickKit = P.ak
	T.teleport(home + Vector3(0, 0, 9.0))
	aim_at(P, home + Vector3(16, 0, 0))
	HunterKeys.ult_pressed(P)
	step(m, 1.2, func(): aim_at(P, home + Vector3(16, 0, 0)))
	var spot: Vector3 = K.jet.trail[0]["b"] if not K.jet.trail.is_empty() else home
	_stand(m, T, spot)
	_still(T, _watch(m, T, 1.5, func(): aim_at(P, home + Vector3(16, 0, 0))), "Cinder's lava trail")
	await done(m)

func _scar() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	T.teleport(home + Vector3(0, 0, 9.0))
	aim_at(P, home + Vector3(7.0, 0, 0))
	HunterKeys.ult_pressed(P)
	step(m, 1.5)
	ok("zone bounce: Albert's Faultline leaves its scar", not K.ult.scar.is_empty())
	_stand(m, T, home + Vector3(5.0, 0, 0))
	_still(T, _watch(m, T, 1.5), "Albert's Faultline scar")
	await done(m)

func _neve() -> void:
	var r := setup("rimewright", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: RimewrightKit = P.ak
	T.teleport(home + Vector3(0, 0, 9.0))
	aim_at(P, home + Vector3(6.0, 0, 0))
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.3)
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	var t := 0.0
	while K.zones.is_empty() and t < 2.0:
		m.step(DT)
		t += DT
	var at: Vector3 = K.zones[0]["at"] if not K.zones.is_empty() else home
	_stand(m, T, at)
	_still(T, _watch(m, T, 1.2), "Neve's Ice Spear field")
	step(m, 1.5)
	_stand(m, T, home + Vector3(2.5, 0, 0))
	HunterKeys.ult_pressed(P)
	_still(T, _watch(m, T, 3.0), "Neve's Rimelock rink")
	await done(m)

## The source: a slow row that carries "lift": 0.0 (and a pull's 0.0) is no launch; a real knock-up still is.
func _rows() -> void:
	var r := setup("archer", 4.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var at: Vector3 = T.pos
	_stand(m, T, at)
	var slow_row := {"src": "abil", "kb": Vector2.ZERO, "lift": 0.0, "slow": 0.8, "slow_k": 0.3}
	_still(T, _watch(m, T, 1.0, func(): T.hurt(1.0, P, slow_row)), "a slow row with lift 0")
	_stand(m, T, at)
	var tug := {"src": "hazard", "kb": Vector2(0.0, 3.2), "lift": 0.0, "slow": 0.3}
	var pull := _watch(m, T, 1.0, func(): T.hurt(0.1, null, tug))
	_still(T, pull, "a zone pull with lift 0")
	for row in [{"kb": Vector2(6, 0), "lift": 4.0}, {"lift": 5.0}]:
		_stand(m, T, at)
		T.hurt(1.0, P, row.merged({"src": "abil"}))
		ok("zone bounce: a real knock-up still launches %s" % str(row), not T.grounded and T.vel.y > 3.0,
			"grounded %s vy %.1f" % [T.grounded, T.vel.y])
		step(m, 1.5)
	await done(m)
