extends "res://tools/hero_vfx_reel.gd"
## Gil's reel (tools/hero_vfx_reel.gd): the three swordfish thrusts, each potion of the Grab Bag bursting on the
## dummy (one sheet per potion), the Ground Swim's fin and its surfacing, Riptide's spin to its waterspout, and the
## Tidal Wave ridden to its landing.

const POTIONS := ["thunder", "slime", "air", "fire", "zeep"]

func parts() -> Array:
	return ["lmb", "rmb", "dash", "e", "r"]

func _part_lmb() -> void:
	await _reset(3.0)
	var thrusts := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 1.0
		_aim(T.pos)
	await _go(1.6, thrusts, _sheet("lmb", "LMB held: two thrusts and the lunge, the water off the blade",
		[0.12, 0.2, 0.45, 0.52, 0.78, 0.85, 0.95, 1.1, 1.4], func(): return (P.pos + T.pos) * 0.5), 2.0)
	await _go(GAP)

func _part_rmb() -> void:
	for v: String in POTIONS:
		await _reset(6.0)
		(P.ak as GilKit).bag.append(v)
		P.ak.cd["rmb"] = 0.0
		P.ak.ch_rmb = 2.0
		var cast := func(t: float):
			P.inp["sec"] = _at(t, 0.1)
			_aim(T.pos)
		await _go(1.8, cast, _sheet("rmb_" + v, "RMB, %s: the throw, the flight, the burst on the dummy" % v,
			[0.15, 0.3, 0.45, 0.6, 0.7, 0.85, 1.0, 1.3, 1.7], func(): return T.pos), 2.0)
		await _go(GAP)

func _part_dash() -> void:
	await _reset(8.0)
	var swim := func(t: float):
		if _at(t, 0.15):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		if t > 0.5:
			P.inp["move"] = Vector2.ZERO
		_aim(T.pos)
	await _go(1.6, swim, _sheet("dash", "Shift: the dive, the fin cutting the ground, surfacing by the dummy",
		[0.17, 0.25, 0.35, 0.45, 0.55, 0.65, 0.8, 1.0, 1.4], func(): return (P.pos + T.pos) * 0.5), 2.0)
	await _go(GAP)

func _part_e() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		if _at(t, 1.3):
			P.ak.e_recast()
		_aim(T.pos)
	await _go(2.2, cast, _sheet("e", "E: the Riptide spin, E again: the waterspout down the line",
		[0.2, 0.5, 0.8, 1.1, 1.35, 1.45, 1.55, 1.7, 2.0], func(): return (P.pos + T.pos) * 0.5), 2.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(8.0)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(T.pos)
	await _go(2.2, cast, _sheet("r", "X, Tidal Wave: the wave rises, he rides its crest, the landing",
		[0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.15, 1.4, 1.9], func(): return (P.pos + T.pos) * 0.5), 2.5)
	await _go(GAP)
