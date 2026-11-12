class_name WispLook
extends RefCounted
## What a downed Hunter turns into: a Wisp, built from data. A skin is an entry in
## content/rules/wisp_looks.json (body colours and surface, size, plume, drift, hum, pop effects), picked by
## its id in Save.d["look"]["wisp"]; a skin only lists what it changes from "default". A new skin needs no
## code. Every Wisp is a chubby round body sitting on the ground with a tiny face (round = Hunter, critter =
## Boki) under a see-through plume; the plume and the body's outline are the viewer's relation colour
## (SideColor), whatever the skin. HunterWisp plays it; this file reads the data and builds it: two meshes,
## two materials, so thirty of them stay cheap.

const RULES_PATH := "res://content/rules/wisp_looks.json"
const SHADER := preload("res://shaders/wisp_core.gdshader")
const PLUME := preload("res://shaders/wisp_plume.gdshader")
const SEGMENTS := 24      # sphere radial segments; the shader does the work, the mesh stays light
const RINGS := 12

static var _rules := {}
static var _meshes := {}      # body spec (as a string) -> the shared ArrayMesh

## All look entries by id (the file, read once).
static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules

## The look for an id with every key filled in; an unknown id gives the default Wisp.
static func get_look(id: String) -> Dictionary:
	var looks: Dictionary = rules()["looks"]
	var base: Dictionary = looks[String(rules()["default"])]
	if id == "" or not looks.has(id):
		return base
	return _merged(base, looks[id])

static func _merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in over:
		if out.get(key) is Dictionary and over[key] is Dictionary:
			out[key] = _merged(out[key], over[key])
		else:
			out[key] = over[key]
	return out

## The id the local player wears, from their saved look.
static func equipped() -> String:
	var id := String(Save.d.get("look", {}).get("wisp", ""))
	return id if (rules()["looks"] as Dictionary).has(id) else String(rules()["default"])

## Wear a Wisp from now on. False for an id with no look.
static func equip(id: String) -> bool:
	if not (rules()["looks"] as Dictionary).has(id):
		return false
	if not Save.d.has("look"):
		Save.d["look"] = Unmasked.default_look()
	Save.d["look"]["wisp"] = id
	return true

## The body shader's surfaces, by its `style` index (an unknown name is plain).
const STYLES := ["plain", "glitch", "ember"]

## Where the body's centre sits over the hunter's feet: on the ground, sunk in a little.
static func hover(look: Dictionary) -> float:
	var body: Dictionary = look["body"]
	return float(body["radius"]) * float(body["squash"]) - float(body["sink"])

## A Wisp (a Node3D at the body's centre) with two children: Body, the round soul in the skin's material,
## and Plume, the see-through flame over it. Both carry the relation colour `side_col` (recolour() changes
## it); the materials are in the node's metas "mat" and "plume" so HunterWisp can flash and fade them.
static func build(look: Dictionary, side_col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Wisp"
	var core: Dictionary = look["core"]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("body_col", Color(String(core["color"])))
	mat.set_shader_parameter("shade_col", Color(String(core["shade"])))
	mat.set_shader_parameter("face_col", Color(String(core["face"])))
	mat.set_shader_parameter("glow_col", Color(String(core["glow_col"])))
	mat.set_shader_parameter("style", maxi(0, STYLES.find(String(core["style"]))))
	mat.set_shader_parameter("rim", float(core["rim_width"]))
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _mesh(look["body"])
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	root.set_meta("mat", mat)
	root.add_child(_plume(look, root))
	recolour(root, side_col)
	return root

## Tints a built Wisp's outline and plume (the viewer's relation to its hunter).
static func recolour(node: Node3D, side_col: Color) -> void:
	(node.get_meta("mat") as ShaderMaterial).set_shader_parameter("rim_col", side_col)
	(node.get_meta("plume") as ShaderMaterial).set_shader_parameter("col", side_col)

## The flame: one quad that faces the camera (the shader turns it), its base at the body's bottom edge on
## screen, with the body cut out of it so the body sits in the flame.
static func _plume(look: Dictionary, root: Node3D) -> MeshInstance3D:
	var spec: Dictionary = look["plume"]
	var body: Dictionary = look["body"]
	var mat := ShaderMaterial.new()
	mat.shader = PLUME
	mat.set_shader_parameter("alpha", float(spec["alpha"]))
	mat.set_shader_parameter("speed", float(spec["speed"]))
	mat.set_shader_parameter("rise", float(spec["height"]) * 0.5 - float(body["radius"]) * float(body["squash"]))
	mat.set_shader_parameter("lift", float(body["radius"]))
	mat.set_shader_parameter("hole", float(body["radius"]))
	var quad := QuadMesh.new()
	quad.size = Vector2(float(spec["width"]), float(spec["height"]))
	var plume := MeshInstance3D.new()
	plume.name = "Plume"
	plume.mesh = quad
	plume.material_override = mat
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("plume", mat)
	return plume

## The chubby round body: one squashed sphere, shared by every Wisp with the same body spec.
static func _mesh(spec: Dictionary) -> SphereMesh:
	var key := JSON.stringify(spec)
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = float(spec["radius"])
		mesh.height = mesh.radius * 2.0 * float(spec["squash"])
		mesh.radial_segments = SEGMENTS
		mesh.rings = RINGS
		_meshes[key] = mesh
	return _meshes[key]
