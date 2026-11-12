extends "res://tools/hero_vfx_reel.gd"
## Motley's reel (tools/hero_vfx_reel.gd): the generic LMB, held LMB and Trade; the Shard Snap's wind-up, flight and
## stun; the Brimseed planted, grown and popped; Nightwell from the dome to the quiet close, then a dash and a glide
## with the well gone (nothing of it may be left on screen), for the strips at the match camera.

func parts() -> Array:
	return ["lmb", "hold", "rmb", "dash", "e", "r", "after"]

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
		P.inp["sig"] = _at(t, 0.1) or _at(t, 6.9)
		_aim(T.pos)
	await _go(7.8, cast, _sheet("e", "E, Brimseed: the drop, the globe growing to full, E again: the pop",
		[0.2, 0.5, 1.5, 3.0, 4.6, 6.6, 6.95, 7.1, 7.5], func(): return T.pos), 2.5)
	await _go(GAP)

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
