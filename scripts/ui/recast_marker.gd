class_name RecastMarker
extends Node3D
## The world marker on what an open recast will trigger (docs/HUD.md): a plain ring on the spot in the ability's
## colour, shrinking and fading as the window runs out and pulsing faster as it closes. No key or word on world
## objects (the 2026-11-11 rule): the key lives on the ability slot. Only the caster's own game draws it
## (nothing here goes over Net). A kit calls `show_at` every step the recast is open; one node serves the match
## and hides itself when a step goes by without a call.

const KEEP := 0.25  # s without a call before the marker hides (a hit-stop must not blink it)
const RING_R := 0.9  # m, the ring's mid radius
const RING_W := 0.09  # m, the ring's width
const RING_LIFT := 0.08  # m above the ground, so the ring never sinks into it
const FADE_MIN := 0.3  # the ring's strength as the window closes
const SHRINK_MIN := 0.6  # the ring's size as the window closes
const FLAT := 0.05  # the ring's height scale: a flat band
const PULSE_HZ := Vector2(2.0, 7.0)  # pulses per s as the window opens / as it closes
const PULSE_DEPTH := 0.35  # how far the ring's strength dips between pulses (0 = steady)

var _ring := MeshInstance3D.new()
var _mat := StandardMaterial3D.new()
var _idle := 0.0
var _pulse := 0.0  # pulse phase, in cycles
var _frac := 1.0  # the window left, 0..1


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


## The marker for `h`'s open recast on `at`: `left` / `total` the window in seconds. Does nothing for anyone but
## the local player.
static func show_at(h: Hunter, at: Vector3, left: float, total: float, col: Color) -> void:
	if h == null or h.m == null or not h.is_local():
		return
	var node := h.m.get_node_or_null("RecastMarker") as RecastMarker
	if node == null:
		node = RecastMarker.new()
		h.m.add_child(node)
	node.put(at, clampf(left / maxf(0.05, total), 0.0, 1.0), col)


func put(at: Vector3, frac: float, col: Color) -> void:
	_idle = 0.0
	_frac = frac
	visible = true
	position = at + Vector3(0, RING_LIFT, 0)
	var grown := lerpf(SHRINK_MIN, 1.0, frac)
	_ring.scale = Vector3(grown, FLAT, grown)
	_mat.albedo_color = Color(col, _strength())


## The ring's strength: it fades with the window, and dips in a pulse that quickens toward the end.
func _strength() -> float:
	var base := lerpf(FADE_MIN, 1.0, _frac)
	return base * (1.0 - PULSE_DEPTH * 0.5 * (1.0 - cos(TAU * _pulse)))


func _process(delta: float) -> void:
	_idle += delta
	_pulse = fposmod(_pulse + delta * lerpf(PULSE_HZ.y, PULSE_HZ.x, _frac), 1.0)
	if _idle > KEEP:
		visible = false
	else:
		_mat.albedo_color.a = _strength()
