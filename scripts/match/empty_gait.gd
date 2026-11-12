class_name EmptyGait
extends RefCounted
## The Empty's legs on the move: the player at home has no clips, HunterAnim poses the Models.hunter rig by hand.
## Each foot is planted where it lands, on the move and standing. The sole's ground point is kept in world space and
## the hip, knee and leg-out angles are solved every frame so the boot's lowest point stays on it while the hips
## pass over, rolling heel to toe; a planted foot never slides, whatever the speed, the turn or the body (height,
## build). Standing, the feet stay put as the body turns or shifts its weight until a leg cannot reach, then it
## steps. The step length follows the speed and the leg (data), so the cadence does too; the stance is as long as
## the legs allow, and faster than that the body flies between steps. HunterAnim blends these legs over its own
## legs with gait_k, which is 1 on the ground (its own legs show in the air and in moves that own the body).
## Data: content/rules/warden_stance.json empty_f / empty_m "gait" (m at the rig's rest size, scaled by the body):
##   step [m, m per m/s]: step length over speed; stance: how far the hips travel over a planted foot;
##   strike: the heel lands this far ahead of the hip; hip [strike, flat, lift]: hip height over the ground at the
##   strike, with the foot flat (FLAT_U of the stance) and from the push-off on (RISE_U; the boot has no ankle, so
##   the body rises onto the toe to push off and comes down again in the air); swing: how high the swinging foot's
##   arc goes (it kicks up fast behind, so the leg can reach it as the body moves on).

const THIGH := Vector3(0.0, -FootPlant.KNEE, 0.0)
const SOLE: Array = FootPlant.SOLE
const HEEL_Z: float = (FootPlant.SOLE[0] as Vector3).z
const REACH_MARGIN := 0.01   # m: a ground point nearer than this to the leg's full stretch ends the stance early
const SWING_MIN := 0.12      # s: a swing never lands sooner (a stop mid-stride, a first step)
const SWING_MAX := 0.6       # s: nor later (a stop mid-swing still puts the foot down)
const FLAT_U := 0.3          # of the stance: the foot is flat and the hips at their "flat" height
const RISE_U := 0.7          # of the stance: the heel is up and the hips at their "lift" height from here on
const KICK := 0.7            # the swing arc's time warp: height ~ sin(pi * w^KICK), up fast behind, down slowly ahead
const LAND_T := 0.03         # s: the landing foot brakes from the body's pace to a standstill over this long
const STAND_LIFT := 0.5      # x the arc height for a standing re-step
const ROLL_TOL := 0.0005     # m: a sole point this much lower than the one on the ground takes the ground over
const ON_RATE := 10.0        # /s: how fast the planted legs take over on landing
const OFF_RATE := 6.0        # /s: and let go when the body leaves the ground
const MOVE_RATE := 10.0      # /s: how fast the hips go from their standing height to the gait's, and back
const STAND_Z := 0.06        # m: standing, the heel settles this far behind the hip (the hip over the sole)
const STAND_STEP := 0.25     # s: a standing re-step (the body turned too far for a planted foot)

## One leg's state: planted on its world anchor, or swinging to its landing pose.
class Leg:
	var pivot: Vector3           # the hip joint in the legs' space
	var side := 1.0              # -1 left, 1 right: which way the foot splays
	var planted := false
	var anchor := Vector3.ZERO   # world: the heel's ground point (the other sole points lie flat ahead of it)
	var aim := Basis.IDENTITY    # the legs' world basis as it landed: the boot keeps pointing where it was put down
	var pose := Vector3.ZERO     # hip x, knee x, leg-out z (rad)
	var from := Vector2.ZERO     # legs' space (x, z) as the swing began: where the foot left the ground
	var swing_t := 0.0
	var swing_dur := 0.3
	var landed_at := 0.0         # s on the gait clock
	var u := 0.0                 # stance progress: 0 the strike, 1 the lift
	var contact := 0             # the sole point on the ground (FootPlant.SOLE index): heel, then mid, then toe

var legs: Node3D
var left := Leg.new()
var right := Leg.new()
var gait_k := 0.0            # 1: these legs; 0: HunterAnim's own legs
var ph := 0.0                # the walk phase HunterAnim's arms and torso follow: the left leg's cycle
var landed := false          # a foot came down this frame
var hl := 0.0
var hr := 0.0
var kl := 0.0
var kr := 0.0
var wl := 0.0
var wr := 0.0
var _step: Array = [0.36, 0.18]
var _stance := 0.37
var _strike := -0.08
var _hip: Array = [0.43, 0.445, 0.485]
var _swing := 0.1
var _splay := 0.03           # m: the foot lands this far out from under the hip
var _clock := 0.0
var _was_on := false
var _move_k := 0.0           # 1 on the move (the gait's hip heights and landing spot), 0 standing
var _hip_now := 0.44         # m: the hips' height over the ground this frame, for the swinging foot's arc
var _hold_reach := 0.44      # m: the hips' height while both feet are off the ground
var _fly_from := 0.44        # m: the hips' height as the last foot left the ground
var _fly_len := 0.0          # s: how long that flight was to last

