class_name StolenWisp
extends Node3D
## The looks of a Boki wisp that has left its owner (DECISIONS 2026-11-09 Stealing, briefs/boki-art/
## WISP_ART_BRIEF.md): round = Hunter, critter = Boki, so every state keeps the critter body of BokiWispLook.
##   loose    floating where its owner fell: a slow bob with a soft pulse, so it reads as grabbable
##   held     grabbed: a thin ring in the thief's side colour (SideColor) round it and a thin tether to the
##            thief, the wisp trailing a little behind so the line is long enough to see. Carriers are targets.
##   scatter  the thief died: each wisp darts out on its own arc and settles loose again
##   home     match end: it flies to its owner along a curve with a fading ribbon, then folds into them
## Nothing here is gameplay. The steal rules (who may grab, how many, the passives) call the verbs:
## loose(), grab(), scatter(), go_home(); `arrived` fires when a wisp reaches home. No ground ring, no
## particles of its own: the body's own sparkles plus one small Fx burst on a grab, a scatter and an arrival.

signal arrived

enum State { LOOSE, HELD, SCATTER, HOME }

const BOB_M := 0.12           # m the loose wisp rises and falls
const BOB_HZ := 0.45          # bobs per second: slower than the hop of a carried wisp
const PULSE_HZ := 0.9         # soft pulses per second
const PULSE_LOW := 0.72       # brightness at the bottom of a pulse (1 at the top)
const PULSE_SIZE := 0.08      # fraction its size swells by at the top of a pulse
const RING_R := 0.2           # m: the thief ring's radius round the wisp
const RING_W := 0.012         # m: the ring's thickness
const RING_TILT := 1.15       # rad the ring leans off flat, so it reads from above and from the side
const RING_SPIN := 2.0        # rad/s
const TETHER_W := 0.012       # m: the tether's radius
const TETHER_ALPHA := 0.75
const CHEST_Y := 1.2          # m above a Hunter's feet where the tether is tied
const FOLLOW_Y := 1.7         # m above the thief's feet that a held wisp floats at
const FOLLOW_R := 1.1         # m round the thief it orbits at
const FOLLOW_HZ := 0.3        # laps per second
const FOLLOW_RATE := 5.0      # 1/s: how tightly it follows (lower = a longer tether when the thief runs)
const SNAP_M := 8.0           # m: further than this behind and it jumps (a teleport)
const SCATTER_S := 0.8        # s of the dart
const SCATTER_DIST := Vector2(5.0, 7.5)     # m the dart travels (min, max)
const SCATTER_HUMP := Vector2(1.0, 2.0)     # m the arc rises in the middle
const SCATTER_SWING := 1.6    # m the arc bends sideways, to either side
const HOME_SPEED := 14.0      # m/s along the way home
const HOME_S := Vector2(0.8, 2.5)           # s: the shortest and longest flight home
const HOME_ARC := 0.25        # the flight home bows up by this fraction of its length
const RIBBON_POINTS := 14
const RIBBON_STEP := 0.03     # s between ribbon samples
const RIBBON_W := 0.09        # m across at the head

var state := State.LOOSE
var model: Node3D
var m: Match
var thief: Hunter
var owner_h: Hunter
var col := Color.WHITE        # the thief team's colour (the ring, the tether)
var slot := 0                 # which of the thief's (up to two) stolen wisps this is
var _t := 0.0
var _at := Vector3.ZERO       # where it floats while loose
var _from := Vector3.ZERO
var _to := Vector3.ZERO       # the end of a scatter dart
var _bend := Vector3.ZERO
var _hump := 0.0
var _p := 0.0                 # the dart or flight home, 0 to 1
var _len := 1.0               # s the dart or flight home takes
var _ring: MeshInstance3D
var _tether: MeshInstance3D
var _ribbon: MeshInstance3D
var _trace := PackedVector3Array()
var _trace_t := 0.0

