class_name GearModels
extends RefCounted
## What gear and weapon tunings look like lying on the ground: the usual rarity beam and ring
## (Models.gear_drop), with a small shape of the piece spinning above it so you can tell armor from
## boots from across a room. Gloves keep the old gem token.

## slot: Gear slot index (0/1 gloves, 2 armor, 3 boots).
static func drop(slot: int, col: Color, rar: int) -> Node3D:
	var root := Models.gear_drop(col, rar)
	if slot < 2:
		return root
	var spin: Node3D = root.get_node("Spin")
	for ch in spin.get_children():
		ch.queue_free()
	var rc: Color = Data.RARITY[clampi(rar, 0, Data.RARITY.size() - 1)]["color"]
	var body := Models.toon(col, true, 0.55)
	var trim := Models.toon(rc, true, 0.8)
	match slot:
		2:   # a breastplate: a chest block, shoulder bosses, a bright trim band
			Models.part(spin, Models.box(0.46, 0.5, 0.26), body, Vector3(0, 0.02, 0))
			Models.part(spin, Models.sphere(0.14, 8), body, Vector3(-0.3, 0.2, 0))
			Models.part(spin, Models.sphere(0.14, 8), body, Vector3(0.3, 0.2, 0))
			Models.part(spin, Models.box(0.5, 0.07, 0.3), trim, Vector3(0, -0.14, 0))
		3:   # a boot: a shaft, a toe and a heel
			Models.part(spin, Models.box(0.2, 0.42, 0.22), body, Vector3(-0.04, 0.08, 0))
			Models.part(spin, Models.box(0.36, 0.14, 0.22), body, Vector3(0.08, -0.16, 0))
			Models.part(spin, Models.box(0.22, 0.06, 0.24), trim, Vector3(-0.04, 0.3, 0))
	return root

## A weapon tuning: a small bright core in a spinning ring, bigger and tinted for a Brand.
static func tuning(col: Color, brand: bool) -> Node3D:
	var root := Models.gear_drop(col, 3 if brand else 2)
	var spin: Node3D = root.get_node("Spin")
	for ch in spin.get_children():
		ch.queue_free()
	var k := 1.35 if brand else 1.0
	Models.part(spin, Models.sphere(0.2 * k, 10), Models.toon(col, true, 1.0), Vector3(0, 0, 0))
	var t := TorusMesh.new(); t.inner_radius = 0.3 * k; t.outer_radius = 0.34 * k
	Models.part(spin, t, Models.toon(Color.WHITE, true, 0.8), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2.4, 0, 0))
	var t2 := TorusMesh.new(); t2.inner_radius = 0.3 * k; t2.outer_radius = 0.34 * k
	Models.part(spin, t2, Models.toon(col.lightened(0.3), true, 0.8), Vector3.ZERO, Vector3.ONE, Vector3(-PI / 2.4, PI / 2, 0))
	return root
