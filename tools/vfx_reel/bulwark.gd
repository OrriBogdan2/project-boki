extends "res://tools/hero_vfx_reel.gd"
## Albert's reel (tools/hero_vfx_reel.gd, docs/decisions/0022-breaker-swing-lunge.md): the Crushing Blow let go
## standing and then running (the lunge, its distance over him with the full performance overlay on), the 360
## Smash, the aegis boop on the dummy, the Faultline hop and slam, and the thrown hammer reeled home by its rope.

const HOLD := 1.5              # s the swing is held: past full charge and its perfect window

func parts() -> Array:
	return ["swing", "dash", "boop", "r", "rope"]

func _part_swing() -> void:
	Settings.v["show_fps"] = 2                 # (the full overlay: each swing's distance shows over him)
	await _reset(9.0)
	var stand := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 0.1 + HOLD
		_aim(T.pos)
	await _go(2.6, stand, _sheet("swing", "LMB held and let go standing: the lunge", [1.5, 1.62, 1.75, 1.9, 2.2]), 1.5)
	await _reset(12.0)
	P.teleport(home + Vector3(-4.0, 0, 0))
	var run := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 0.1 + HOLD
		P.inp["move"] = Vector2(1, 0) if t < 2.0 else Vector2.ZERO
		_aim(T.pos)
	await _go(2.8, run, _sheet("swing", "LMB held and let go running: further", [1.5, 1.62, 1.75, 1.9, 2.2]), 1.5)
	await _go(GAP)

func _part_boop() -> void:
	await _reset(2.3)
	var boop := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 1.8
		P.inp["fire"] = (t > 0.7 and t < 0.75) or (t > 1.3 and t < 1.35)
		if _at(t, 1.2):
			T.teleport(home + Vector3(2.3, 0, 0))
		_aim(home + Vector3(6.0, 0, 0))
	await _go(2.2, boop, _sheet("boop", "RMB up, LMB: the boop", [0.7, 0.75, 0.8, 0.9, 1.0, 1.35, 1.45]), 1.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(9.0, 2.6)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(home + Vector3(12.0, 0, 0))
	await _go(2.6, cast, _sheet("r", "R, Faultline: the hop, the slam, the lane",
		[0.15, 0.25, 0.32, 0.4, 0.5, 0.56, 0.7, 1.0, 1.6]), 2.0)
	await _go(GAP)

func _part_rope() -> void:
	await _reset(30.0)
	var walk := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 0.15
		P.inp["move"] = Vector2(-1, 0) if t > 0.8 and t < 3.4 else Vector2.ZERO
		_aim(home + Vector3(8.0, 0, 0))
	await _go(4.2, walk, _sheet("rope", "LMB throw, walk away: the rope reels it home",
		[0.3, 0.8, 1.6, 2.4, 2.8, 3.0, 3.2, 3.6, 4.0]), 3.0)
	await _go(GAP)
