class_name ItemArt
extends RefCounted
## Sculpted item models (art/items/*.glb, the 11-12 Meshy pass): the painted texture under the game's toon
## light, times a tint (gear drops take their rarity colour, so their textures are neutral grey).
## Every maker returns null when the file is missing or --prim-art is on; callers keep their primitive.
## The GLBs are pivoted at the bottom centre, front to +z (the camera side).

const DIR := "res://art/items/%s.glb"
static var _scenes := {}

## The model `id` under `parent`, its base lifted by `y`. Returns the node, or null.
static func add(parent: Node3D, id: String, y := 0.0, tint := Color.WHITE, glow := 0.0) -> Node3D:
	if not Assets.on():
		return null
	if not _scenes.has(id):
		var path := DIR % id
		_scenes[id] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	var ps: PackedScene = _scenes[id]
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position.y = y
	parent.add_child(n)
	var mats: Array = []
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(si) as BaseMaterial3D
			var m := Models.toon(tint, true, glow)
			if src and src.albedo_texture:
				m.set_shader_parameter("use_tex", true)
				m.set_shader_parameter("albedo_tex", src.albedo_texture)
			mi.set_surface_override_material(si, m)
			mats.append(m)
	n.set_meta("mats", mats)
	return n

## A gear drop's spinning piece (slot 2 armor, 3 boots), centred on the spin; painted neutral grey, so it
## takes the drop's colour. False when there is no model for it.
static func gear(spin: Node3D, slot: int, col: Color) -> bool:
	if slot == 2:
		return add(spin, "gear_armor", -0.3, col, 0.55) != null
	return add(spin, "gear_boots", -0.27, col, 0.55) != null

## A loot gem, centred (it bobs about its middle); the primitive one is two mint prisms.
static func gem() -> Node3D:
	var root := Node3D.new()
	if add(root, "gem", -0.3, Color.WHITE, 0.25):
		return root
	var p := PrismMesh.new()
	p.size = Vector3(0.28, 0.3, 0.28)
	var m := Models.toon(Color("7ef0d0"), false, 0.7)
	Models.part(root, p, m, Vector3(0, 0.15, 0))
	Models.part(root, p, m, Vector3(0, -0.15, 0), Vector3.ONE, Vector3(PI, 0, 0))
	return root

## A healing tonic standing on its base; the primitive one is a mint ball with a neck and a cork.
static func tonic() -> Node3D:
	var root := Node3D.new()
	if add(root, "tonic", 0.0, Color.WHITE, 0.15):
		return root
	Models.part(root, Models.sphere(0.16, 12), Models.toon(Color("8ff0a0"), false, 0.6), Vector3(0, 0.16, 0))
	Models.part(root, Models.cyl(0.05, 0.06, 0.14, 8), Models.toon(Color("e6f2ea")), Vector3(0, 0.34, 0))
	Models.part(root, Models.cyl(0.065, 0.065, 0.05, 8), Models.toon(Color("8b6d52")), Vector3(0, 0.43, 0))
	return root