func _init(legs_node: Node3D, gait: Dictionary) -> void:
	legs = legs_node
	left.pivot = (legs.get_node("LegL") as Node3D).position
	right.pivot = (legs.get_node("LegR") as Node3D).position
	left.side = -1.0
	_step = gait.get("step", _step)
	_stance = float(gait.get("stance", _stance))
	_strike = float(gait.get("strike", _strike))
	_hip = gait.get("hip", _hip)
	_swing = float(gait.get("swing", _swing))
	_splay = FootPlant.HIP * sin(float(gait.get("width", 0.1)) * 0.6)
	_hold_reach = _hip_h(0.0)
	for leg in [left, right]:
		leg.pose = _solve(leg, 0, Vector3(leg.pivot.x + leg.side * _splay, 0.0, _strike), _hold_reach)

## Hip height over the ground through a stance: the strike height, the flat height by FLAT_U, the lift height
## from RISE_U on, eased between.
func _hip_h(u: float) -> float:
	if u <= FLAT_U:
		return lerpf(float(_hip[0]), float(_hip[1]), smoothstep(0.0, FLAT_U, u))
	return lerpf(float(_hip[1]), float(_hip[2]), smoothstep(FLAT_U, RISE_U, u))

## Advances the legs a frame: `on` while the feet have ground under them, `moving` as HunterAnim sees it, `vel` the
## body's world velocity, `own` HunterAnim's own legs [hl, hr, kl, kr, wl, wr] these blend over. Reads the legs'
## world transform (last frame's hips).
func step(dt: float, on: bool, moving: bool, vel: Vector3, own: Array) -> void:
	_clock += dt
	landed = false
	var rate := ON_RATE if on else OFF_RATE
	gait_k = move_toward(gait_k, 1.0 if on else 0.0, dt * rate)
	_move_k = move_toward(_move_k, 1.0 if moving else 0.0, dt * MOVE_RATE)
	var xf := legs.global_transform
	var inv := xf.affine_inverse()
	var dir := dir_of(xf, vel)
	var spd := Vector2(vel.x, vel.z).length()
	var step_len := xf.basis.y.length() * (float(_step[0]) + float(_step[1]) * spd)
	if on and not _was_on:
		_start(xf, inv, moving)
	_was_on = on
	if on:
		_hip_now = 0.0
		for leg in [left, right]:
			if leg.planted:
				_stance_frame(leg, inv, dir, step_len, spd)
		if not left.planted and not right.planted:      # in the air: down from the push-off to the landing height
			var left_fly := minf(left.swing_dur - left.swing_t, right.swing_dur - right.swing_t)
			if _fly_len <= 0.0:
				_fly_from = _hold_reach
				_fly_len = maxf(left_fly, dt)
			var f := clampf(1.0 - left_fly / _fly_len, 0.0, 1.0)
			_hold_reach = lerpf(_fly_from, _hip_h(0.0 if dir > 0.0 else 1.0), f * f * (3.0 - 2.0 * f))
			_hip_now = _hold_reach
		else:
			_fly_len = 0.0
		for leg in [left, right]:
			if not leg.planted:
				_swing_frame(leg, dt, dir, xf, inv, vel)
	ph = PI * 0.5 + PI * (left.u if left.planted else _swing_ph(left, dir))
	var k := gait_k
	hl = lerpf(float(own[0]), left.pose.x, k)
	hr = lerpf(float(own[1]), right.pose.x, k)
	kl = lerpf(float(own[2]), left.pose.y, k)
	kr = lerpf(float(own[3]), right.pose.y, k)
	wl = lerpf(float(own[4]), left.pose.z, k)
	wr = lerpf(float(own[5]), right.pose.z, k)

## The hips' height over the ground (the drop HunterAnim applies), from the planted legs' final reach; held while
## both feet fly; blended with HunterAnim's own legs' `own` (the lower sole of the two) by gait_k.
func hip_reach(reach_l: float, reach_r: float, own: float) -> float:
	var planted_reach := -1.0
	if left.planted:
		planted_reach = reach_l
	if right.planted:
		planted_reach = maxf(planted_reach, reach_r)
	if planted_reach > 0.0:
		_hold_reach = planted_reach
	return lerpf(own, _hold_reach, gait_k)

