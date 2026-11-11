extends "res://tools/hero_vfx_reel.gd"
## Pip's reel (tools/hero_vfx_reel.gd): her starlit casts, the hop's star trail, the Burrseed to its root, the
## Hearthlight on her and thrown (its heals rising as stars, the bloom), and Hearth Call's tether to its end.

func parts() -> Array:
	return ["lmb", "hold", "dash", "rmb", "e", "r"]

func _part_lmb() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 1.6
		_aim(T.pos)
	await _go(2.0, cast, _sheet("lmb", "LMB held: starlit comets from alternating hands, the hand flares, Kindled",
		[0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.3, 1.6, 1.9], func(): return (P.pos + T.pos) * 0.5), 2.0)
	await _go(GAP)

func _part_dash() -> void:
	await _reset(6.0)
	var hop := func(t: float):
		if _at(t, 0.15):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		if t > 0.5:
			P.inp["move"] = Vector2.ZERO
		_aim(T.pos)
	await _go(1.6, hop, _sheet("dash", "Shift: the hop's stars and its faint star trail",
		[0.17, 0.22, 0.28, 0.34, 0.42, 0.55, 0.7, 1.0, 1.4]), 2.0)
	await _go(GAP)

func _part_rmb() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 0.6
		_aim(T.pos)
	await _go(2.6, cast, _sheet("rmb", "RMB: starlight gathers at the lantern, the cast, the seed's trail, the root",
		[0.3, 0.62, 0.7, 0.8, 1.0, 1.4, 1.8, 2.1, 2.5], func(): return (P.pos + T.pos) * 0.5), 2.5)
	await _go(GAP)

func _part_e() -> void:
	await _reset(6.0)
	P.hp = P.max_hp * 0.5          # (hurt, so her light's heals show)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		if _at(t, 1.2):
			P.ak.e_recast()
		_aim(P.pos + Vector3(3.0, 0, 0))
	await _go(3.0, cast, _sheet("e", "E: the lantern flares, stars rise off her as it heals, thrown, it lands",
		[0.15, 0.3, 0.6, 0.9, 1.2, 1.35, 1.6, 2.2, 2.9]), 1.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(4.0)
	P.hp = P.max_hp * 0.5
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(P.pos)
	await _go(2.8, cast, _sheet("r", "R, Hearth Call: the lantern's flare, the heals rising as stars",
		[0.15, 0.3, 0.5, 0.8, 1.1, 1.5, 1.9, 2.3, 2.7]), 1.0)
	await _go(GAP)
