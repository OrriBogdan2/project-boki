class_name MeshyKin
extends Node
## A Boki drawn from a game-ready Meshy model: a static mesh (tools/blender/meshy_gameready.py, about 8k triangles, feet
## on y=0, front toward -Z) wearing its baked colour atlas under the Boki toon light and
## ink outline. It has no skeleton:
## KinPuppet's squash, lean and hop (and Flex) move it. Which species wear one, and where the files are, lives in
## content/kin_models.json, one row per kin id, so a model is swapped by changing its row (or deleting the row to
## fall back to the old rig or primitives). A row's "redo" marks a model queued for a Meshy redo.
## Added under Flex as "M3d" (Evo.dress leaves its mutation parts off it), with this node beside it as "MeshyKin".

const TABLE := "res://content/kin_models.json"
const INK_WIDTH := 0.0011
const INK_FAR_THIN := 0.5
const COAT_LOOK := {"far_lift": 0.12, "fres": 0.55, "top_light": 0.45, "rim_amount": 0.25}

static var enabled := true
static var _rows: Dictionary
static var _loaded := false

var species := ""
var model: Node3D
var _coat: ShaderMaterial

## kin id -> model row (glb, atlas, redo, frame, tris).
static func rows() -> Dictionary:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(TABLE, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_rows = (parsed as Dictionary).get("kin", {})
	return _rows

## True when this kin id has a Meshy model row whose files exist.
static func has(kin_id: String) -> bool:
	if not enabled or not rows().has(kin_id):
		return false
	var r: Dictionary = rows()[kin_id]
	return ResourceLoader.exists(String(r["glb"])) and ResourceLoader.exists(String(r["atlas"]))

## Adds the model under `flex_node` and its driver beside it. Returns the head frame, as KinModels.build.
static func build(kin_id: String, flex_node: Node3D, c: Dictionary, mats: Array) -> Dictionary:
	var row: Dictionary = rows()[kin_id]
	var m3d := (load(String(row["glb"])) as PackedScene).instantiate() as Node3D
	m3d.name = "M3d"
	flex_node.add_child(m3d)
	var node := MeshyKin.new()
	node.name = "MeshyKin"
	node.species = kin_id
	node.model = m3d
	node._dress(load(String(row["atlas"])) as Texture2D, c, mats)
	flex_node.add_child(node)
	return frame_of(row)

## The row's frame as KinModels' head frame (Vector3s from [x, y, z] arrays).
static func frame_of(row: Dictionary) -> Dictionary:
	var fr: Dictionary = (row.get("frame", {}) as Dictionary).duplicate()
	for k in fr:
		if fr[k] is Array:
			var a: Array = fr[k]
			fr[k] = Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fr

func _ready() -> void:
	_copy_coat()

func _dress(atlas: Texture2D, c: Dictionary, _mats: Array) -> void:
	var m := Models.toon(Color.WHITE, false)
	Models.hero_look(m)
	m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("albedo_tex", atlas)
	for k in WardenGlb.PAINTED:
		m.set_shader_parameter(k, WardenGlb.PAINTED[k])
	for k in COAT_LOOK:
		m.set_shader_parameter(k, COAT_LOOK[k])
	m.set_shader_parameter("rim_color", (c["body"] as ShaderMaterial).get_shader_parameter("rim_color"))
	var ink := ShaderMaterial.new()
	ink.shader = Models.OUTLINE
	ink.set_shader_parameter("width", INK_WIDTH)
	ink.set_shader_parameter("far_thin", INK_FAR_THIN)
	m.next_pass = ink
	_coat = m
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in inst.mesh.get_surface_count():
			inst.set_surface_override_material(si, m)

## A shimmer's or an evolved form's colour shift, and coat marks, land on KinModels' body material
## (Unique.dress, after build): take them on, as BokiRig does.
func _copy_coat() -> void:
	var root := get_parent().get_parent().get_parent() as Node3D
	var mats: Array = root.get_meta("mats", [])
	if mats.is_empty() or _coat == null:
		return
	var body := mats[0] as ShaderMaterial
	var base: Color = Data.KIN[species]["color"]
	var now := body.get_shader_parameter("albedo") as Color
	_coat.set_shader_parameter("albedo", BokiRig._tint(now, base))
	if body.get_shader_parameter("mark_kind") == null:
		return
	var marks := ShaderMaterial.new()
	marks.shader = preload("res://shaders/boki_marks.gdshader")
	for k in ["mark_kind", "mark_color", "mark_seed", "mark_scale", "mark_amt", "mark_glow"]:
		marks.set_shader_parameter(k, body.get_shader_parameter(k))
	marks.next_pass = _coat.next_pass
	_coat.next_pass = marks
