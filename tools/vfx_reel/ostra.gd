extends "res://tools/hero_vfx_reel.gd"
## Motley's reel (tools/hero_vfx_reel.gd): Nightwell from the dome to the quiet close, then a dash and a glide with the
## well gone (nothing of it may be left on screen), for the parity strips at the match camera.

func parts() -> Array:
	return ["r", "after"]

func _part_r() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(T.pos)
	await _go(5.0, cast, _sheet("r", "R, Nightwell: the dome, the whirlpool opening and pulling the dummy in",
		[0.6, 1.3, 2.0, 2.8, 3.6, 4.3, 4.65, 4.8, 4.95], func(): return (P.pos + T.pos) * 0.5), 2.5)
	await _go(GAP)

## Straight after the close: a ground dash, then a jump and a glide, over the spot where the well was.
func _part_after() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		P.inp["move"] = Vector2(1, 0) if t > 4.7 else Vector2.ZERO
		P.inp["dash"] = _at(t, 4.7)
		P.inp["jump"] = t > 5.4 and t < 6.4
		_aim(T.pos)
	await _go(7.0, cast, _sheet("after", "After the close: a dash, then a jump and a glide; no well left",
		[4.55, 4.75, 4.95, 5.2, 5.5, 5.8, 6.1, 6.5, 6.9], func(): return (P.pos + T.pos) * 0.5), 2.5)
	await _go(GAP)
