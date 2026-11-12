class_name GlintFx
extends RefCounted
## The looks of Glint Fishing, drawn with the shared cel pass (shaders/glint_water.gdshader). One flat quad a look
## on the rock, recipes in content/rules/glint_fishing_vfx.json: a small ripple where the bobber lands, rings
## that close in while the ears are up, a sharp splash on the bite, a glint on a catch sized by what came up.
## Nothing here changes what the game does; it only shows the line's moments.

const WATER_LIFT := 0.02            # m above the water sheet, so a ripple never flickers against it
const SEED_MAX := 100.0             # the shader's ring seed range (whole turns of the tiling noise)

const KEYS := ["plop", "wait", "bite", "catch"]  # the recipes in glint_fishing_vfx.json

static var shader: Shader = preload("res://shaders/glint_water.gdshader")

var _nodes: Dictionary = {}         # recipe key -> its MeshInstance3D
var _age: Dictionary = {}           # recipe key -> s since it played (one-shot looks)
var _base: Dictionary = {}          # recipe key -> where its one-shot look was played (rock-local)

func _init(parent: Node3D) -> void:
	for key in KEYS:
		var rec: Dictionary = recipes()[key]
		var node := MeshInstance3D.new()
		node.mesh = QuadMesh.new() if rec["look"] == "glint" else PlaneMesh.new()
		node.material_override = ShaderMaterial.new()
		node.material_override.shader = shader
		node.material_override.set_shader_parameter("look", look_id(rec["look"]))
		node.visible = false
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		_nodes[key] = node

static func recipes() -> Dictionary:
	return Content.rules("glint_fishing_vfx")

## The shader's look number for a recipe's look name.
static func look_id(look: String) -> int:
	return ["ripple", "tight", "splash", "glint"].find(look)

## Which size a catch draws at: rare, else the kind of what came up (snack or item).
static func catch_size_key(catch_entry: Dictionary, rare: bool) -> String:
	return "rare" if rare else String(catch_entry.get("kind", "snack"))

## A look's quad (visible while it is on the water).
func node_of(key: String) -> MeshInstance3D:
	return _nodes[key]

## Plays a one-shot look at a point (rock-local, on the water); `size_key` picks a catch's size and tint.
func play(key: String, at: Vector3, size_key := "") -> void:
	var rec: Dictionary = recipes()[key]
	var node: MeshInstance3D = _nodes[key]
	var half_w: float = float(rec["size"][size_key]) if rec["size"] is Dictionary else float(rec["size"])
	var rare := size_key == "rare"
	_base[key] = at + Vector3(0.0, WATER_LIFT, 0.0)
	node.scale = Vector3.ONE * half_w
	_paint(node.material_override, rec, rare)
	node.material_override.set_shader_parameter("seed", randf() * SEED_MAX)
	_age[key] = 0.0
	_set_life(key, 0.0)
	node.visible = true

func _paint(mt: ShaderMaterial, rec: Dictionary, rare: bool) -> void:
	mt.set_shader_parameter("col", Color(String(rec["rare_c"] if rare else rec["c"])))
	mt.set_shader_parameter("col2", Color(String(rec["rare_c2"] if rare else rec["c2"])))

func _set_life(key: String, life: float) -> void:
	var node: MeshInstance3D = _nodes[key]
	node.material_override.set_shader_parameter("life", life)
	var rise: float = float(recipes()[key].get("rise", 0.0))
	node.position = _base[key] + Vector3(0.0, rise * life, 0.0)

## The waiting rings round the bobber, `close` 0 (wide, faint) to 1 (closed on it).
func wait_rings(at: Vector3, close: float) -> void:
	var rec: Dictionary = recipes()["wait"]
	var node: MeshInstance3D = _nodes["wait"]
	if not node.visible:
		_paint(node.material_override, rec, false)
		node.material_override.set_shader_parameter("rest", float(rec["rest"]))
		node.material_override.set_shader_parameter("core", float(rec["close"]))
		node.material_override.set_shader_parameter("rings", int(rec["rings"]))
		node.scale = Vector3.ONE * float(rec["size"])
		node.visible = true
	node.position = at + Vector3(0.0, WATER_LIFT, 0.0)
	node.material_override.set_shader_parameter("close", close)

func hide_wait() -> void:
	_nodes["wait"].visible = false

## Ages the one-shot looks; each hides when its life is spent.
func tick(d: float) -> void:
	for key in _age:
		var node: MeshInstance3D = _nodes[key]
		if not node.visible:
			continue
		_age[key] += d
		var life: float = _age[key] / float(recipes()[key]["life"])
		if life >= 1.0:
			node.visible = false
		else:
			_set_life(key, life)

func hide_all() -> void:
	for node in _nodes.values():
		node.visible = false
