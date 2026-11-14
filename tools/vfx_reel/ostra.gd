extends "res://tools/hero_vfx_reel.gd"
## Motley's reel (tools/hero_vfx_reel.gd): quick orbs and a full orb at the dummy with their hits, the Shard Snap's
## wind-up, flight and stun, the Trade's lob to its landing, the Brimseed planted, growing and popped, and Nightwell
## from its dome through the open well to its close.

func parts() -> Array:
	return ["lmb", "full", "rmb", "dash", "e", "r"]

## A full orb: he waits out the charge (lmb.idle), then one shot.
func _part_full() -> void:
	await _reset(5.0)
	var shoot := func(t: float):
		P.inp["fire"] = _at(t, 1.5)
		_aim(T.pos)
	await _go(2.4, shoot, _sheet("full", "LMB after a 1.5 s wait: the charge glow, the full orb, its hit",
		[0.6, 1.2, 1.45, 1.52, 1.58, 1.64, 1.7, 1.85, 2.2], func(): return (P.pos + T.pos) * 0.5), 2.0)
	await _go(GAP)

func _part_rmb() -> void:
	await _reset(7.0)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		_aim(T.pos)
	await _go(1.6, cast, _sheet("rmb", "RMB, Shard Snap: the wind-up, the bundle in flight, the stun",
		[0.15, 0.3, 0.42, 0.46, 0.52, 0.6, 0.75, 1.0, 1.4], func(): return (P.pos + T.pos) * 0.5), 2.0)
	await _go(GAP)

func _part_dash() -> void:
	await _reset(7.0)
	var lob := func(t: float):
		if _at(t, 0.15):
			P.do_dash()
		_aim(T.pos)
	await _go(2.6, lob, _sheet("dash", "Shift, Lantern Trade: the lob, the lantern in flight, both ends folding in",
		[0.2, 0.4, 0.8, 1.2, 1.6, 1.9, 2.0, 2.1, 2.4], func(): return (P.pos + T.pos) * 0.5), 2.5)
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
