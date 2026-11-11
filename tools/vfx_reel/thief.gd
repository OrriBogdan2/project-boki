extends "res://tools/hero_vfx_reel.gd"
## Sable's reel (tools/hero_vfx_reel.gd): the generic set, with her own E and X. E: the Shadow Knife into the dummy
## and on the ground, each recast so the blink's arrival shows. X: Encore with one dummy in the outer band (the rim
## blades) and one well inside it, through the ring opening, the beats and the fade.

const RIM_AT := 4.7            # m from her: in Encore's outer band (past 75% of 5.4 m)
const INNER_AT := 2.4          # m: well inside it
const RING_CROP := Vector2i(760, 460)     # px: the whole 5.4 m ring at the match camera

func parts() -> Array:
	return ["lmb", "hold", "rmb", "dash", "e", "e_ground", "r"]

func _thief_e() -> void:
	await _reset(6.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1) or _at(t, 1.3)
		_aim(T.pos)
	await _go(2.4, cast, _sheet("e", "E at the dummy: the knife sticks, its circle; E again at 1.3 s: the blink lands",
		[0.15, 0.3, 0.5, 0.8, 1.2, 1.32, 1.38, 1.5, 1.9], func(): return (P.pos + T.pos) * 0.5), 2.5)
	await _go(GAP)

func _thief_e_ground() -> void:
	await _reset(9.0)
	var spot := home + Vector3(5.0, 0, 2.5)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1) or _at(t, 1.4)
		_aim(spot)
	await _go(2.4, cast, _sheet("e_ground", "E at the ground: the knife's circle on its own; E again at 1.4 s",
		[0.2, 0.4, 0.7, 1.0, 1.3, 1.42, 1.48, 1.6, 2.0], func(): return (home + spot) * 0.5), 2.5)
	await _go(GAP)

func _thief_r() -> void:
	await _reset(RIM_AT)
	if T2 == null:
		T2 = m.make_hunter("T2", 5, "medium", "Inner", "idle", {}, home, {"arch": "none"})
	T2.teleport(home + Vector3(-1.0, 0, INNER_AT))
	T2.vel = Vector3.ZERO
	T2.hp = T2.max_hp
	crop_px = RING_CROP
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(T.pos)
	await _go(3.0, cast, _sheet("r", "X Encore: the ring opens, blades on the beats (rim dummy right, inner up)",
		[0.2, 0.35, 0.5, 0.56, 0.7, 1.0, 1.5, 2.2, 2.7], func(): return P.pos), 2.5)
	crop_px = SHEET_CROP
	T2.teleport(home + Vector3(-30, 0, 30))
	await _go(GAP)
