extends "res://tools/hero_vfx_reel.gd"
## Sable's reel (tools/hero_vfx_reel.gd): Encore at match zoom, the ring growing out over its 0.4s, then a Vault
## across the ring with the blade layer riding on her.

func parts() -> Array:
	return ["x"]

func _part_x() -> void:
	await _reset(3.0)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		if _at(t, 1.0):
			P.inp["move"] = Vector2(0, -1)
			P.do_dash()
		if t > 1.6:
			P.inp["move"] = Vector2.ZERO
		_aim(T.pos)
	await _go(2.2, cast, _sheet("x", "X, Encore: the ring grows over 0.4s, then a Vault with the blades riding on her",
		[0.12, 0.2, 0.3, 0.4, 0.5, 0.9, 1.1, 1.25, 1.4], func(): return P.pos + Vector3(0, 0.9, 0)), 2.5)
	await _go(GAP)
