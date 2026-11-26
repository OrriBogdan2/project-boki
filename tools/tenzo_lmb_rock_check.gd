extends "res://tools/hero_pair_check.gd"
## --tenzo-lmb-rock-check: Tenzo's (dolm) LMB and his rocks. With a Stone Row of three rocks in
## the lane, a TAP sends only the nearest rock (no boulder); a HELD punch sends all three; a tap with no rock in
## reach still throws the boulder.


func run(main_node: Node) -> void:
	main = main_node
	var r := setup("dolm", 5.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[3]
	var k: DolmKit = p.ak
	t_v.teleport(home + Vector3(0, 0, 40))      # out of every lane
	# a row of three rocks along +z, Tenzo stood behind it aiming down the row
	_row(m, p, k, home)
	var near: Vector3 = k.rock_mid(_nearest(m, p))
	ok(
		"setup: three of his rocks stand in the lane",
		rocks(m).size() == 3 and k.sweep_rocks(p.aim_dir()).size() == 3,
		"rocks %d in lane %d" % [rocks(m).size(), k.sweep_rocks(p.aim_dir()).size()]
	)
	var l0 := k.launches
	var b0 := k.boulders
	_press(m, p, 0.08)
	step(m, 0.4)
	var left := rocks(m)
	ok(
		"tap: exactly one rock is launched, the boulder stays in his hand",
		k.launches == l0 + 1 and k.last_sweep == 1 and k.boulders == b0 and left.size() == 2,
		"launched %d swept %d boulders %d left %d" % [k.launches - l0, k.last_sweep, k.boulders - b0, left.size()]
	)
	ok(
		"tap: it is the nearest rock that went",
		left.all(func(w): return k.rock_mid(w).distance_to(p.pos) > near.distance_to(p.pos) + 0.5)
	)
	# the hold: the same row, every rock flies
	_row(m, p, k, home)
	l0 = k.launches
	_press(m, p, 0.95)
	step(m, 0.5)
	ok(
		"hold: the same row sends all three rocks",
		k.launches == l0 + 3 and k.last_sweep == 3 and rocks(m).is_empty(),
		"launched %d swept %d left %d" % [k.launches - l0, k.last_sweep, rocks(m).size()]
	)
	# nothing in reach: a tap is still the boulder
	b0 = k.boulders
	l0 = k.launches
	p.fire_cd = 0.0
	_press(m, p, 0.08)
	step(m, 0.3)
	ok(
		"tap, no rock in reach: the boulder",
		k.boulders == b0 + 1 and k.launches == l0,
		"boulders %d" % (k.boulders - b0)
	)
	print("PAIRCHECK tenzo-lmb-rock DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


## Clear his rocks, raise a fresh Stone Row and stand him at its end aiming along it.
func _row(m: Match, p: Hunter, k: DolmKit, home: Vector3) -> void:
	for w in rocks(m):
		HeroZones.remove_rock(m, w)
	p.teleport(home)
	p.vel = Vector3.ZERO
	aim_at(p, home + Vector3(10, 0, 0))      # Stone Row: three rocks side by side across the aim
	k.cd["e"] = 0.0
	k.use_e()
	step(m, 0.3)
	var zs: Array = rocks(m).map(func(w): return k.rock_mid(w).z)
	zs.sort()
	var lx: float = k.rock_mid(rocks(m)[1]).x
	p.teleport(Vector3(lx - 0.25, home.y, float(zs[0]) - 1.6))
	p.vel = Vector3.ZERO
	aim_at(p, Vector3(lx - 0.25, home.y, float(zs[0]) + 10.0))
	p.fire_cd = 0.0


func _nearest(m: Match, p: Hunter) -> Dictionary:
	var at := Vector2(p.pos.x, p.pos.z)
	var rs := rocks(m)
	rs.sort_custom(func(a, b): return (a["a"] as Vector2).distance_to(at) < (b["a"] as Vector2).distance_to(at))
	return rs[0]


## Hold the attack key for `secs`, then let go.
func _press(m: Match, p: Hunter, secs: float) -> void:
	p.inp["fire"] = true
	step(m, secs, func(): p.inp["fire"] = true)
	p.inp["fire"] = false
	m.step(DT)