## The swing's share of the left leg's cycle: forward it runs on from the lift (1 -> 2), backward from the strike
## (0 -> -1), so the phase never jumps.
func _swing_ph(leg: Leg, dir: float) -> float:
	var w := clampf(leg.swing_t / leg.swing_dur, 0.0, 1.0)
	return 1.0 + w if dir > 0.0 else -w

## Ground under the feet: both are planted where they stand; already moving, the one further back steps first.
func _start(xf: Transform3D, inv: Transform3D, moving: bool) -> void:
	for leg in [left, right]:
		_plant(leg, xf)
	if not moving:
		return
	var first: Leg = left if (inv * left.anchor).z > (inv * right.anchor).z else right
	var other: Leg = right if first == left else left
	other.landed_at = _clock
	_lift(first, SWING_MIN, inv)

## Plants a leg on the ground point under its boot's lowest sole point, as the heel's ground point.
func _plant(leg: Leg, xf: Transform3D) -> void:
	var low := _lowest(leg, leg.pose)
	leg.contact = low[0]
	var heel_ground := Vector3(low[1].x, 0.0, low[1].z - ((SOLE[low[0]] as Vector3).z - HEEL_Z))
	leg.anchor = xf * heel_ground
	leg.aim = xf.basis
	leg.planted = true
	leg.landed_at = _clock

## A planted leg: the hips have moved on (or turned), so the leg is re-solved onto its anchor; past the stance, or
## out of reach, it lifts.
func _stance_frame(leg: Leg, inv: Transform3D, dir: float, step_len: float, spd: float) -> void:
	var other: Leg = right if leg == left else left
	var a := inv * leg.anchor
	leg.u = (a.z - _strike) / _stance
	var hip_h := lerpf(float(_hip[1]), _hip_h(leg.u), _move_k)      # standing: the flat-footed height
	while _too_far(leg, _heel_at(leg, a, inv), hip_h) and leg.contact < SOLE.size() - 1:
		leg.contact += 1      # the heel comes up: the boot rolls on to the next sole point
	var done := (dir > 0.0 and leg.u >= 1.0) or (dir < 0.0 and leg.u <= 0.0)
	if done or _too_far(leg, _heel_at(leg, a, inv), hip_h):
		# this foot comes down a step after the other: half-way from the cycle's own swing toward that beat
		var period := step_len / maxf(spd, 0.5)
		var other_down := other.landed_at if other.planted else _clock + other.swing_dur - other.swing_t
		var nominal := 2.0 * period - _stance * legs.global_transform.basis.z.length() / maxf(spd, 0.5)
		var on_beat := other_down + period - _clock
		var dur := clampf(lerpf(nominal, on_beat, 0.5), SWING_MIN, SWING_MAX)
		_lift(leg, lerpf(STAND_STEP, dur, _move_k), inv)
		return
	leg.pose = _solve(leg, leg.contact, _heel_at(leg, a, inv), hip_h)
	var low := _lowest(leg, leg.pose)
	if low[0] != leg.contact and (leg.pivot.y - low[1].y) > hip_h + ROLL_TOL:
		leg.contact = low[0]      # the boot rolled on: the next sole point along is down
		leg.pose = _solve(leg, leg.contact, _heel_at(leg, a, inv), hip_h)
	_hip_now = maxf(_hip_now, hip_h)

## The heel's ground point in the legs' space (`a` where the anchor is) shifted, on the move, so the contact sole
## point stays where the boot was put down while the body turns above it: the boot does not swivel on its toe.
## Standing, a turn on the spot leaves the boot to turn with the body (it re-steps when a leg cannot reach).
func _heel_at(leg: Leg, a: Vector3, inv: Transform3D) -> Vector3:
	var ahead := (SOLE[leg.contact] as Vector3).z - HEEL_Z
	var held := inv.basis * (leg.aim * Vector3(0.0, 0.0, ahead))
	return a + _move_k * Vector3(held.x, 0.0, held.z - ahead)

## True when the leg cannot stretch from the hip at `hip_h` to its contact sole point's ground spot (`a` the
## heel's, in the legs' space).
func _too_far(leg: Leg, a: Vector3, hip_h: float) -> bool:
	var sole: Vector3 = SOLE[leg.contact]
	var hip_to_ground := Vector3(a.x - leg.pivot.x, hip_h, a.z + sole.z - HEEL_Z).length()
	return hip_to_ground > FootPlant.KNEE + sole.length() - REACH_MARGIN

## A leg leaves the ground for a swing of `dur` seconds.
func _lift(leg: Leg, dur: float, inv: Transform3D) -> void:
	leg.planted = false
	leg.swing_t = 0.0
	leg.swing_dur = dur
	var a := inv * leg.anchor
	leg.from = Vector2(a.x, a.z)

