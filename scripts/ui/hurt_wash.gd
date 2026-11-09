class_name HurtWash
extends RefCounted
## Low health: a red wash creeping in from the screen edges, deeper as health runs out, and heavier in a
## soft arc on the edge the last second's hits came from (Hud.hurt_dirs), easing back to even. It is
## clear in the middle and faint at the edge, so aim lines and telegraphs read through it.

const BELOW := 0.35        # share of max health: the wash shows under this
const FLOOR := 0.5         # share of full strength it starts at, just under BELOW
const EVEN_A := 0.15       # alpha at the screen edge all round, at zero health
const EVEN_D := 90.0       # px: how far the even wash reaches in, at zero health
const ARC_A := 0.27        # extra edge alpha on the struck side (a fresh hit, at zero health)
const ARC_D := 130.0       # px: extra reach on the struck side
const ARC_HALF := 0.9      # rad: half-width of the arc around a hit's direction
const FADE := 1.0          # s: a hit's arc eases back to even over this
const PULSE_HZ := 0.95     # pulses a second
const PER_EDGE := 12       # samples along each screen edge
const RED := Color(0.75, 0.05, 0.05)
const RING := PER_EDGE * 4

static var _pts := PackedVector2Array()
static var _cols := PackedColorArray()
static var _tris := PackedInt32Array()

## 0 above BELOW, then FLOOR rising to 1 as health runs out. Nothing while downed or out.
static func strength(p: Hunter) -> float:
	if p == null or p.downed or p.out or p.max_hp <= 0.0 or p.hp >= p.max_hp * BELOW:
		return 0.0
	return lerpf(FLOOR, 1.0, 1.0 - p.hp / (p.max_hp * BELOW))

## How hard the hits in `dirs` ({ang, t}) weigh on screen direction `ang`: 0 (even) to 1 (fresh, dead on).
static func weight_at(dirs: Array, ang: float) -> float:
	var w := 0.0
	for h in dirs:
		var fresh := 1.0 - smoothstep(0.0, FADE, float(h["t"]))
		var near := clampf(1.0 - absf(angle_difference(float(h["ang"]), ang)) / ARC_HALF, 0.0, 1.0)
		w = maxf(w, fresh * near * near * (3.0 - 2.0 * near))
	return w

## One ring of quads round the screen: opaque-ish on the edge, fading to nothing toward the middle.
static func draw(c: CanvasItem, sz: Vector2, p: Hunter, dirs: Array, time: float) -> void:
	var s := strength(p)
	if s <= 0.0:
		return
	if _tris.is_empty():
		_build_ring()
	var pulse := 0.8 + 0.2 * sin(time * TAU * PULSE_HZ)
	var ctr := sz * 0.5
	var corners := [Vector2.ZERO, Vector2(sz.x, 0.0), sz, Vector2(0.0, sz.y)]
	for k in RING:
		var e := floori(float(k) / PER_EDGE)
		var edge: Vector2 = corners[e].lerp(corners[(e + 1) % 4], float(k % PER_EDGE) / PER_EDGE)
		var inward := (ctr - edge).normalized()
		var w := weight_at(dirs, (-inward).angle())
		_pts[k * 2] = edge
		_pts[k * 2 + 1] = edge + inward * s * (EVEN_D + ARC_D * w)
		_cols[k * 2] = Color(RED, s * (EVEN_A + ARC_A * w) * pulse)
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), _tris, _pts, _cols)

## The ring's fixed triangles (edge point 2k, inner point 2k+1) and its inner points' clear colour.
static func _build_ring() -> void:
	_pts.resize(RING * 2)
	_cols.resize(RING * 2)
	for k in RING:
		var nxt := (k + 1) % RING
		_tris.append_array([k * 2, nxt * 2, k * 2 + 1, k * 2 + 1, nxt * 2, nxt * 2 + 1])
		_cols[k * 2 + 1] = Color(RED, 0.0)
