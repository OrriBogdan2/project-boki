class_name SeatBeacon
extends RefCounted
## One way-out seat's far-read marker: a column, a ground ring at the seat's real radius and a countdown glyph.
## Built once with its own two materials (pooled: nothing is created after setup) and re-looked by show();
## the look is only pushed to the materials when it changes. WaysOutLook decides which look.

const BEAM_R := 0.8               # m, the column's radius
const GLYPH_Y := 6.5              # m above the seat
const GLYPH_PX := 0.0016          # fixed-size glyph: share of the screen height per font pixel
const FILL := 0.16                # the ring's pad (a soft disc inside the ring, so the seat reads from afar)
const BEAM := preload("res://shaders/seat_beam.gdshader")

var node: Node3D
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _glyph: Label3D
var _key := []                     # what the materials show now: [look, colour, hold]
var _h := 0.0                      # the column's height now (it eases to the look's height)
var _clock := -1

func _init(parent: Node3D, at: Vector3, radius: float) -> void:
	node = Node3D.new()
	node.position = at
	parent.add_child(node)
	_ring_mat = Models.ring_mat(WaysOutLook.DIM, 0.1)
	_ring_mat.set_shader_parameter("fill", FILL)
	var ring := MeshInstance3D.new()
	ring.mesh = Models.flat_quad(radius * 2.2)
	ring.material_override = _ring_mat
	ring.position = Vector3(0, 0.14, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(ring)
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = BEAM
	var cyl := CylinderMesh.new()
	cyl.top_radius = BEAM_R * 0.6
	cyl.bottom_radius = BEAM_R
	cyl.height = 1.0
	cyl.radial_segments = 10
	cyl.rings = 1
	_beam = MeshInstance3D.new()
	_beam.mesh = cyl
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(_beam)
	_glyph = Label3D.new()
	_glyph.font = UI.big
	_glyph.font_size = 48
	_glyph.outline_size = 14
	_glyph.outline_modulate = Color(0.1, 0.1, 0.14, 0.9)
	_glyph.modulate = Color("eef2ff")
	_glyph.pixel_size = GLYPH_PX
	_glyph.fixed_size = true
	_glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glyph.no_depth_test = true
	_glyph.position = Vector3(0, GLYPH_Y, 0)
	node.add_child(_glyph)

## The look for this reading. Cheap to call every tick: it touches the materials only when something changed.
func show(rd: Dictionary, dt: float) -> void:
	var st := int(rd["st"])
	var look: Dictionary = WaysOutLook.LOOKS[st]
	var col := WaysOutLook.color_of(rd)
	var key := [st, col, snappedf(float(rd["prog"]), 0.02)]
	if key != _key:
		_key = key
		_beam_mat.set_shader_parameter("color", Color(col, float(look["a"])))
		_ring_mat.set_shader_parameter("color", Color(col, float(look["ring_a"])))
		_ring_mat.set_shader_parameter("arc", float(rd["prog"]) if st == WaysOutLook.St.IN_USE else 1.0)
	var want := float(look["h"])
	var step := WaysOutLook.BEAM_H / WaysOutLook.COLLAPSE_S * dt
	_h = move_toward(_h, want, step) if st == WaysOutLook.St.TAKEN else want
	_beam.visible = _h > 0.05
	_beam.scale = Vector3(1.0, maxf(_h, 0.01), 1.0)
	_beam.position.y = _h * 0.5
	var s := int(ceilf(float(rd["left"]))) if st == WaysOutLook.St.LOCKED else -1
	if s != _clock:
		_clock = s
		_glyph.visible = s >= 0
		_glyph.text = WaysOutLook.clock(float(s)) if s >= 0 else ""

## What it shows now: beam colour, ring colour, column height and the glyph text (the checks compare these).
func looks() -> Array:
	return [_beam_mat.get_shader_parameter("color"), _ring_mat.get_shader_parameter("color"), snappedf(_h, 0.1),
		_glyph.text if _glyph.visible else ""]
