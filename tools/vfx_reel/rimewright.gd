extends "res://tools/hero_vfx_reel.gd"
## Claire's reel (tools/hero_vfx_reel.gd): the darts held, the skate carving its frost trail with beams, the spear
## through its landing and detonation, the Rink Wall frozen, and Rimelock to its crash.

func parts() -> Array:
	return ["lmb", "hold", "dash", "rmb", "e", "r"]

func _part_lmb() -> void:
	await _reset(6.0)
	var darts := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 1.6
		_aim(T.pos)
	await _go(2.0, darts, _sheet("lmb", "LMB held: darts with icy trails, chill and the frost on the foe",
		[0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.3, 1.6, 1.9], func(): return (P.pos + T.pos) * 0.5), 2.0)
	await _go(GAP)

func _part_dash() -> void:
	await _reset(6.0)
	var skate := func(t: float):
		P.inp["dash"] = _at(t, 0.1)
		P.inp["dash_down"] = t > 0.1 and t < 1.5
		P.inp["move"] = Vector2(1, 0) if t < 0.6 else Vector2(0, 1)
		P.inp["fire"] = t > 0.7 and t < 1.2
		_aim(T.pos)
	await _go(2.4, skate, _sheet("dash", "Shift: the skate's frost trail, a carve, beams, the stop, the frost melting",
		[0.2, 0.4, 0.6, 0.8, 1.0, 1.3, 1.6, 1.9, 2.3]), 1.0)
	await _go(GAP)

func _part_rmb() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 0.5
		_aim(T.pos)
	await _go(3.2, cast, _sheet("rmb", "RMB: the gather, the push, the spear's trail, the landing, the detonation",
		[0.3, 0.55, 0.65, 0.8, 1.0, 1.4, 2.6, 2.75, 3.1], func(): return T.pos), 3.0)
	await _go(GAP)

func _part_e() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		if _at(t, 0.9):
			P.ak.e_recast()
		_aim(T.pos)
	await _go(2.0, cast, _sheet("e", "E: the tell at her feet, the wall rising, E again: the freeze",
		[0.15, 0.3, 0.45, 0.6, 0.8, 0.95, 1.1, 1.4, 1.8], func(): return (P.pos + T.pos) * 0.5), 2.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(4.0)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(T.pos)
	await _go(4.2, cast, _sheet("r", "R, Rimelock: the seal, the cold held round her, the crash and its frost",
		[0.15, 0.3, 0.6, 1.2, 2.4, 3.55, 3.7, 3.9, 4.15]), 1.5)
	await _go(GAP)
