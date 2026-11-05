extends "res://tools/hero_vfx_reel.gd"
## Vex's reel (--hero-vfx-reel --reel-hero=gunslinger): the generic set with the rifle held down (her tracers) and
## the Burr Charge thrown past the dummy too, so it sticks, fizzes and blasts.

func parts() -> Array:
	return ["lmb", "rmb", "blast", "dash", "e", "r"]

func _part_lmb() -> void:
	await _reset(6.0)
	var shoot := func(t: float):
		P.inp["fire"] = t < 1.0
		_aim(T.pos)
	await _go(1.6, shoot, _sheet("lmb", "LMB held at the dummy", [0.05, 0.1, 0.2, 0.35, 0.5, 0.7, 0.9, 1.1, 1.4]),
			2.5)
	await _go(GAP)

func _part_blast() -> void:
	await _reset(5.0, 3.0)
	var at := P.pos + Vector3(6.0, 0, -2.0)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 0.4
		_aim(at)
	var focus := func() -> Vector3: return at + Vector3(0, 0.6, 0)
	var times := [0.3, 0.5, 0.7, 0.9, 1.1, 1.3, 1.45, 1.7, 2.3]
	await _go(2.6, cast, _sheet("blast", "RMB past the dummy: it sticks, fizzes, blasts", times, focus), 2.5)
	await _go(GAP)
