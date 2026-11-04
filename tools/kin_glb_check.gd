extends RefCounted
## --kin-glb-check: a Boki species drawn from a 3D model (KinGlb) still works like a procedural one.
##   1. the model builds, and has the nodes KinPuppet animates (Body/Flex, Tail, Ears, Legs/Leg0..3)
##   2. every surface is on a textured hero-toon material, listed in the kin's `mats` (hit flashes reach it)
##   3. KinPuppet finds its tail, ears and four legs, and a short run of frames moves them
##   4. a shimmer tints the painted atlas, and a species with no model keeps its primitives
##   5. the model is chunky and small enough: about a Boki tall, a few thousand triangles
## Prints KINGLB lines and "KINGLB DONE, failures: n".

const SPECIES := ["pebbit"]

var fails := 0

func ok(what: String, cond: bool, info := "") -> void:
	print("KINGLB %-62s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main: Node) -> void:
	for id in SPECIES:
		_species(main, String(id))
	var plain := Models.kin("cindle")
	var parts := plain.find_children("*", "MeshInstance3D", true, false).size()
	ok("a species without a model keeps its primitives", parts > 20)
	plain.free()
	print("KINGLB DONE, failures: %d" % fails)
	main.get_tree().quit()

func _species(main: Node, id: String) -> void:
	ok("%s has a model" % id, KinGlb.has(id))
	var kin := Models.kin(id)
	main.add_child(kin)
	var flex := kin.get_node("Body/Flex")
	var has_tail := flex.find_child("Tail", true, false) != null
	ok("%s: Tail and Ears" % id, has_tail and flex.find_child("Ears", true, false) != null)
	var legs := flex.find_child("Legs", true, false)
	var names := legs.get_children().map(func(n): return String(n.name)) if legs else []
	names.sort()
	ok("%s: Leg0..Leg3" % id, names == ["Leg0", "Leg1", "Leg2", "Leg3"], str(names))
	var tris := 0
	var textured := true
	for mi in kin.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.name == "Shell" or inst.mesh == null or inst.mesh is SphereMesh:
			continue
		tris += inst.mesh.get_faces().size() / 3
		for si in inst.mesh.get_surface_count():
			var m := inst.get_surface_override_material(si) as ShaderMaterial
			textured = textured and m != null and m.get_shader_parameter("use_tex") == true
	ok("%s: every surface is a textured hero-toon material" % id, textured)
	ok("%s: a few thousand triangles" % id, tris > 3000 and tris < 40000, "%d" % tris)
	var puppet := KinPuppet.new()
	puppet.species = id
	kin.add_child(puppet)
	var found := puppet.tail != null and puppet.ears != null and puppet.legs.size() == 4
	ok("%s: KinPuppet finds tail, ears and four legs" % id, found)
	var before := (puppet.legs[0] as Node3D).rotation
	for k in 30:
		puppet._process(1.0 / 60.0)
	kin.position.x += 1.0
	for k in 30:
		puppet._process(1.0 / 60.0)
	ok("%s: walking swings a leg" % id, (puppet.legs[0] as Node3D).rotation != before)
	var box := _bounds(kin)
	ok("%s: about a Boki tall" % id, box.size.y > 0.3 and box.size.y < 1.0, "%.2f m" % box.size.y)
	kin.free()
	var shiny := Models.kin(id, {"shimmer": true})
	var body := _first_material(shiny)
	var normal := Models.kin(id)
	var plain_albedo = _first_material(normal).get_shader_parameter("albedo")
	ok("%s: a shimmer tints the atlas" % id, body != null and body.get_shader_parameter("albedo") != plain_albedo)
	shiny.free()
	normal.free()

func _first_material(kin: Node) -> ShaderMaterial:
	for mi in kin.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
		if m != null and m.get_shader_parameter("use_tex") == true:
			return m
	return null

func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null or inst.mesh is SphereMesh:
			continue
		var b := inst.global_transform * inst.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
