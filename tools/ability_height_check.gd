extends RefCounted
## --ability-height-check: the height rule of docs/COMBAT.md for ability shapes. Each shape is cast at a
## dummy standing 1 and 2 tiers (World.LEVEL) above and below the caster, which must hit, and 3 and 4 tiers
## (past AimMode.REACH_Y; 4 is a wall's height) above and below, which must not. The shapes: circle (Grimble's
## Anchor Drop, Tenzo's Quakefall), zone (Vex's Cinderfall, Lace's Hail Wall), lane (Albert's Faultline),
## cone (Vex's Burr blast); the shared stage and effect hit tests are asserted straight on AimMode.

const AKCheck := preload("res://tools/archetype_check.gd")
const UP := [0, 1, 2, -1, -2, 3, -3, 4, -4]       # dummy tiers relative to the caster
const SIDE := 0.9                           # m: where the cursor lands beside the dummy, on the caster's level
const PAD := 0                              # tiles either side of the dummy that move with it
var A: AKCheck
var tx := 0                                 # the dummy's tile x
var tz := 0
var base := 0                               # the strip's tile level

func run(main_node: Node) -> void:
	A = AKCheck.new()
	A.main = main_node
	_rule()
	await _circle_grimble()
	await _circle_tenzo()
	await _zone_vex()
	await _zone_lace()
	await _lane_albert()
	await _cone_vex()
	print("AHEIGHT DONE, %d checks, failures: %d" % [A.n, A.fails])
	main_node.get_tree().quit(1 if A.fails > 0 else 0)

## The shared rule, straight: the band is symmetric and a wall's height is out.
func _rule() -> void:
	var l := World.LEVEL
	var reach := func(a: int, b: int) -> bool: return AimMode.in_reach(a * l, b * l)
	var near: bool = reach.call(0, 1) and reach.call(0, 2) and reach.call(2, 0) and reach.call(1, 0)
	A.ok("rule: 1 and 2 tiers up or down reach", near)
	var far: bool = reach.call(0, 3) or reach.call(3, 0) or reach.call(0, 4)
	A.ok("rule: 3 tiers and a wall (4) up or down do not", not far)

## Moves the strip so the dummy stands `d` tiers off the caster: up raises the dummy's pad, down raises the rest.
func _rig(m: Match, P: Hunter, T: Hunter, home: Vector3, spot: Vector3, d: int) -> void:
	var W: World = m.world
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	for dz in range(-10, 11):
		for dx in range(-8, int(spot.x - home.x) + 12):
			if not W.inb(hx + dx, hz + dz): continue
			var pad: bool = absi(hx + dx - tx) <= PAD and absi(hz + dz - tz) <= PAD
			var lift := 0
			if pad and d > 0:
				lift = d
			elif not pad and d < 0:
				lift = -d
			W.level[W.idx(hx + dx, hz + dz)] = base + lift
	var py := W.ground_at(home.x, home.z)
	P.teleport(Vector3(home.x, py, home.z))
	P.vel = Vector3.ZERO
	T.teleport(Vector3(spot.x, W.ground_at(spot.x, spot.z), spot.z))
	T.vel = Vector3.ZERO

## One cast per tier offset, each in a fresh match (statuses from the last cast must not leak): `cast` returns once
## the ability has landed. A cursor-placed shape in the wall-height cases is aimed beside the dummy, on the
## caster's level, so the test is the shape's own height reach and not the cursor following the ledge.
func _sweep(what: String, arch: String, dist: float, cast: Callable, aim_beside := false) -> void:
	for d in UP:
		var r: Array = A.setup(arch, dist, "", false)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var T: Hunter = r[2]
		var home: Vector3 = r[4]
		base = int(r[5])
		var spot := T.pos
		tx = int(floor(spot.x))
		tz = int(floor(spot.z))
		P.lvl = 6
		_rig(m, P, T, home, spot, d)
		var cur := T.pos
		if aim_beside and absi(d) >= 3:
			cur = Vector3(spot.x - SIDE, m.world.ground_at(spot.x - SIDE, spot.z), spot.z)
		A.aim_at(P, cur)
		A.step(m, 0.2)
		await cast.call(m, P, T)
		var hit: bool = A.dmg(T) > 0.0 or T.stun_t > 0.0
		var near := absi(d) <= 2
		A.ok("%s: dummy %+d tiers %s" % [what, d, "hit" if near else "not hit"], hit == near, "took %.0f" % A.dmg(T))
		await A.done(m)

func _circle_grimble() -> void:
	await _sweep("circle Grimble Anchor Drop", "dredge", 2.0, func(m, P, T):
		P.ak.cd["e"] = 0.0
		P.ak.use_e()
		A.step(m, 0.9))

func _circle_tenzo() -> void:
	await _sweep("circle Tenzo Quakefall", "dolm", 2.5, func(m, P, T):
		P.ak.ch_rmb = 1.0
		P.ak.cd["rmb"] = 0.0
		P.inp["sec_hold"] = true
		P.ak.press_rmb()
		A.step(m, 0.6, func(): P.inp["sec_hold"] = true)
		P.inp["sec_hold"] = false
		A.step(m, 0.6))

func _zone_vex() -> void:
	await _sweep("zone Vex Cinderfall", "gunslinger", 6.0, func(m, P, T):
		P.ak.cd["x"] = 0.0
		HunterKeys.ult_pressed(P)
		A.step(m, 3.2), true)

func _zone_lace() -> void:
	await _sweep("zone Lace Hail Wall", "archer", 5.0, func(m, P, T):
		P.ak.cd["e"] = 0.0
		P.ak.use_e()
		A.step(m, 1.8), true)

func _lane_albert() -> void:
	await _sweep("lane Albert Faultline", "bulwark", 7.0, func(m, P, T):
		P.ak.cd["x"] = 0.0
		HunterKeys.ult_pressed(P)
		A.step(m, 4.0))

func _cone_vex() -> void:
	await _sweep("cone Vex Burr blast", "gunslinger", 3.0, func(m, P, T):
		var K: GunslingerKit = P.ak
		K._cone(Vector3(P.pos.x, P.pos.y, P.pos.z), Vector2.RIGHT, K.rmb_def()["burr"], false)
		A.step(m, 0.2))
