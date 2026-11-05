extends "res://tools/hero_vfx_reel.gd"
## Breaker's reel (--hero-vfx-reel --reel-hero=bulwark): the throw and recall, the held Crushing Blow to its
## release, the aegis blocking and breaking, the 360 Smash, the armed Shield Charge into a Shield Slam, Mending
## Ground through its burst, and Faultline's sea path to its scar.

## Engine.time_scale while the reel runs: a software frame takes about half a second, so at this scale the
## looks (on process time) advance about one match step per frame, as the match itself does here.
const SLOW := 0.033

func parts() -> Array:
	return ["throw", "hold", "aegis", "dash", "charge", "e", "r"]

func run(main_node: Node) -> void:
	Engine.time_scale = SLOW
	await super.run(main_node)

func _part_throw() -> void:
	await _reset(6.0)
	var throw := func(t: float):
		P.inp["fire"] = _at(t, 0.1) or _at(t, 1.3)
		_aim(T.pos)
	await _go(2.2, throw, _sheet("throw", "LMB tap: the throw, planted, the recall, the catch",
		[0.2, 0.3, 0.45, 0.7, 1.1, 1.35, 1.45, 1.6, 1.9]), 3.0)
	await _go(GAP)

func _part_hold() -> void:
	await _reset(3.0)
	var hold := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 1.62
		_aim(T.pos)
	await _go(2.6, hold, _sheet("hold", "LMB hold: the charge, the lure at full, the Crushing Blow",
		[0.5, 0.9, 1.3, 1.5, 1.64, 1.7, 1.8, 2.0, 2.4]), 1.5)
	await _go(GAP)

func _part_aegis() -> void:
	await _reset(4.0)
	var K: BulwarkKit = P.ak
	var guard := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 2.4
		if _at(t, 0.8) or _at(t, 1.2):
			K.on_block(30.0, T)
		if _at(t, 1.7) and not K.wall.is_empty():
			m.verbs.walls.erase(K.wall)          # broken
		_aim(T.pos)
	await _go(2.6, guard, _sheet("aegis", "RMB: the aegis rises, blocks twice, breaks",
		[0.2, 0.35, 0.82, 0.9, 1.22, 1.3, 1.72, 1.8, 2.1]), 2.0)
	await _go(GAP)

func _part_charge() -> void:
	await _reset(5.0)
	var K: BulwarkKit = P.ak
	K.res = 60.0
	var charge := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 1.2
		if _at(t, 0.4):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		_aim(T.pos)
	await _go(1.8, charge, _sheet("charge", "Shift with the aegis up and Guard armed: Shield Charge, Shield Slam",
		[0.42, 0.5, 0.58, 0.66, 0.72, 0.8, 0.95, 1.2, 1.6]), 2.5)
	await _go(GAP)

func _part_e() -> void:
	await _reset(4.0)
	P.hp = P.max_hp * 0.5
	var mend := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		_aim(T.pos)
	await _go(5.6, mend, _sheet("e", "E: Mending Ground on him (the column, the zone, the burst)",
		[0.2, 0.6, 1.0, 1.15, 1.6, 2.6, 5.1, 5.2, 5.4]), 0.0)
	await _go(GAP)

func _part_r() -> void:
	await _reset(8.0)
	var ult := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(T.pos)
	await _go(4.2, ult, _sheet("r", "R, Faultline: the lure, the slam, the sea path, the vortex, the wet scar",
		[0.2, 0.45, 0.55, 0.7, 0.85, 1.0, 1.4, 2.4, 4.0], func(): return P.pos + Vector3(7.0, 0.5, 0)), 7.0)
	await _go(GAP)
