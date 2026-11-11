extends "res://tools/parity_reel.gd"
## --dredge-arm-reel --reel-hero=dredge --shots-dir=<dir> [--reel-only=<part>]: Grimble's Abyssal Hand at the match
## camera, to see that the arm reads as his own and holds steady: the grab standing, the grab while strafing, a
## miss, and a plain run. Frames and the ffmpeg line as in tools/parity_reel.gd.

const PARTS := ["rmb_hit", "rmb_strafe", "rmb_miss", "run"]

func parts() -> Array:
	return PARTS

func _p_rmb_hit() -> void:
	await _seg("RMB at the dummy, standing", 4.2, func(t: float) -> void:
		P.inp["sec"] = _in(t, 0.2))

func _p_rmb_strafe() -> void:
	await _seg("RMB while strafing", 4.2, func(t: float) -> void:
		P.inp["move"] = Vector2(0, 1) if t < 3.6 else Vector2.ZERO
		P.inp["sec"] = _in(t, 0.2))

func _p_rmb_miss() -> void:
	await _seg("RMB, a miss", 2.6, func(t: float) -> void:
		_aim(P.pos + Vector3(0, 0, -8))
		P.inp["sec"] = _in(t, 0.2), 6.0)

func _p_run() -> void:
	await _seg("Run", 3.0, func(t: float) -> void:
		P.inp["move"] = Vector2(1, 0) if t < 1.4 else Vector2(-1, 0), FAR)
