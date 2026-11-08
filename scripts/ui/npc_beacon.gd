class_name NpcBeacon
extends Node3D
## What makes an NPC read from the top-down camera (content/rules/npc_talk.json): a soft glowing outline
## round its model (brighter while you are close enough to talk), its name over its head, and an arrow at
## the edge of the screen pointing to it while it is off screen and has something for you. It rides on the
## NPC's model as a child named NODE_NAME; the owner sets `lit` and `wants_arrow`.

const NODE_NAME := "Beacon"
const GLOW_DIM := 0.35       # outline strength from afar
const GLOW_LIT := 1.0        # ...and while you are in talking reach
const GLOW_EASE := 6.0       # 1/s
const ARROW_PX := 16.0       # px: the arrow's length
const ARROW_LABEL_PX := 34.0 # px: the name sits this far in from the arrow

var lit := false
var wants_arrow := false
var head := 2.0              # m above the feet the arrow points at
var _glow: ShaderMaterial
var _strength := GLOW_DIM
var _arrow: Control
var _arrow_tip: Polygon2D
var _arrow_name: Label

## Puts a beacon on `model` for the speaker `id`.
static func attach(model: Node3D, id: String) -> NpcBeacon:
	var sp := NpcDialogue.speaker(id)
	var b := NpcBeacon.new()
	b.name = NODE_NAME
	b.head = float(sp["head"])
	model.add_child(b)
	b._outline(model, Color(String(sp["glow"])))
	b._name_tag(String(sp["name"]), float(sp["tag"]) / model.scale.y)
	b._make_arrow(String(sp["short"]))
	return b

func _process(dt: float) -> void:
	_strength = lerpf(_strength, GLOW_LIT if lit else GLOW_DIM, 1.0 - exp(-GLOW_EASE * dt))
	_glow.set_shader_parameter("strength", _strength)
	_place_arrow()

## The glow shell (the kin aura) as a second pass on every part of the model.
func _outline(model: Node3D, col: Color) -> void:
	_glow = ShaderMaterial.new()
	_glow.shader = Models.AURA
	_glow.set_shader_parameter("color", col)
	_glow.set_shader_parameter("strength", GLOW_DIM)
	_glow.set_shader_parameter("grow", 0.03)
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var mat := (part as MeshInstance3D).material_override
		if mat:
			mat.next_pass = _glow

func _name_tag(text: String, at_y: float) -> void:
	var tag := Label3D.new()
	tag.text = text
	tag.font_size = 40
	tag.pixel_size = 0.0085
	tag.outline_size = 12
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, at_y, 0)
	add_child(tag)

## The arrow, on a canvas layer of its own under the HUD (layer 0: over the world, under the panels).
func _make_arrow(short_name: String) -> void:
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	_arrow_tip = Polygon2D.new()
	_arrow_tip.polygon = PackedVector2Array([Vector2(ARROW_PX, 0), Vector2(-ARROW_PX * 0.6, -ARROW_PX * 0.7),
			Vector2(-ARROW_PX * 0.6, ARROW_PX * 0.7)])
	_arrow_tip.color = UI.GOLD
	_arrow.add_child(_arrow_tip)
	_arrow_name = UI.label(short_name, UI.T_SMALL, UI.INK, UI.semi)
	_arrow_name.add_theme_constant_override("outline_size", 6)
	_arrow_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_arrow.add_child(_arrow_name)
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	layer.add_child(_arrow)

## The arrow sits where the line from the screen's middle to the NPC leaves the screen, pointing out.
func _place_arrow() -> void:
	var cam := get_viewport().get_camera_3d()
	if not wants_arrow or cam == null:
		_arrow.visible = false
		return
	var at := global_position + Vector3(0, head, 0)
	var rect := get_viewport().get_visible_rect()
	var behind := cam.is_position_behind(at)
	var on_screen := cam.unproject_position(at)
	if not behind and rect.has_point(on_screen):
		_arrow.visible = false
		return
	var mid := rect.size * 0.5
	var dir := (on_screen - mid) * (-1.0 if behind else 1.0)
	if dir.length_squared() < 1.0:
		dir = Vector2.DOWN
	dir = dir.normalized()
	var room := mid - Vector2.ONE * float(NpcDialogue.rules()["arrow_margin"])
	var reach := minf(room.x / maxf(absf(dir.x), 0.001), room.y / maxf(absf(dir.y), 0.001))
	_arrow.visible = true
	_arrow.position = mid + dir * reach
	_arrow_tip.rotation = dir.angle()
	_arrow_name.position = -dir * ARROW_LABEL_PX - _arrow_name.size * 0.5