## A wisp of `species` floating at `at` (a world position), parented under `match_node`.
static func spawn(match_node: Match, species: String, rec: Dictionary, at: Vector3) -> StolenWisp:
	var w := StolenWisp.new()
	w.name = "StolenWisp"
	w.m = match_node
	w.model = BokiWispLook.build(species, rec)
	w.add_child(w.model)
	match_node.add_child(w)
	w.loose(at)
	return w

func loose(at: Vector3) -> void:
	state = State.LOOSE
	thief = null
	_at = at
	position = at
	_drop_marks()

## Grabbed by `by`: the ring and tether in its side colour; `slot_i` is 0 or 1 for its two possible wisps.
func grab(by: Hunter, slot_i := 0) -> void:
	state = State.HELD
	thief = by
	slot = slot_i
	col = SideColor.of(m, by)
	_drop_marks()
	_ring = _mark(TorusMesh.new())
	var torus := _ring.mesh as TorusMesh
	torus.inner_radius = RING_R - RING_W
	torus.outer_radius = RING_R + RING_W
	torus.rings = 24
	torus.ring_segments = 4
	_ring.rotation.x = RING_TILT
	_tether = _mark(CylinderMesh.new())
	var cyl := _tether.mesh as CylinderMesh
	cyl.top_radius = TETHER_W
	cyl.bottom_radius = TETHER_W
	cyl.height = 1.0
	cyl.radial_segments = 4
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	_tether.top_level = true
	m.fx.burst(global_position, col, 6, 2.5, 0.35, 2.0, 0.8)

## The thief died: this wisp darts out along its own arc (`i` of `n` wisps scatter from one spot, so each
## takes its own bearing) and then floats loose where it lands.
func scatter(i := 0, n := 1) -> void:
	var a := TAU * (float(i) + randf_range(-0.2, 0.2)) / float(maxi(n, 1)) + randf() * 0.6
	var dir := Vector3(cos(a), 0, sin(a))
	state = State.SCATTER
	thief = null
	_from = global_position
	_to = _from + dir * randf_range(SCATTER_DIST.x, SCATTER_DIST.y)
	_bend = dir.cross(Vector3.UP) * SCATTER_SWING * (1.0 if randf() < 0.5 else -1.0)
	_hump = randf_range(SCATTER_HUMP.x, SCATTER_HUMP.y)
	_p = 0.0
	_len = SCATTER_S
	m.fx.burst(_from, col, 6, 3.5, 0.4, 3.0, 0.8)
	_drop_marks()

## Match end: it flies home to `to`, trailing a fading ribbon, and folds into them (`arrived`).
func go_home(to: Hunter) -> void:
	state = State.HOME
	owner_h = to
	thief = null
	_from = global_position
	_len = clampf(_from.distance_to(_home_point()) / HOME_SPEED, HOME_S.x, HOME_S.y)
	_p = 0.0
	_drop_marks()
	_trace.clear()
	_trace.resize(RIBBON_POINTS)
	_trace.fill(_from)
	_ribbon = MeshInstance3D.new()
	_ribbon.mesh = ImmediateMesh.new()
	_ribbon.top_level = true
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ribbon.material_override = mat
	add_child(_ribbon)

func _process(dt: float) -> void:
	tick(dt)

func tick(dt: float) -> void:
	_t += dt
	match state:
		State.LOOSE:
			position = _at
			_float()
		State.HELD:
			if not is_instance_valid(thief):
				scatter()
				return
			_follow(dt)
			_float()
			_marks(dt)
		State.SCATTER:
			_p = minf(_p + dt / _len, 1.0)
			var e := 1.0 - (1.0 - _p) * (1.0 - _p)
			var arc := sin(PI * _p)
			position = _from.lerp(_to, e) + _bend * arc + Vector3(0, _hump * arc, 0)
			_float()
			if _p >= 1.0:
				loose(position)
		State.HOME:
			_fly(dt)

