extends "res://tools/hero_vfx_reel.gd"
## Lisette's (archer) reel parts for --hero-vfx-reel: the bow's draw to Supercharged and its red-thread needle,
## a missed needle left in the ground, the full Heavy Shot, Spirit Walk, the Hail Wall and Starpiercer.

func parts() -> Array:
	return ["draw", "miss", "heavy", "dash", "e", "r"]

func _part_draw() -> void:
	await _reset(7.0)
	var pull := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 1.45
		_aim(T.pos)
	await _go(2.4, pull, _sheet("draw",
			"LMB held to Supercharged: thread gathering at the nock, the string's threads drawn taut at each stage, "
			+ "the needle and its red thread, the hit stitching the dummy",
			[0.3, 0.75, 1.2, 1.4, 1.5, 1.56, 1.65, 1.9, 2.3]), 2.5)
	await _go(GAP)

func _part_miss() -> void:
	await _reset(7.0, 4.0)
	var pull := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 0.9
		_aim(P.pos + Vector3(5.0, 0, 0))
	await _go(2.6, pull, _sheet("miss", "A needle that misses stays in the ground with a little thread",
			[0.92, 1.0, 1.1, 1.3, 1.6, 1.9, 2.2, 2.4, 2.6]), 2.0)
	await _go(GAP)

func _part_heavy() -> void:
	await _reset(6.0)
	var K: ArcherKit = P.ak
	var hold := func(t: float):
		if _at(t, 0.1):
			P.inp["sec_hold"] = true
			K.press_rmb()
		if t >= 1.4:
			P.inp["sec_hold"] = false
		_aim(T.pos)
	await _go(2.6, hold, _sheet("heavy",
			"RMB held, Heavy Shot: thread winding thick at the nock, the release at the bow, the big needle's "
			+ "thread, the hit run through with thread and dust",
			[0.5, 1.0, 1.38, 1.44, 1.5, 1.6, 1.8, 2.1, 2.5]), 2.0)
	await _go(GAP)

func _part_dash() -> void:
	await _reset(6.0)
	var dash := func(t: float):
		if _at(t, 0.15):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		if t > 0.5:
			P.inp["move"] = Vector2.ZERO
		_aim(T.pos)
	await _go(2.0, dash, _sheet("dash", "Shift, Spirit Walk: thread unravelling off her through the walk",
			[0.18, 0.25, 0.35, 0.5, 0.7, 0.9, 1.2, 1.6, 1.9]), 2.5)
	await _go(GAP)

func _part_e() -> void:
	await _reset(7.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		_aim(T.pos)
	var on_wall := func() -> Vector3:
		return T.position + Vector3(0, 0.9, 0)
	await _go(3.0, cast, _sheet("e",
			"E, Hail Wall: needles shot up from the bow, the rain landing, thread settling where it fell",
			[0.15, 0.3, 0.6, 0.9, 1.2, 1.6, 2.0, 2.5, 2.9], on_wall), 2.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(8.0)
	var K: ArcherKit = P.ak
	var cast := func(t: float):
		if _at(t, 0.1):
			K.cd["x"] = 0.0
			K.cast_ult()
		P.inp["fire"] = t > 0.4 and t < 0.5 or t > 1.4 and t < 1.5
		_aim(T.pos)
	await _go(2.6, cast, _sheet("r",
			"R, Starpiercer: thread drawn in on the cast, the nock, the thread beam through the dummy and the "
			+ "stitched line it leaves",
			[0.15, 0.3, 0.55, 0.75, 0.85, 1.0, 1.3, 1.85, 2.4]), 2.5)
	await _go(GAP)
