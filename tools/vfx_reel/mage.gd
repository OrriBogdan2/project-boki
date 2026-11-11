extends "res://tools/hero_vfx_reel.gd"
## Sparkle's reel (tools/hero_vfx_reel.gd): finger bolts and their hits, the Storm Rod held to full and thrown,
## Skycall placed, dragged and striking, and Kitefall brought down early so the strike and its afterglow are framed.

func parts() -> Array:
	return ["lmb", "rmb", "e", "r"]

func _between() -> Callable:
	return func(): return (P.pos + T.pos) * 0.5 + Vector3(0, 0.9, 0)

func _part_lmb() -> void:
	await _reset(5.0)
	var shoot := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 1.5
		_aim(T.pos)
	await _go(2.0, shoot, _sheet("lmb", "LMB: finger bolts from alternating hands, the bolt in flight, the hit",
		[0.12, 0.16, 0.2, 0.26, 0.4, 0.77, 0.81, 0.86, 1.2], _between()), 2.0)
	await _go(GAP)

func _part_rmb() -> void:
	await _reset(5.0)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 1.25
		_aim(T.pos)
	await _go(2.6, cast, _sheet("rmb", "RMB: the rod summoned, held to full, thrown, the hit and its orb",
		[0.2, 0.7, 1.15, 1.28, 1.32, 1.38, 1.5, 1.8, 2.4], _between()), 2.0)
	await _go(GAP)

func _part_e() -> void:
	await _reset(5.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		P.inp["e_down"] = t > 0.1 and t < 0.5
		_aim(T.pos if t < 0.15 else T.pos + Vector3(0, 0, 2.0))
	await _go(2.6, cast, _sheet("e", "E: placed, dragged, the countdown, the strike and its afterglow",
		[0.15, 0.4, 0.7, 1.0, 1.25, 1.33, 1.4, 1.6, 2.2], func(): return T.pos + Vector3(0, 0.9, 0)), 3.0)
	await _go(GAP)

func _part_r() -> void:
	P.lvl = 6
	await _reset(5.0)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		if _at(t, 0.5):
			P.ak.ult_recast()
		_aim(T.pos)
	await _go(2.4, cast, _sheet("r", "R, Kitefall: the call, the launch, the hang, the strike, its afterglow",
		[0.15, 0.45, 0.75, 1.0, 1.16, 1.22, 1.35, 1.6, 2.1], _between()), 3.0)
	await _go(GAP)