## The loose float: a slow bob and a soft pulse of brightness and size.
func _float() -> void:
	var body := model.get_node("Body") as GeometryInstance3D
	var phase := float(model.get_meta("phase", 0.0))
	var pulse := 0.5 + 0.5 * sin(TAU * (_t * PULSE_HZ + phase))
	body.position = Vector3(0, BOB_M * sin(TAU * (_t * BOB_HZ + phase)), 0)
	body.scale = Vector3.ONE * (1.0 + PULSE_SIZE * pulse)
	body.set_instance_shader_parameter("dim", lerpf(PULSE_LOW, 1.0, pulse))
	(model.get_node("Trail") as Node3D).position = body.position

func _follow(dt: float) -> void:
	var a := TAU * (_t * FOLLOW_HZ + 0.5 * float(slot))
	var goal := thief.position + Vector3(cos(a) * FOLLOW_R, FOLLOW_Y, sin(a) * FOLLOW_R)
	if position.distance_to(goal) > SNAP_M:
		position = goal
	position = position.lerp(goal, 1.0 - exp(-FOLLOW_RATE * dt))

func _marks(dt: float) -> void:
	_ring.rotation.y += RING_SPIN * dt
	var body := model.get_node("Body") as Node3D
	_ring.position = body.position      # the ring rides the bob, so it never hangs off an empty spot
	var a := thief.position + Vector3(0, CHEST_Y, 0)
	var b := body.global_position
	var ln := a.distance_to(b)
	if ln < 0.05:
		_tether.visible = false
		return
	_tether.visible = true
	var axis := (b - a) / ln
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	_tether.global_transform = Transform3D(Basis(side, axis * ln, side.cross(axis)), (a + b) * 0.5)

func _mark(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col, TETHER_ALPHA)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _drop_marks() -> void:
	for n in [_ring, _tether, _ribbon]:
		if n:
			n.queue_free()
	_ring = null
	_tether = null
	_ribbon = null

func _home_point() -> Vector3:
	return owner_h.position + Vector3(0, FOLLOW_Y - 0.2, 0)

func _fly(dt: float) -> void:
	_p = minf(_p + dt / _len, 1.0)
	var end := _home_point()
	var e := _p * _p * (3.0 - 2.0 * _p)
	var span := _from.distance_to(end)
	var mid := (_from + end) * 0.5 + Vector3(0, span * HOME_ARC, 0)
	position = _from.lerp(mid, e).lerp(mid.lerp(end, e), e)
	_float()
	_trace_t += dt
	if _trace_t >= RIBBON_STEP:
		_trace_t = 0.0
		_trace.remove_at(0)
		_trace.append(position)
	_trace[RIBBON_POINTS - 1] = position
	_draw_ribbon()
	if _p >= 1.0:
		m.fx.burst(end, SideColor.of(m, owner_h), 8, 3.0, 0.4, 2.0, 0.9)
		arrived.emit()
		queue_free()

## The fading ribbon behind a wisp flying home: a strip facing the camera, thick at the head, gone at the tail.
func _draw_ribbon() -> void:
	var cam := get_viewport().get_camera_3d()
	var glow := (model.get_node("Trail") as CPUParticles3D).color
	var im := _ribbon.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in RIBBON_POINTS:
		var p := _trace[i]
		var q := _trace[mini(i + 1, RIBBON_POINTS - 1)] if i < RIBBON_POINTS - 1 else p + (p - _trace[i - 1])
		var dir := (q - p).normalized() if q != p else Vector3.UP
		var eye := (cam.global_position - p).normalized() if cam else Vector3.UP
		var side := dir.cross(eye).normalized() * RIBBON_W * 0.5 * float(i) / float(RIBBON_POINTS - 1)
		var c := Color(glow, 0.8 * float(i) / float(RIBBON_POINTS - 1))
		im.surface_set_color(c)
		im.surface_add_vertex(p + side)
		im.surface_set_color(c)
		im.surface_add_vertex(p - side)
	im.surface_end()
