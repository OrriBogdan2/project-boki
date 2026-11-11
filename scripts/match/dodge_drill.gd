class_name DodgeDrill
extends RefCounted
## The dodge drill on the Arena and the Training Grounds: while you are near the Strafer (the moving
## dummy) and the drill is not done, it throws one slow shot every few seconds. Its red lane (the fx
## telegraph) fills first, then the orb crawls down it. A clean dodge is a dash after the lane showed
## that the orb did not catch: dash through it or out of its way. Three clean dodges finish the drill
## (Match's Training Grounds checklist row "dodge"), and the Strafer stops throwing. Nothing here costs health.

const NEED := 3                # clean dodges that finish the drill
const LOOP := 3.0              # s from one shot to the next
const FIRST_AT := 1.5          # s after you step in before the first lane shows
const WINDUP := 0.6            # s the lane fills before the orb leaves
const SPEED := 8.0             # m/s the orb travels, slow on purpose
const HIT_R := 0.9             # m, how close the orb must come to you to catch you
const WIDTH := 1.6             # m, the lane's width
const OVERSHOOT := 3.0         # m the lane runs past where you stood (backing straight off is no escape)
const REACH := 7.0             # m from the Strafer: further away it throws no new shot
const ORB_LIFT := 1.0          # m above the ground
const COL_WARN := Color("ff5a3a")
const COL_DONE := Color("8ff0a0")

var m: Match
var thrower: Hunter
var dodges := 0
var done := false
var _t := 0.0                  # s into the loop
var _near := false             # you were in reach last tick (each visit starts the loop over)
var _told := false             # the one-line prompt has shown (once a session)
var _dash_t := -99.0           # the last time you were seen dashing
var _shot := {}                # {t0, from, dir, len, t, lane}
var _orb: MeshInstance3D = null

func _init(match_node: Match, dummy: Hunter) -> void:
	m = match_node
	thrower = dummy

func tick(dt: float) -> void:
	var P: Hunter = m.player
	if P.roll_t > 0.0:
		_dash_t = m.time
	if done or P.downed or not is_instance_valid(thrower):
		stop()
		return
	var near := P.flat_dist(thrower.pos) <= REACH
	if near and not _near:
		_t = LOOP - FIRST_AT
		if not _told:
			_told = true
			var key := Settings.key_cap("dash")
			_say("Dodge drill: dash (%s) through or out of the Strafer's red shot, %d times" % [key, NEED], COL_WARN)
	_near = near
	if near:
		_t += dt
		if _t >= LOOP:
			_t -= LOOP
			_throw(P)
	if not _shot.is_empty():
		_fly(P, dt)      # a shot in the air flies on even if your dash took you out of reach

## You went down or finished: drop the shot in the air.
func stop() -> void:
	_near = false
	_end_shot()

func _end_shot() -> void:
	if _shot.is_empty():
		return
	m.fx.end_telegraph(_shot["lane"])
	_orb.visible = false
	_shot = {}

func _throw(P: Hunter) -> void:
	var from := thrower.pos
	var to := Vector2(P.pos.x - from.x, P.pos.z - from.z)
	if to.length() < 0.5 or not _shot.is_empty():
		return
	var length := to.length() + OVERSHOOT
	var lane: Node3D = m.fx.telegraph_rect(from, to.normalized(), length, WIDTH, COL_WARN)
	m.fx.telegraph_progress(lane, 0.0)
	_shot = {"t0": m.time, "from": from, "dir": to.normalized(), "len": length, "t": 0.0, "lane": lane}

func _fly(P: Hunter, dt: float) -> void:
	_shot["t"] += dt
	var t: float = _shot["t"]
	m.fx.telegraph_progress(_shot["lane"], t / WINDUP)
	if t < WINDUP:
		return
	var run := SPEED * (t - WINDUP)
	var dir: Vector2 = _shot["dir"]
	var at: Vector3 = _shot["from"] + Vector3(dir.x, 0, dir.y) * minf(run, float(_shot["len"]))
	var orb := _orb_node()
	orb.visible = true
	orb.global_position = at + Vector3(0, ORB_LIFT, 0)
	var caught := P.roll_t <= 0.0 and Vector2(P.pos.x - at.x, P.pos.z - at.z).length() < HIT_R
	if caught or run >= float(_shot["len"]):
		_land(P, caught, float(_shot["t0"]))
		_end_shot()

## The shot is over. Caught: no damage, just a ring and a nudge. Otherwise a dash since the lane showed is a
## clean dodge; no dash (you walked away) does not count.
func _land(P: Hunter, caught: bool, shown: float) -> void:
	if caught:
		m.fx.ring(P.pos, 1.2, COL_WARN, 0.3)
		_say("Caught (no damage here). Dash out of the red", COL_WARN)
	elif _dash_t >= shown:
		dodges += 1
		done = dodges >= NEED
		_say("Dodge drill done" if done else "Dodged %d / %d" % [dodges, NEED], COL_DONE)

func _orb_node() -> MeshInstance3D:
	if _orb:
		return _orb
	_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	_orb.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COL_WARN
	_orb.material_override = mat
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(_orb)
	return _orb

func _say(text: String, col: Color) -> void:
	if m.hud:
		m.hud.toast(text, col)
