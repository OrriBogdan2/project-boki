extends "res://tools/hero_vfx_reel.gd"
## Cinder's reel (tools/hero_vfx_reel.gd): the lance held and swept across the dummy (the hose, its tongues and
## scorch), the Cinder Shot into a burning dummy (the spread), the ram into it, the cloak, and the flight with the
## tank jets over the carpet.

func parts() -> Array:
	return ["lmb", "rmb", "dash", "e", "r"]

func _part_lmb() -> void:
	await _reset(4.5)
	var hose := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 2.0
		var sweep := sin(t * 2.2) * 2.5          # m the aim swings across the dummy
		_aim(T.pos + Vector3(0, 0, sweep))
	await _go(2.4, hose, _sheet("lmb", "LMB held and swept: the pilot, the hose, its tongues and scorch, release",
		[0.12, 0.25, 0.45, 0.7, 1.0, 1.3, 1.7, 2.05, 2.3]), 1.5)
	await _go(GAP)

func _part_rmb() -> void:
	await _reset(6.0)
	P.ak.stoke(T)              # (a burning dummy, so the shot shows its spread)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 0.5
		_aim(T.pos)
	await _go(2.4, cast, _sheet("rmb", "RMB: the gather, the shot and its trail, the hit on a burning foe",
		[0.2, 0.4, 0.52, 0.58, 0.66, 0.8, 1.0, 1.4, 2.0], func(): return (P.pos + T.pos) * 0.5), 2.0)
	await _go(GAP)

func _part_r() -> void:
	await _reset(3.0)
	P.teleport(home + Vector3(-5.0, 0, 0))
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(T.pos + Vector3(4.0, 0, 2.0))
	await _go(2.8, cast, _sheet("r", "R, Flue Flight: lift-off, the tank jets, the carpet, the landing",
		[0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.4, 1.9, 2.6]), 2.5)
	await _go(GAP)
