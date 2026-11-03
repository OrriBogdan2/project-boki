class_name StallModels
extends RefCounted
## The market stall at each level (docs/decisions/0013-market.md), on its 3 x 2 tile footprint:
##   L1  a single vendor's stall
##   L2  a narrower counter with the shelter's little hut beside it (a paw on the door) and a
##       hanging trade sign: the Shelter, your own stall and search
##   L3  the auction bell on a tall post, bunting and a gold-trimmed awning: the Auction House

static func build(level: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Stall%d" % level
	if level <= 1:
		n.add_child(Models.stall())
		_crate(n, Vector3(1.25, 0, 0.55))
		return n
	var counter := Models.stall()
	counter.position = Vector3(0.38, 0, 0)
	counter.scale = Vector3(0.74, 1, 1)
	n.add_child(counter)
	_hut(n, Vector3(-1.02, 0, 0.05))
	_sign(n, Vector3(0.38, 1.62, -0.52), level)
	if level >= 3:
		_bell(n, Vector3(1.22, 0, 0.62))
		_bunting(n)
	return n

static func _crate(n: Node3D, at: Vector3) -> void:
	var wood := Models.toon(Color("a07850"))
	Models.part(n, Models.box(0.5, 0.42, 0.5), wood, at + Vector3(0, 0.21, 0))
	Models.part(n, Models.box(0.52, 0.06, 0.52), Models.toon(Color("6b4a2e")), at + Vector3(0, 0.44, 0))
	Models.part(n, Models.sphere(0.1, 8), Models.toon(Color("ff6a4a")), at + Vector3(-0.1, 0.52, 0.05))
	Models.part(n, Models.sphere(0.1, 8), Models.toon(Color("f2c84a")), at + Vector3(0.11, 0.52, -0.06))

## The shelter's hut: plank walls, a pitched roof, a round doorway with a paw over it, straw inside.
static func _hut(n: Node3D, at: Vector3) -> void:
	var wall := Models.toon(Color("c89a6a"))
	var roof := Models.toon(Color("5a8ac8"))
	Models.part(n, Models.box(0.86, 0.78, 0.9), wall, at + Vector3(0, 0.39, 0))
	for sx in [-1.0, 1.0]:
		Models.part(n, Models.box(0.58, 0.07, 1.02), roof, at + Vector3(sx * 0.24, 0.93, 0), Vector3.ONE,
			Vector3(0, 0, -sx * 0.62))
	Models.part(n, Models.box(0.1, 0.08, 1.04), Models.toon(Color("3d5f8f")), at + Vector3(0, 1.1, 0))
	Models.part(n, Models.cyl(0.21, 0.21, 0.04, 16), Models.toon(Color("2a1e18"), false), at + Vector3(0, 0.3, -0.45),
		Vector3(1, 1, 1.25), Vector3(PI / 2, 0, 0))
	Models.part(n, Models.box(0.42, 0.06, 0.12), Models.toon(Color("e8c870"), false), at + Vector3(0, 0.04, -0.5))
	var paw := Models.toon(Color("fff2e0"), false, 0.3)
	Models.part(n, Models.sphere(0.075, 8), paw, at + Vector3(0, 0.66, -0.46), Vector3(1.2, 1, 0.4))
	for i in 3:
		Models.part(n, Models.sphere(0.035, 6), paw, at + Vector3(-0.07 + i * 0.07, 0.75, -0.46), Vector3(1, 1, 0.4))

## A hanging board over the counter: a gem for trade (gold-edged at L3).
static func _sign(n: Node3D, at: Vector3, level: int) -> void:
	var wood := Models.toon(Color("6b4a2e"))
	var gilded := level >= 3
	var edge := Models.toon(Color("f2c84a"), true, 0.3) if gilded else Models.toon(Color("8a5a35"))
	Models.part(n, Models.box(0.72, 0.34, 0.05), edge, at)
	Models.part(n, Models.box(0.64, 0.26, 0.06), wood, at)
	var gem := Models.toon(Color("5ad0f0"), false, 0.8)
	Models.part(n, Models.sphere(0.09, 4), gem, at + Vector3(0, 0, -0.04), Vector3(1, 1.3, 0.5))
	for sx in [-0.26, 0.26]:
		Models.part(n, Models.cyl(0.008, 0.008, 0.36, 4), wood, at + Vector3(sx, 0.34, 0))

## The auction bell: a tall post behind the counter with a gold bell under a little roof.
static func _bell(n: Node3D, at: Vector3) -> void:
	var wood := Models.toon(Color("5a3a24"))
	var gold := Models.toon(Color("f2c84a"), true, 0.5)
	Models.part(n, Models.cyl(0.06, 0.07, 2.7, 8), wood, at + Vector3(0, 1.35, 0))
	Models.part(n, Models.box(0.62, 0.06, 0.06), wood, at + Vector3(0, 2.55, 0))
	Models.part(n, Models.cyl(0.08, 0.2, 0.3, 14), gold, at + Vector3(0, 2.32, 0))
	Models.part(n, Models.sphere(0.05, 8), gold, at + Vector3(0, 2.14, 0))
	var cap := Models.toon(Color("b03a4a"))
	Models.part(n, Models.cyl(0.0, 0.4, 0.26, 4), cap, at + Vector3(0, 2.76, 0), Vector3.ONE, Vector3(0, PI / 4, 0))
	var lt := OmniLight3D.new()
	lt.light_color = Color("ffe0a0")
	lt.light_energy = 0.5
	lt.omni_range = 2.6
	lt.position = at + Vector3(0, 2.2, -0.3)
	n.add_child(lt)

## Bunting from the bell post to the hut's roof and to the stall's far post.
static func _bunting(n: Node3D) -> void:
	var cols := [Color("e0607e"), Color("f2c84a"), Color("5ab0f0"), Color("8fd16a")]
	var top := Vector3(1.22, 2.52, 0.62)
	var ends := [[top, Vector3(-1.02, 1.12, 0.05)], [top, Vector3(-0.2, 2.1, -0.35)]]
	for pair in ends:
		var a: Vector3 = pair[0]
		var b: Vector3 = pair[1]
		for i in 6:
			var t := (float(i) + 0.5) / 6.0
			var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.22, 0)
			var flag := Models.toon(cols[i % cols.size()], false)
			Models.part(n, Models.cyl(0.0, 0.07, 0.14, 3), flag, p - Vector3(0, 0.07, 0),
				Vector3(1, 1, 0.3), Vector3(PI, 0, 0))
