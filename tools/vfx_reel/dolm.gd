extends "res://tools/hero_vfx_reel.gd"
## Tenzo's reel (tools/hero_vfx_reel.gd), owner playtest 11-08: the held Quakefall at the dummy and at a dummy
## right in its path, and R pressed while falling over the abyss (the rock floor rising under him, its cracks and
## shake, the crumble), besides the generic dash and E.

func parts() -> Array:
	return ["rmb", "rmb_body", "dash", "e", "r_void"]

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
