class_name DodgeDummy
extends RefCounted
## The Training Area's dash-dodge station: a dummy that, while you stand near it, loops every 3 s through one
## slow orb (its red lane shows first, then the orb crawls down it) and one ground circle that fills under
## where you stood and then bursts. Nothing here costs health. A shot counts as dodged when you dash after it
## was announced and it did not catch you (a dash through it, or out of its way); the goal line ticks at 5
## (StationGoals, kind "dodges"). Only a few lines per tick, and nothing at all when you are away.

const NAME := "Shooter"        # the dummy's name (Arena.SPOTS, station_goals.json "who")
const LOOP := 3.0              # s, one shot and one circle, then again
const SHOT_WINDUP := 0.5       # s the lane fills before the orb leaves
const SHOT_SPEED := 8.0        # m/s, slow on purpose
const SHOT_HIT_R := 0.9        # m, how close the orb must come to you to hit
const SHOT_WIDTH := 1.6        # m, the lane's width
const CIRCLE_AT := 1.6         # s into the loop when the circle is set under you
const CIRCLE_TIME := 1.4       # s the circle fills before it bursts (so it bursts as the next shot starts)
const CIRCLE_R := 2.4          # m
const REACH := 13.0            # m from the dummy: further away it stops firing
const ORB_LIFT := 1.0          # m above the ground
const COL_WARN := Color("ff5a3a")

var m: Match
var shooter: Hunter
var goals: StationGoals
var dodges := 0                # dodged in this visit (the goal line keeps its own count)
var _t := LOOP - SHOT_WINDUP   # s into the loop (the first shot starts half a second after you step in)
var _circle_set := true        # this loop's circle has been placed (the first partial loop has none)
var _dash_t := -99.0           # the last time you were seen dashing
var _shot := {}                # {t0, from, dir, len, t, lane, orb}
var _circle := {}              # {t0, at, t, node}

func _init(match_node: Match, dummy: Hunter, station_goals: StationGoals) -> void:
	m = match_node
	shooter = dummy
	goals = station_goals

func tick(dt: float) -> void:
	var P: Hunter = m.player
	if P.roll_t > 0.0:
		_dash_t = m.time
	if P.downed or P.flat_dist(shooter.pos) > REACH:
		_stop()
		return
	_t += dt
	if _t >= LOOP:
		_t -= LOOP
		_circle_set = false
		_start_shot(P)
	elif not _circle_set and _t >= CIRCLE_AT:
		_circle_set = true
		_start_circle(P)
	if not _shot.is_empty():
		_step_shot(P, dt)
	if not _circle.is_empty():
		_step_circle(P, dt)

## You left (or went down): drop what is in the air and start the next visit from the top.
func _stop() -> void:
	_end_shot()
	_end_circle()
	_t = LOOP - SHOT_WINDUP
	_circle_set = true

func _start_shot(P: Hunter) -> void:
	var from := shooter.pos
	var to := Vector2(P.pos.x - from.x, P.pos.z - from.z)
	if to.length() < 0.5:
		return
	var dir := to.normalized()
	var lane: Node3D = m.fx.telegraph_rect(from, dir, to.length(), SHOT_WIDTH, COL_WARN)
	m.fx.telegraph_progress(lane, 0.0)
	_shot = {"t0": m.time, "from": from, "dir": dir, "len": to.length(), "t": 0.0, "lane": lane, "orb": _orb(from)}

func _orb(at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COL_WARN
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(mi)
	mi.global_position = at + Vector3(0, ORB_LIFT, 0)
	mi.visible = false
	return mi

func _step_shot(P: Hunter, dt: float) -> void:
	_shot["t"] += dt
	var t: float = _shot["t"]
	if t < SHOT_WINDUP:
		m.fx.telegraph_progress(_shot["lane"], t / SHOT_WINDUP)
		return
	m.fx.telegraph_progress(_shot["lane"], 1.0)
	var run := SHOT_SPEED * (t - SHOT_WINDUP)
	var dir: Vector2 = _shot["dir"]
	var from: Vector3 = _shot["from"]
	var at := from + Vector3(dir.x, 0, dir.y) * minf(run, float(_shot["len"]))
	var orb: MeshInstance3D = _shot["orb"]
	orb.visible = true
	orb.global_position = at + Vector3(0, ORB_LIFT, 0)
	if Vector2(P.pos.x - at.x, P.pos.z - at.z).length() < SHOT_HIT_R:
		_land(P, true, float(_shot["t0"]))
		_end_shot()
	elif run >= float(_shot["len"]):
		_land(P, false, float(_shot["t0"]))
		_end_shot()

func _start_circle(P: Hunter) -> void:
	var at := Vector3(P.pos.x, m.world.ground_at(P.pos.x, P.pos.z), P.pos.z)
	var node: Node3D = m.fx.telegraph_circle(at, CIRCLE_R, COL_WARN)
	m.fx.telegraph_progress(node, 0.0)
	_circle = {"t0": m.time, "at": at, "t": 0.0, "node": node}

func _step_circle(P: Hunter, dt: float) -> void:
	_circle["t"] += dt
	var t: float = _circle["t"]
	m.fx.telegraph_progress(_circle["node"], t / CIRCLE_TIME)
	if t < CIRCLE_TIME:
		return
	var at: Vector3 = _circle["at"]
	m.fx.ring(at, CIRCLE_R, COL_WARN, 0.4)
	_land(P, Vector2(P.pos.x - at.x, P.pos.z - at.z).length() < CIRCLE_R, float(_circle["t0"]))
	_end_circle()

## An attack reaches you. Under it and not dashing: hit (no damage). Otherwise a dash since it was announced
## is a dodge; no dash is only a miss.
func _land(P: Hunter, under: bool, announced: float) -> void:
	if under and P.roll_t <= 0.0:
		m.fx.ring(P.pos, 1.2, COL_WARN, 0.3)
		_say("Hit, but no damage here. Dash out of the red", COL_WARN)
	elif _dash_t >= announced:
		dodges += 1
		goals.hit(NAME.to_upper(), "dodges")
		_say("Dodged!", StationGoals.COL_DONE)

func _say(text: String, col: Color) -> void:
	if m.hud:
		m.hud.toast(text, col)

func _end_shot() -> void:
	if _shot.is_empty():
		return
	m.fx.end_telegraph(_shot["lane"])
	(_shot["orb"] as Node).queue_free()
	_shot = {}

func _end_circle() -> void:
	if _circle.is_empty():
		return
	m.fx.end_telegraph(_circle["node"])
	_circle = {}
