extends "res://tools/hero_vfx_reel.gd"
## Sable's (thief) reel parts for --hero-vfx-reel: her violet shots (a hit, a fizzle at the cursor), the Vault and
## its empowered shot, the Bola, the Shadow Knife and its blink, and Encore.

func parts() -> Array:
	return ["lmb", "vault", "rmb", "e", "r"]

func _part_lmb() -> void:
	await _reset(6.0)
	var shoot := func(t: float):
		P.inp["fire"] = fmod(t, 0.5) < DT * 2.0 and t < 1.3
		_aim(T.pos if t < 0.9 else P.pos + Vector3(3.0, 0, 2.5))
	await _go(2.2, shoot, _sheet("lmb",
			"LMB: the muzzle flare at her hand, the violet tracer, the hit on the dummy; a shot left at the cursor "
			+ "fizzles to smoke",
			[0.03, 0.08, 0.15, 0.3, 0.52, 0.6, 1.05, 1.3, 1.8]), 2.0)
	await _go(GAP)

func _part_vault() -> void:
	await _reset(6.0)
	var dash := func(t: float):
		if _at(t, 0.15):
			P.inp["move"] = Vector2(0, -1)
			P.do_dash()
		if t > 0.3:
			P.inp["move"] = Vector2.ZERO
		P.inp["fire"] = _at(t, 1.0)
		_aim(T.pos)
	await _go(2.4, dash, _sheet("vault",
			"Shift, Vault: the cartwheel's arcs, the smoke she leaves hanging and thinning, the empowered shot "
			+ "formed in the hand, its tracer and the reset",
			[0.2, 0.3, 0.45, 0.7, 0.95, 1.05, 1.15, 1.5, 2.2]), 2.5)
	await _go(GAP)

func _part_rmb() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		_aim(T.pos)
	await _go(2.4, cast, _sheet("rmb",
			"RMB, Bola: sparks whirling at the raised hand, the throw, the wrap on the dummy, smoke where it ends",
			[0.15, 0.3, 0.45, 0.55, 0.65, 0.8, 1.1, 1.5, 2.2]), 2.5)
	await _go(GAP)

func _part_e() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1) or _at(t, 1.0)
		_aim(T.pos)
	await _go(2.6, cast, _sheet("e",
			"E, Shadow Knife: the throw and its trail, the knife biting the dummy, E again: smoke where she vanished "
			+ "and where she arrives",
			[0.2, 0.3, 0.45, 0.8, 1.05, 1.15, 1.4, 1.9, 2.5]), 2.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(3.5)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(T.pos)
	await _go(2.8, cast, _sheet("r", "R, Encore: violet gathering on her, the blades flying, the hits",
			[0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.4, 1.9, 2.6]), 2.5)
	await _go(GAP)
