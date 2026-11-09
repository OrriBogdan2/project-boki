class_name RecastMarker
extends Node3D
## The world marker on what an open recast will trigger (docs/HUD.md): a ring on the spot
## and the recast's key on a cap above it, in the ability's colour, fading as the window runs out. Only the
## caster's own game draws it (nothing here goes over Net). A kit calls `show_at` every step the recast is open;
## one node serves the match and hides itself when a step goes by without a call.

const KEEP := 0.25             # s without a call before the marker hides (a hit-stop must not blink it)
const RING_R := 0.9            # m, the ring's mid radius
const RING_W := 0.09           # m, the ring's width
const RING_LIFT := 0.08        # m above the ground, so the ring never sinks into it
const CAP_UP := 1.7            # m above the spot, where the key cap hangs
const CAP_PX := 0.012          # m per font pixel of the key
const FADE_MIN := 0.3          # the ring's strength as the window closes
const SHRINK_MIN := 0.6        # the ring's size as the window closes
const FLAT := 0.05             # the ring's height scale: a flat band

var _ring := MeshInstance3D.new()
var _mat := StandardMaterial3D.new()
var _cap := Label3D.new()
var _disc := MeshInstance3D.new()
var _disc_mat := StandardMaterial3D.new()
var _idle := 0.0

func _init() -> void:
	name = "RecastMarker"
	visible = false
	var torus := TorusMesh.new()
	torus.inner_radius = RING_R - RING_W
	torus.outer_radius = RING_R + RING_W
	torus.rings = 32
	torus.ring_segments = 6
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.mesh = torus
	_ring.material_override = _mat
	add_child(_ring)
	_disc.mesh = _disc_mesh()
	_disc.position.y = CAP_UP
	add_child(_disc)
	_cap.font = UI.big
	_cap.pixel_size = CAP_PX
	_cap.outline_size = 8
	_cap.outline_modulate = Color(0.03, 0.03, 0.05)
	_cap.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cap.no_depth_test = true
	_cap.render_priority = 2
	_cap.position.y = CAP_UP
	add_child(_cap)

## A dark billboard disc behind the key.
func _disc_mesh() -> QuadMesh:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 0.86, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_disc_mat.no_depth_test = true
	_disc_mat.albedo_texture = tex
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.8
	quad.material = _disc_mat
	return quad

## The marker for `h`'s open recast on `at`: `action` is the InputMap action that triggers it, `left` / `total`
## the window in seconds. Does nothing for anyone but the local player.
static func show_at(h: Hunter, action: String, at: Vector3, left: float, total: float, col: Color) -> void:
	if h == null or h.m == null or not h.is_local() or AimKit.blocked(h):
		return
	var node := h.m.get_node_or_null("RecastMarker") as RecastMarker
	if node == null:
		node = RecastMarker.new()
		h.m.add_child(node)
	node.put(Settings.key_cap(action), at, clampf(left / maxf(0.05, total), 0.0, 1.0), col)

func put(key: String, at: Vector3, frac: float, col: Color) -> void:
	_idle = 0.0
	visible = true
	position = at + Vector3(0, RING_LIFT, 0)
	var grown := lerpf(SHRINK_MIN, 1.0, frac)
	var strength := lerpf(FADE_MIN, 1.0, frac)
	_ring.scale = Vector3(grown, FLAT, grown)
	_mat.albedo_color = Color(col, strength)
	_disc_mat.albedo_color = Color(col.darkened(0.6), strength)
	_cap.text = key
	_cap.font_size = 64 if key.length() <= 2 else 40
	_cap.modulate = Color(1, 1, 1, strength)

func _process(delta: float) -> void:
	_idle += delta
	if _idle > KEEP:
		visible = false
