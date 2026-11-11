extends "res://tools/hero_vfx_reel.gd"
## Pip's reel (tools/hero_vfx_reel.gd): her starlit casts, the hop's star trail, the Burrseed to its root, the
## Hearthlight on her and thrown (its heals rising as stars, the bloom), and Hearth Call's tether to its end.

const NEAR := [Vector3(0.9, 0, -1.3), Vector3(0.9, 0, 1.3)]     # m from the target: the RMB part's extra dummies

var near: Array[Hunter] = []

func parts() -> Array:
	return ["lmb", "hold", "dash", "rmb", "e", "r"]

func _part_lmb() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 1.6
		_aim(T.pos)
	await _go(2.0, cast, _sheet("lmb", "LMB held: starlit comets from alternating hands, the hand flares, Kindled",
		[0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.3, 1.6, 1.9], func(): return (P.pos + T.pos) * 0.5), 2.0)
	await _go(GAP)

func _part_dash() -> void:
	await _reset(6.0)
	var hop := func(t: float):
		if _at(t, 0.15):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		if t > 0.5:
			P.inp["move"] = Vector2.ZERO
		_aim(T.pos)
	await _go(1.6, hop, _sheet("dash", "Shift: the hop's stars and its faint star trail",
		[0.17, 0.22, 0.28, 0.34, 0.42, 0.55, 0.7, 1.0, 1.4]), 2.0)
	await _go(GAP)

## Two more dummies stand beside the target, inside the burst, so the root shows on each foe it takes.
func _part_rmb() -> void:
	await _reset(6.0)
	for side in NEAR:
		near.append(m.make_hunter("T%d" % near.size(), 5, "medium", "Target", "idle", {}, T.pos + side,
				{"arch": "none"}))
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 0.6
		_aim(T.pos)
	await _go(4.4, cast, _sheet("rmb", "RMB: the cast, the seed's vine, the root field filling, the root on each foe",
		[0.3, 1.0, 1.5, 2.3, 3.0, 3.35, 3.5, 3.8, 4.3], func(): return (P.pos + T.pos * 2.0) / 3.0), 2.5)
	near.clear()
	await _go(GAP)

## (the rig parks every other Hunter far off each frame; the RMB part's extra dummies stay beside the target)
func _park_others() -> void:
	super._park_others()
	for i in near.size():
		near[i].teleport(T.pos + NEAR[i])

func _part_e() -> void:
	await _reset(6.0)
	P.hp = P.max_hp * 0.5          # (hurt, so her light's heals show)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		if _at(t, 1.2):
			P.ak.e_recast()
		_aim(P.pos + Vector3(3.0, 0, 0))
	await _go(3.0, cast, _sheet("e", "E: the lantern flares, stars rise off her as it heals, thrown, it lands",
		[0.15, 0.3, 0.6, 0.9, 1.2, 1.35, 1.6, 2.2, 2.9]), 1.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(4.0)
	P.hp = P.max_hp * 0.5
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(P.pos)
	await _go(2.8, cast, _sheet("r", "R, Hearth Call: the lantern's flare, the heals rising as stars",
		[0.15, 0.3, 0.5, 0.8, 1.1, 1.5, 1.9, 2.3, 2.7]), 1.0)
	await _go(GAP)
