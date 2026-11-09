class_name KeyModels
extends RefCounted
## The look of keys: the brass key on the ground, the small spinning glint over a monster that
## carries one, and the padlock hanging on a locked chest. All original, built from primitives.

const BRASS := Color("f2c84a")
const BRASS_DARK := Color("b8892a")

## A brass key lying or hovering: a round bow with a hole, a shaft and two teeth, with a soft halo.
static func key(size_k := 1.0, halo := true) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Key"
	body.scale = Vector3.ONE * size_k
	root.add_child(body)
	var gold := Models.toon(BRASS, true, 0.7)
	var dark := Models.toon(BRASS_DARK, true, 0.2)
	var hole := Models.toon(Color("2a2020"), false, 0.0)
	Models.part(body, Models.cyl(0.13, 0.13, 0.05, 14), gold, Vector3(0, 0.32, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
	Models.part(body, Models.cyl(0.06, 0.06, 0.056, 12), hole, Vector3(0, 0.32, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
	Models.part(body, Models.box(0.055, 0.34, 0.05), gold, Vector3(0, 0.07, 0))
	Models.part(body, Models.box(0.12, 0.05, 0.05), dark, Vector3(0.07, -0.04, 0))
	Models.part(body, Models.box(0.09, 0.05, 0.05), dark, Vector3(0.055, 0.05, 0))
	if halo:
		var h := MeshInstance3D.new()
		h.mesh = Models.flat_quad(0.8)
		h.material_override = Models.ring_mat(Color(BRASS, 0.75), 0.12)
		h.position.y = -0.05
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(h)
		root.add_child(Models.icon_badge("ckey", 0.95, 0.5))
	return root

## The pickup on the ground (a dropped key): the key, bobbing with the other pickups.
static func pickup() -> Node3D:
	return key(1.2, true)

## A padlock on a chest's front: big enough to read from the camera, hidden when the chest opens.
static func padlock() -> Node3D:
	var root := Node3D.new()
	root.name = "Lock"
	var gold := Models.toon(BRASS, true, 0.5)
	var dark := Models.toon(BRASS_DARK, true, 0.1)
	var hole := Models.toon(Color("1c1618"), false, 0.0)
	Models.part(root, Models.box(0.2, 0.17, 0.08), gold, Vector3(0, -0.02, 0))
	Models.part(root, Models.box(0.04, 0.09, 0.03), hole, Vector3(0, -0.02, -0.045))
	Models.part(root, Models.box(0.035, 0.13, 0.035), dark, Vector3(-0.065, 0.12, 0))
	Models.part(root, Models.box(0.035, 0.13, 0.035), dark, Vector3(0.065, 0.12, 0))
	Models.part(root, Models.box(0.165, 0.035, 0.035), dark, Vector3(0, 0.185, 0))
	return root
