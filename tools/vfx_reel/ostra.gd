extends "res://tools/hero_vfx_reel.gd"
## Motley's reel (--hero-vfx-reel --reel-hero=ostra): a charged orb then a plain one bursting into burning cards,
## the Snap's wind-up, spear and hit, the Lantern Trade's flight and both ends, the seed popped after it grew,
## Swell filling, and Nightwell from the dome to its close.

## Engine.time_scale while the reel runs: a software frame takes about half a second, so at this scale the
## looks (on process time) advance about one match step per frame, as the match itself does here.
const SLOW := 0.033

func parts() -> Array:
	return ["lmb", "rmb", "trade", "e", "swell", "r"]

func run(main_node: Node) -> void:
	Engine.time_scale = SLOW
	await super.run(main_node)

func _part_lmb() -> void:
	await _reset(6.0)
	await _go(1.5)              # (a rest: the first orb leaves fully charged)
	var shoot := func(t: float):
		P.inp["fire"] = _at(t, 0.1) or _at(t, 0.8)
		_aim(T.pos)
	await _go(1.8, shoot, _sheet("lmb", "LMB: a charged orb, then a plain one; each bursts into burning cards",
		[0.15, 0.25, 0.4, 0.55, 0.85, 0.95, 1.1, 1.3, 1.6]), 3.0)
	await _go(GAP)

func _part_rmb() -> void:
	await _reset(7.0)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		_aim(T.pos)
	await _go(1.6, cast, _sheet("rmb", "RMB, Shard Snap: the void gathering, the spear, the hit",
		[0.2, 0.35, 0.45, 0.5, 0.6, 0.7, 0.85, 1.0, 1.3]), 3.5)
	await _go(GAP)

func _part_trade() -> void:
	await _reset(6.0)
	var trade := func(t: float):
		if _at(t, 0.1):
			_aim(P.pos + Vector3(7.0, 0, 0))
			P.do_dash()
	await _go(2.6, trade, _sheet("trade", "Shift, Lantern Trade: the lob, the flight, a void flare at both ends",
		[0.2, 0.5, 1.0, 1.6, 1.9, 1.95, 2.0, 2.15, 2.4]), 3.5)
	await _go(GAP)

func _part_e() -> void:
	await _reset(5.0)
	var plant := func(t: float):
		P.inp["sig"] = _at(t, 0.1) or _at(t, 2.6)
		_aim(T.pos)
	await _go(3.6, plant, _sheet("e", "E, Brimseed: the seed thrown, grown, popped",
		[0.2, 0.6, 1.5, 2.5, 2.65, 2.7, 2.8, 3.0, 3.4], func(): return T.pos + Vector3(0, 0.5, 0)), 2.5)
	await _go(GAP)

func _part_swell() -> void:
	await _reset(4.0)
	var K: OstraKit = P.ak
	var fill := func(t: float):
		if _at(t, 0.1):
			K.add_swell(K.res_max())
	await _go(1.4, fill, _sheet("swell", "Passive: Swell fills, he goes Swollen",
		[0.12, 0.16, 0.2, 0.3, 0.4, 0.55, 0.7, 0.9, 1.2]), 2.0)
	K.swollen_t = 0.0
	K.res = 0.0
	await _go(GAP)

func _part_r() -> void:
	await _reset(6.0)
	var ult := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(T.pos)
	await _go(5.0, ult, _sheet("r", "R, Nightwell: the dome, the void vortex opening, cards swirling up, the close",
		[0.3, 0.9, 1.15, 1.3, 1.8, 2.6, 3.4, 4.6, 4.75], func(): return T.pos + Vector3(0, 0.5, 0)), 3.0)
	await _go(GAP)
