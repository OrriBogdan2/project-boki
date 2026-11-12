class_name BarrierRipple
extends Node3D
## The one hit ripple every placed barrier shares (Albert's front shield, Tenzo's rocks, Neve's Rimewall):
## a ring that spreads over the barrier's face from the impact point, in the barrier's own colour, and a
## bigger white-hot one on the hit that breaks it. A fixed pool, so a firefight makes no new nodes.

const POOL := 8
const RING_R := 0.9        # m: how far a plain hit's ring spreads over the face
const BREAK_R := 2.4       # m: the breaking hit's
const RING_T := 0.3        # s: a plain ring's life
const BREAK_T := 0.5       # s: the breaking hit's
const FACE_GAP := 0.04     # m: off the face, so the ring never z-fights the slab
const LEAN := 0.8          # how far the ring tips up toward the camera: flat on a vertical face it reads edge-on
const RING_W := 0.24       # ring band width (Models.ring_mat thickness)

var m: Node = null
var _free: Array[MeshInstance3D] = []
var _live: Array = []      # {node, t, dur, r, basis, col}

func _init(match_node: Node) -> void:
	m = match_node
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.0, 2.0)
	for i in POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = Models.ring_mat(Color.WHITE, RING_W)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_free.append(mi)
	m.add_child(self)

## A hit on barrier `w` from `from`: the ripple lands on the face that side, at the hit's height.
func on_wall(w: Dictionary, from: Vector3, broke: bool) -> void:
	var ab: Vector2 = (w["b"] as Vector2) - (w["a"] as Vector2)
	var f2 := Vector2(from.x, from.z)
	var c := Geometry2D.get_closest_point_to_segment(f2, w["a"], w["b"])
	var nrm := Vector2(-ab.y, ab.x).normalized()
	if (f2 - c).dot(nrm) < 0.0:
		nrm = -nrm
	var floor_y := float(w["y"])
	var y := clampf(from.y, floor_y + 0.2, floor_y + float(w.get("top", Verbs.WALL_H)) - 0.2)
	var face := Vector3(c.x, y, c.y) + Vector3(nrm.x, 0.0, nrm.y) * float(w["th"])
	hit(face, ab.normalized(), nrm, w["col"], broke)

## A hit at `at` on the face whose outward side is `nrm` and which runs along `along` (both flat).
func hit(at: Vector3, along: Vector2, nrm: Vector2, col: Color, broke: bool) -> void:
	var mi: MeshInstance3D
	if _free.is_empty():
		mi = (_live.pop_front() as Dictionary)["node"]       # all busy: the oldest ring gives way
	else:
		mi = _free.pop_back()
	var t3 := Vector3(along.x, 0.0, along.y)
	var n3 := Vector3(nrm.x, 0.0, nrm.y)
	var up := (n3 + Vector3.UP * LEAN).normalized()      # the ring's normal: out of the face, tipped up
	var shown := col.lerp(Color.WHITE, 0.3)
	var radius := RING_R
	var life := RING_T
	var flare := 0.3
	if broke:
		shown = col.lerp(Color.WHITE, 0.7)
		radius = BREAK_R
		life = BREAK_T
		flare = 1.5
	mi.global_position = at + n3 * FACE_GAP
	mi.visible = true
	_live.append({"node": mi, "t": 0.0, "dur": life, "r": radius,
		"basis": Basis(t3, up, t3.cross(up)), "col": shown})
	tick(0.0)
	m.fx.flash(at + n3 * FACE_GAP, shown, flare, 0.07 + flare * 0.05)

## Verbs.tick: spreads and fades the live rings.
func tick(dt: float) -> void:
	for ring: Dictionary in _live.duplicate():
		ring["t"] += dt
		var k: float = minf(ring["t"] / ring["dur"], 1.0)
		var mi: MeshInstance3D = ring["node"]
		mi.basis = (ring["basis"] as Basis).scaled(Vector3.ONE * lerpf(0.2, ring["r"], 1.0 - pow(1.0 - k, 3.0)))
		(mi.material_override as ShaderMaterial).set_shader_parameter("color", Color(ring["col"], 1.0 - k))
		if k >= 1.0:
			mi.visible = false
			_free.append(mi)
			_live.erase(ring)
