extends "res://tools/hero_vfx_reel.gd"
## Motley's reel (tools/hero_vfx_reel.gd): the Shard Snap's wind-up, flight and stun; the Brimseed planted,
## growing and popped; Nightwell from its dome through the open well to its close. LMB and the Trade play the
## generic parts.

func parts() -> Array:
	return ["lmb", "hold", "rmb", "dash", "e", "r"]

func _part_rmb() -> void:
	await _reset(7.0)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		_aim(T.pos)
	await _go(1.6, cast, _sheet("rmb", "RMB, Shard Snap: the wind-up, the bundle in flight, the stun",
		[0.15, 0.3, 0.42, 0.46, 0.52, 0.6, 0.75, 1.0, 1.4], func(): return (P.pos + T.pos) * 0.5), 2.0)
	await _go(GAP)

func _part_e() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1) or _at(t, 2.6)
		_aim(T.pos)
	await _go(3.6, cast, _sheet("e", "E, Brimseed: the drop, the seed growing, E again: the pop",
		[0.2, 0.4, 1.0, 2.0, 2.62, 2.68, 2.8, 3.0, 3.4], func(): return T.pos), 2.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(T.pos)
	await _go(5.0, cast, _sheet("r", "X, Nightwell: the dome, the well opening, held, closing",
		[0.3, 0.7, 1.05, 1.15, 1.3, 1.8, 3.0, 4.6, 4.8], func(): return T.pos), 2.5)
	await _go(GAP)