## Which way the body moves in the legs' frame: 1 forward, -1 backing up.
static func dir_of(xf: Transform3D, vel: Vector3) -> float:
	return -1.0 if (xf.basis.inverse() * vel).z > 0.0 else 1.0

## A swinging leg: the boot's lowest sole point (the toe as it leaves, the heel as it lands) travels, in the legs'
## own frame, from where it left the ground to where it lands, in an arc; it overshoots the spot a little and
## comes back at the body's pace over the last LAND_T, so it is still against the ground as it lands whatever the
## speed. Standing, it is a plain step.
func _swing_frame(leg: Leg, dt: float, dir: float, xf: Transform3D, inv: Transform3D, vel: Vector3) -> void:
	leg.swing_t += dt
	var w := clampf(leg.swing_t / leg.swing_dur, 0.0, 1.0)
	var land_z := _strike if dir > 0.0 else _strike + _stance
	var land := Vector2(leg.pivot.x + leg.side * _splay, lerpf(STAND_Z, land_z, _move_k))
	var brake := LAND_T / leg.swing_dur
	var pace := (inv.basis * vel).length() * leg.swing_dur / maxf(absf(land.y - leg.from.y), 0.05)
	var over := pace * brake * 0.5
	var s := (1.0 + over) * smoothstep(0.0, 1.0 - brake, w)
	if w > 1.0 - brake:
		s = 1.0 + over - pace / (2.0 * brake) * (w - 1.0 + brake) * (w - 1.0 + brake)
	var at := Vector2(lerpf(leg.from.x, land.x, smoothstep(0.0, 1.0, w)), lerpf(leg.from.y, land.y, s))
	var arc := _swing * lerpf(STAND_LIFT, 1.0, _move_k) * sin(PI * pow(w, lerpf(1.0, KICK, _move_k)))
	var depth := _hip_now - arc
	if w > 0.5:
		leg.contact = 0      # coming down to land: the heel rides the arc unless that pose hangs the toe lower
	leg.pose = _solve(leg, leg.contact, Vector3(at.x, 0.0, at.y), depth)
	var low := _lowest(leg, leg.pose)
	if low[0] != leg.contact and (leg.pivot.y - low[1].y) > depth + ROLL_TOL:
		leg.contact = low[0]
		leg.pose = _solve(leg, leg.contact, Vector3(at.x, 0.0, at.y), depth)
	leg.u = 0.0 if dir > 0.0 else 1.0
	if w >= 1.0:
		_plant(leg, xf)
		landed = true

## The boot's lowest sole point for a pose: [index into SOLE, its position in the legs' space].
func _lowest(leg: Leg, pose: Vector3) -> Array:
	var hip := Basis.from_euler(Vector3(pose.x, 0.0, pose.z))
	var shin := Basis(Vector3.RIGHT, pose.y)
	var best := 0
	var low := Vector3.ZERO
	for i in SOLE.size():
		var p: Vector3 = leg.pivot + hip * (THIGH + shin * (SOLE[i] as Vector3))
		if i == 0 or p.y < low.y:
			best = i
			low = p
	return [best, low]

## The hip, knee and leg-out angles that put sole point `contact` on its ground point (`target` is the heel's,
## each sole point lies flat ahead of it) with the hip `hip_h` above it. Closed form for this rig: the knee bends
## about the thigh's own axis, so thigh and boot are one planar chain whose length sets the knee (bent back, the
## knee ahead of the hip-to-sole line); the leg-out angle tips that chain onto the point's side, the hip swings it
## to the point. Out of reach, the leg points at it.
func _solve(leg: Leg, contact: int, target: Vector3, hip_h: float) -> Vector3:
	var sole: Vector3 = SOLE[contact]
	var to := Vector3(target.x - leg.pivot.x, -hip_h, target.z + sole.z - HEEL_Z)
	var l1 := FootPlant.KNEE
	var l2 := sole.length()
	var bend := acos(clampf((l1 * l1 + l2 * l2 - to.length_squared()) / (2.0 * l1 * l2), -1.0, 1.0))
	var sole_dir := atan2(sole.z, sole.y)
	var knee := minf(wrapf(bend - sole_dir, -PI, PI), wrapf(-bend - sole_dir, -PI, PI))
	knee = minf(knee, 0.0)
	var chain := THIGH + Basis(Vector3.RIGHT, knee) * sole
	var out := asin(clampf(-to.x / chain.y, -1.0, 1.0))
	var hip := wrapf(atan2(to.z, to.y) - atan2(chain.z, chain.y * cos(out)), -PI, PI)
	return Vector3(hip, knee, out)
