extends "res://tools/hero_vfx_reel.gd"
## Tenzo's reel (--hero-vfx-reel --reel-hero=dolm): a boulder thrown, Stone Row raised then punched into flying
## rocks that burst, Rock Hop, a full Quakefall (and one at a dummy in its path), Basalt Spine erupting, and R
## pressed while falling over the abyss (owner playtest 11-08).

## Engine.time_scale while the reel runs: a software frame takes about half a second, so at this scale the
## looks (on process time) advance about one match step per frame, as the match itself does here.
const SLOW := 0.033


func parts() -> Array:
	return ["boulder", "rocks", "dash", "quake", "rmb_body", "r", "r_void"]


func run(main_node: Node) -> void:
	Engine.time_scale = SLOW
	await super.run(main_node)


func _part_boulder() -> void:
	await _reset(7.0)
	var throw := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 0.14
		_aim(T.pos)
	await _go(
		1.4,
		throw,
		_sheet(
			"boulder",
			"LMB tap: a boulder thrown, bursting on the dummy",
			[0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.75, 0.95, 1.2]
		),
		3.5
	)
	await _go(GAP)


func _part_rocks() -> void:
	await _reset(9.0)
	var row := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		P.inp["fire"] = t > 1.2 and t < 2.3
		_aim(T.pos)
	var caption := "E then a held LMB: the eye-stones, Stone Row erupting, the punch, rocks flying and bursting"
	await _go(3.2, row, _sheet("rocks", caption, [0.12, 0.35, 0.55, 0.8, 1.8, 2.32, 2.4, 2.6, 2.9]), 3.5)
	await _go(GAP)


func _part_quake() -> void:
	await _reset(3.0)
	var quake := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 1.6
		_aim(T.pos)
	await _go(
		3.0,
		quake,
		_sheet(
			"quake",
			"RMB held: the eye-stones, the charge, the Quakefall, the cracked ground",
			[0.4, 0.9, 1.5, 1.7, 1.8, 1.9, 2.1, 2.5, 2.9]
		),
		1.5
	)
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
	await _go(
		2.4,
		ult,
		_sheet(
			"r",
			"R, Basalt Spine: the eye-stones, the cracks, the ridge erupting",
			[0.15, 0.3, 0.45, 0.55, 0.65, 0.75, 0.9, 1.3, 2.0],
			func(): return T.pos + Vector3(-2.0, 0.5, 0)
		),
		4.0
	)
	await _go(GAP)


func _part_rmb_body() -> void:
	await _reset(2.0)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 0.5
		_aim(T.pos)
	await _go(2.4, cast, _sheet("rmb_body", "RMB with the dummy in the hop's path",
		[0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.2, 1.5, 2.0], func(): return (P.pos + T.pos) * 0.5), 2.0)
	await _go(GAP)

func _part_r_void() -> void:
	await _reset(12.0)
	var e := _edge()
	if e.is_empty():
		print("REEL_NOTE no abyss edge found")
		return
	var d: Vector2 = e["dir"]
	var over: Vector3 = (e["edge"] as Vector3) + Vector3(d.x, 0, d.y) * 2.2
	T.teleport(home + Vector3(-30, 0, 30))
	P.teleport(over + Vector3(0, 0.3, 0))
	P.vel = Vector3.ZERO
	P.grounded = false
	var cast := func(t: float):
		if _at(t, 0.12):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(over + Vector3(d.x, 0, d.y) * 6.0)
		m.verbs.render(1.0)      # (the rig keeps Match._process off; the floor's warning draws here)
	await _go(8.2, cast, _sheet("r_void", "R pressed falling over the abyss: the floor, its warning, the crumble",
		[0.1, 0.14, 0.2, 0.35, 1.0, 5.0, 6.5, 7.4, 8.0], func(): return P.position + Vector3(0, 0.9, 0)), 2.5)
	await _go(GAP)

## A straight abyss edge near home: solid ground behind it, open abyss for 4m past it.
func _edge() -> Dictionary:
	var w: World = m.world
	for k in 4000:
		var g := w.random_ground()
		if Vector2(g.x - home.x, g.z - home.z).length() > 40.0:
			continue
		for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var good := true
			for dd in [1.6, 2.4, 3.2, 4.0]:
				for sd in [-1.6, 0.0, 1.6]:
					good = good and w.is_void(g.x + d.x * dd + d.y * sd, g.z + d.y * dd + d.x * sd)
			for dd in [0.0, -1.0, -2.0, -3.0]:
				good = good and not w.is_void(g.x + d.x * dd, g.z + d.y * dd)
			if good:
				var at := g
				while not w.is_void(at.x + d.x * 0.25, at.z + d.y * 0.25):
					at += Vector3(d.x, 0, d.y) * 0.25
				return {"edge": at, "dir": d}
	return {}
