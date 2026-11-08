extends "res://tools/hero_vfx_reel.gd"
## Sable's reel (tools/hero_vfx_reel.gd): the generic set, with E recast so the blink (its out-burst, afterimages and
## in-burst) is on the sheet.

func parts() -> Array:
	return GENERIC

func _part_e() -> void:
	await _reset(5.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1) or _at(t, 0.8)
		_aim(T.pos)
	await _go(2.0, cast, _sheet("e", "E at the dummy, E again: the blink behind it",
		[0.15, 0.3, 0.5, 0.8, 0.84, 0.9, 1.0, 1.2, 1.6], func(): return (P.pos + T.pos) * 0.5), 2.5)
	await _go(GAP)
