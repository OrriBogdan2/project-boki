extends "res://tools/hero_vfx_reel.gd"
## Lace's reel (--hero-vfx-reel --reel-hero=archer): an LMB tap, a drawn shot let go in the perfect window, the
## Heavy Shot held to full and loosed (RMB), the Hail Wall (E) and Starpiercer (R), each at the match camera.


func parts() -> Array:
	return ["lmb", "draw", "rmb", "e", "r"]


func _part_draw() -> void:
	await _reset(6.0)
	var draw := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 0.75
		_aim(T.pos)
	var times := [0.2, 0.4, 0.6, 0.72, 0.78, 0.85, 0.95, 1.2, 1.6]
	await _go(1.8, draw, _sheet("draw", "LMB held, then let go: the draw and the shot", times), 1.5)
	await _go(GAP)


func _part_rmb() -> void:
	await _reset(6.0)
	var heavy := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 1.4
		_aim(T.pos)
	var times := [0.3, 0.7, 1.1, 1.3, 1.42, 1.5, 1.6, 1.8, 2.2]
	await _go(2.6, heavy, _sheet("rmb", "RMB held to full, then the Heavy Shot", times), 2.0)
	await _go(GAP)
