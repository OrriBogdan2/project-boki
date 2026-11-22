class_name IncubatorCradle
extends RefCounted
## One cradle of the Incubator (Models.incubator): a stone base, a straw nest, six ember pebbles ("P0".."P5"), the
## egg anchor ("Egg") and an iron grate ("Lock", shown while the cradle isn't bought). The named parts are the ones
## HomeIncubator finds and changes. Models.incubator copies one built cradle eight times.

static func build(stone: Material, straw: Material, pebble: Material, iron: Material) -> Node3D:
	var c := Node3D.new()
	Models.part(c, Models.cyl(0.14, 0.16, 0.1, 12), stone, Vector3(0, 0.05, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.06
	ring.outer_radius = 0.14
	ring.rings = 14
	ring.ring_segments = 7
	Models.part(c, ring, straw, Vector3(0, 0.13, 0), Vector3(1.0, 0.6, 1.0), Vector3.ZERO, "Nest")
	for j in 6:
		var b := PI * (0.18 + 0.64 * float(j) / 5.0)
		var at := Vector3(cos(b) * 0.17, 0.02, sin(b) * 0.17)
		Models.part(c, Models.sphere(0.028, 6), pebble, at, Vector3(1.2, 0.7, 1.2), Vector3.ZERO, "P%d" % j)
	var egg := Node3D.new()
	egg.name = "Egg"
	egg.position = Vector3(0, 0.08, 0)
	c.add_child(egg)
	var lock := Node3D.new()
	lock.name = "Lock"
	lock.visible = false
	c.add_child(lock)
	for k in 3:
		Models.part(lock, Models.box(0.24, 0.02, 0.025), iron, Vector3(0, 0.12, -0.07 + k * 0.07))
	return c
