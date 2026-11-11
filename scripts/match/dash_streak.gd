class_name DashStreak
extends Node3D
## The one dash streak, the same for all 12 Hunters: a short flat ribbon in the Hunter's ability colour laid from
## the body anchor along the path while a dash runs (ground, air and chained), fading out in LIFE seconds. Pooled:
## no node is made after the first dash. No ring, disc or burst (docs/decisions: "Movement and combat feel").
## A kit's own dash look (Kael's Blazing Spirit, Grimble's junk roll, the flame, ink and blink trails) draws over it.

const LIFE := 0.2        # s a ribbon piece takes to fade out
const WIDTH := 0.5       # m across, about a body wide, so it reads at match zoom; narrows to half as it fades
const ALPHA := 0.8       # a piece's opacity when laid
const LIFT := 0.9        # m above the feet (times the Hunter's scale): the body anchor
const MIN_LEN := 0.05    # m the Hunter must move before the next piece is laid
const MAX_LEN := 8.0     # m: a longer jump in one frame is a blink, not a path
const POOL := 96         # pieces: 12 Hunters x 8 pieces live in LIFE

var m: Match
var _pieces: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _age := PackedFloat32Array()      # s since laid; -1 = free
var _next := 0
var live := 0                         # pieces showing (checks)
var _last := {}                       # Hunter -> where its last piece ended

## The match's streak, made with the match (Match._start).
static func of(match_node: Match) -> DashStreak:
	if match_node.has_meta("dash_streak"):
		return match_node.get_meta("dash_streak")
	var n := DashStreak.new()
	n.m = match_node
	n.name = "DashStreak"
	match_node.add_child(n)
	match_node.set_meta("dash_streak", n)
	return n

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	for i in POOL:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED      # (written depth tints the frame)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_pieces.append(mi)
		_mats.append(mat)
		_age.append(-1.0)

func _process(delta: float) -> void:
	step(delta)

func step(dt: float) -> void:
	for h in m.hunters:
		_feed(h)
	if live == 0:
		return
	for i in POOL:
		if _age[i] < 0.0:
			continue
		_age[i] += dt
		var k := _age[i] / LIFE
		if k >= 1.0:
			_age[i] = -1.0
			_pieces[i].visible = false
			live -= 1
			continue
		_mats[i].albedo_color.a = ALPHA * (1.0 - k)
		_pieces[i].scale.x = WIDTH * (1.0 - 0.5 * k)

func _feed(h: Hunter) -> void:
	if not (h.roll_t > 0.0 or (h.ak != null and h.ak.dash_left() > 0.0)) or not h.model.visible:
		_last.erase(h)
		return
	var at: Vector3 = h.position + Vector3(0, LIFT * float(h.cdat["scale"]), 0)
	if not _last.has(h):
		_last[h] = at
		return
	var from: Vector3 = _last[h]
	var dist := from.distance_to(at)
	if dist < MIN_LEN:
		return
	_last[h] = at
	if dist <= MAX_LEN:
		_lay(from, at, dist, Arch.color(h.arch))

func _lay(from: Vector3, to: Vector3, dist: float, col: Color) -> void:
	var z := (to - from) / dist
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 0.0001:
		return                      # straight up or down: nothing to lay flat
	x = x.normalized()
	var i := _next
	_next = (_next + 1) % POOL
	if _age[i] < 0.0:
		live += 1
	_age[i] = 0.0
	var mi := _pieces[i]
	mi.transform = Transform3D(Basis(x, z.cross(x), z), (from + to) * 0.5)
	mi.scale = Vector3(WIDTH, 1.0, dist)
	mi.visible = true
	_mats[i].albedo_color = Color(col.lerp(Color.WHITE, 0.2), ALPHA)
