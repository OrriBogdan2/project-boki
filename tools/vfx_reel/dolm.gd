extends "res://tools/hero_vfx_reel.gd"
## Tarek's reel (--hero-vfx-reel --reel-hero=dolm): a boulder thrown, Stone Row raised then punched into flying
## rocks that burst, Rubble Leap, a full Quakefall, and Basalt Spine erupting.

## Engine.time_scale while the reel runs: a software frame takes about half a second, so at this scale the
## looks (on process time) advance about one match step per frame, as the match itself does here.
const SLOW := 0.033

func parts() -> Array:
	return ["boulder", "rocks", "dash", "quake", "r"]

func run(main_node: Node) -> void:
	Engine.time_scale = SLOW
	await super.run(main_node)

func _part_boulder() -> void:
	await _reset(7.0)
	var throw := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 0.14
		_aim(T.pos)
	await _go(1.4, throw, _sheet("boulder", "LMB tap: a boulder thrown, bursting on the dummy",
		[0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.75, 0.95, 1.2]), 3.5)
	await _go(GAP)

func _part_rocks() -> void:
	await _reset(9.0)
	var row := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		P.inp["fire"] = t > 1.2 and t < 2.3
		_aim(T.pos)
	var caption := "E then a held LMB: the eye-stones, Stone Row erupting, the punch, rocks flying and bursting"
	await _go(3.2, row, _sheet("rocks", caption,
		[0.12, 0.35, 0.55, 0.8, 1.8, 2.32, 2.4, 2.6, 2.9]), 3.5)
	await _go(GAP)

func _part_quake() -> void:
	await _reset(3.0)
	var quake := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 1.6
		_aim(T.pos)
	await _go(3.0, quake, _sheet("quake", "RMB held: the eye-stones, the charge, the Quakefall, the cracked ground",
		[0.4, 0.9, 1.5, 1.7, 1.8, 1.9, 2.1, 2.5, 2.9]), 1.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(8.0)
	var ult := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.inp["x_down"] = true
			P.ak.cast_ult()
		if _at(t, 0.4):
			P.inp["x_down"] = false
		_aim(T.pos)
	await _go(2.4, ult, _sheet("r", "R, Basalt Spine: the eye-stones, the cracks, the ridge erupting",
		[0.15, 0.3, 0.45, 0.55, 0.65, 0.75, 0.9, 1.3, 2.0], func(): return T.pos + Vector3(-2.0, 0.5, 0)), 4.0)
	await _go(GAP)
