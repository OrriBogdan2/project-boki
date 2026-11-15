class_name WispLook
extends RefCounted
## What a downed Hunter turns into: a Wisp, built from data. A look is an entry in
## content/rules/wisp_looks.json (colours, body size, hover, drift, hum, pop effects), picked by its id in
## Save.d["look"]["wisp"]; a look only lists what it changes from "default". Adding a Wisp needs no code.
## Every Wisp keeps the owner's outline rule: a round "person" (a round body with a head), team colour rim,
## white core, steady glow (round = Hunter, critter = Boki). HunterWisp plays it; this file reads the data
## and builds the body: one mesh, one material, so thirty of them stay cheap.

const RULES_PATH := "res://content/rules/wisp_looks.json"
const SHADER := preload("res://shaders/wisp_core.gdshader")
const SEGMENTS := 24      # sphere radial segments; the rim shader does the work, the mesh stays light
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

## A colour spec from the data: "team" is the hunter's team colour, anything else a hex string.
static func colour(spec: String, team_col: Color) -> Color:
	return team_col if spec == "team" else Color(spec)

## The body of a Wisp (a Node3D at its hover point) with one child, Body: a single mesh in a single
## material. The material is in the node's meta "mat" so HunterWisp can flash and fade it.
static func build(look: Dictionary, team_col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Wisp"
	var core: Dictionary = look["core"]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("rim_col", colour(String(core["rim"]), team_col))
	mat.set_shader_parameter("core_col", colour(String(core["color"]), team_col))
	mat.set_shader_parameter("rim", float(core["rim_width"]))
	mat.set_shader_parameter("glow", float(core["glow"]))
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _mesh(look["body"])
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	root.set_meta("mat", mat)
	return root

## The round "person": a squashed round body with a smaller head sunk into its top, merged into one
## mesh and shared by every Wisp with the same body spec.
static func _mesh(spec: Dictionary) -> ArrayMesh:
	var key := JSON.stringify(spec)
	if _meshes.has(key):
		return _meshes[key]
	var radius := float(spec["radius"])
	var squash := float(spec["squash"])
	var head := float(spec["head"])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(_sphere(radius), 0, Transform3D(Basis.from_scale(Vector3(1.0, squash, 1.0)), Vector3.ZERO))
	var head_at := Vector3(0.0, radius * squash + head * 0.6, 0.0)
	tool.append_from(_sphere(head), 0, Transform3D(Basis.IDENTITY, head_at))
	var mesh := tool.commit()
	_meshes[key] = mesh
	return mesh

static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = SEGMENTS
	mesh.rings = RINGS
	return mesh
