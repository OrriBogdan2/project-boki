class_name GlideTrail
extends Node3D
## The side trail behind every open glider: a thin ribbon in the gliding Hunter's team colour (the colour of
## their glider stripe and ground ring), so a squad gliding in from the sky reads as ally or rival at range.
## One pooled trail per glider: taken when the glider opens, it stops growing when the glider folds and goes
## back to the pool once its tail has faded. No burst on open or close (DECISIONS: no bursts on dashes,
## landings or resets). The same on every preset: one unshaded, vertex-coloured draw per glider.

const LIFE := 1.2       # s a point of the trail takes to fade out: gone within a second or two of passing
const WIDTH := 0.3      # m across at the glider, narrowing to nothing at the tail
const ALPHA := 0.85     # opacity at the glider
const LIFT := 1.8       # m above the feet (times the Hunter's scale): the canopy's height
const STEP := 0.08      # s between the points a trail lays
const POINTS := 16      # points a trail keeps: LIFE / STEP, rounded up
const LIGHTEN := 0.25   # mixed toward white so the darker team colours still read over the abyss

## One glider's trail: a ring of the points it laid (newest at `head`), each with its age in seconds.
class Trail:
	var mi: MeshInstance3D
	var im := ImmediateMesh.new()
	var pts := PackedVector3Array()
	var ages := PackedFloat32Array()
	var head := 0
	var n := 0
	var since := 0.0
	var col := Color.WHITE
	var open := false       # still laying points (the glider is open)

	func _init() -> void:
		pts.resize(POINTS)
		ages.resize(POINTS)

var m: Match
var _free: Array[Trail] = []
var _by: Dictionary = {}       # Hunter -> its Trail, until the trail has faded
var _mat := StandardMaterial3D.new()

## The match's glider trails, made with the match (Match._start).
static func of(match_node: Match) -> GlideTrail:
	if match_node.has_meta("glide_trail"):
		return match_node.get_meta("glide_trail")
	var n := GlideTrail.new()
	n.m = match_node
	n.name = "GlideTrail"
	match_node.add_child(n)
	match_node.set_meta("glide_trail", n)
	return n

func _ready() -> void:
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED      # (written depth tints the frame)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

func _process(delta: float) -> void:
	step(delta)

## Trails in use, one per glider open or fading (checks).
func live() -> int:
	return _by.size()

## Trail nodes made so far, in use or pooled (checks: the pool only grows to the most gliders at once).
func made() -> int:
	return _by.size() + _free.size()

func step(dt: float) -> void:
	for h in m.hunters:
		if _shows(h) and not _by.has(h):
			_by[h] = _take(h)
	if _by.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	for h in _by.keys():
		var t: Trail = _by[h]
		t.open = is_instance_valid(h) and _shows(h)
		var at := Vector3.ZERO
		if t.open:
			at = h.position + Vector3(0, LIFT * float(h.cdat["scale"]), 0)
		_age(t, dt, at)
		if t.n == 0 and not t.open:
			t.mi.visible = false
			_free.append(t)
			_by.erase(h)
			continue
		_draw(t, at, cam)

func _shows(h: Hunter) -> bool:
	return h.gliding and not h.out and h.model != null and h.model.visible

func _take(h: Hunter) -> Trail:
	var t: Trail = _free.pop_back() if not _free.is_empty() else _make()
	t.n = 0
	t.since = STEP          # the first point goes down at once
	t.col = Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()].lerp(Color.WHITE, LIGHTEN)
	t.mi.visible = true
	return t

func _make() -> Trail:
	var t := Trail.new()
	t.mi = MeshInstance3D.new()
	t.mi.mesh = t.im
	t.mi.material_override = _mat
	t.mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.mi.top_level = true          # (points are in world space)
	add_child(t.mi)
	return t

## Ages the points, drops the faded tail and, while the glider is open, lays a point every STEP.
func _age(t: Trail, dt: float, at: Vector3) -> void:
	for k in t.n:
		t.ages[(t.head - k + POINTS) % POINTS] += dt
	while t.n > 0 and t.ages[(t.head - t.n + 1 + POINTS) % POINTS] >= LIFE:
		t.n -= 1
	if not t.open:
		return
	t.since += dt
	if t.since < STEP:
		return
	t.since = 0.0
	t.head = (t.head + 1) % POINTS
	t.pts[t.head] = at
	t.ages[t.head] = 0.0
	t.n = mini(t.n + 1, POINTS)

## The ribbon from the glider (or the newest point, once folded) back to the oldest, turned to the camera.
func _draw(t: Trail, at: Vector3, cam: Camera3D) -> void:
	t.im.clear_surfaces()
	var lead := 1 if t.open else 0          # while open, the glider itself is the ribbon's first point
	var count := t.n + lead
	if count < 2:
		return
	t.im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var prev := Vector3.ZERO
	for k in count:
		var i := (t.head - k + lead + POINTS) % POINTS
		var p := at if k < lead else t.pts[i]
		var age := 0.0 if k < lead else t.ages[i]
		var along := prev - p if k > 0 else p - t.pts[(t.head - 1 + lead + POINTS) % POINTS]
		var side := along.cross(cam.global_position - p if cam else Vector3.UP)
		if side.length_squared() > 0.000001:
			side = side.normalized()
		var fade := clampf(1.0 - age / LIFE, 0.0, 1.0)
		var c := Color(t.col, ALPHA * fade)
		t.im.surface_set_color(c)
		t.im.surface_add_vertex(p + side * (WIDTH * 0.5 * fade))
		t.im.surface_set_color(c)
		t.im.surface_add_vertex(p - side * (WIDTH * 0.5 * fade))
		prev = p
	t.im.surface_end()
