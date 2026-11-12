class_name WardenGait
extends RefCounted
## What a Hero's walk and run clips get from WardenClips so the feet and arms read at the speed he really moves
## (docs/art/ANIM_QUALITY_AUDIT.md). The clips are keyed at a stride that is short for 4.5 m/s, and some swing an arm
## the same side as its leg, so on top of the clip's own pose, once the tree has advanced:
##  - the walk, run and sneak loops play at the ground speed over the speed their planted soles run back at
##    ("loco.foot_mps": [walk, run], "crouch.foot_mps": m/s at rate 1 with the thighs' stretch about their running
##    mean, "loco.stride": [walk, run]; `--anim-audit --fit-soles`), so a planted foot stays put under a
##    Slow, a haste, a carry or a sneak. A loop whose sole runs back under GLIDE_K of its ring's speed glides (skates,
##    a hover) and plays at the ground over the ring's speed; "loco.cadence" pins the run's rate at its ring speed
##    to a source's footfalls, eased in from the walk's (it scurries or plods; its feet slide);
##  - the run ring shows from RUN_FROM of the walk's speed and hands back under RUN_BACK (`ring`), not a blend of
##    the two at a jog;
##  - "loco.arm_swing": {"L": gain, "R": gain} puts the arm on the opposite swing of its own side's leg: its pitch
##    about the side axis follows minus the leg's, around the arm's running mean (a static arm gets a swing too).
## Everything fades with how much the legs run the body (not in the air, a crouch, or a move that owns the body).

const LEG_BONES := ["thigh.L", "thigh.R"]
const MEAN_TAU := 0.8        # s: the running mean a stride or an arm swing is scaled around
const RATE_MIN := 0.3        # x: slowest a loop plays
const RATE_MAX := 3.0        # x: fastest (a short stride near the top of its ring)
const WALK_R := 0.45         # the walk ring's radius in the loco blend space (the run ring's is 1)
const RUN_FROM := 1.3        # of the walk's speed: faster than this shows the run ring...
const RUN_BACK := 1.2        # ...and slower than this hands back to the walk
const RUN_R_MIN := 0.95      # the run ring's least radius: under its speed a little walk stays in
const GLIDE_K := 0.2         # a loop whose sole runs back slower than this of its ring's speed glides
const FADE_RATE := 8.0       # 1/s: the gait layer in and out

var skel: Skeleton3D
var gain := 1.0              # x: the thigh stretch at this speed
var on_run := false          # the run ring is showing, not the walk
var legs_w := 0.0
var arm_w := 0.0
var legs: Array = []         # [bone index, running mean rotation]
var arms: Array = []         # [upper arm, its parent, same-side thigh, hand, gain, arm mean pitch, thigh mean pitch]

func _init(sk: Skeleton3D, swing: Dictionary) -> void:
	skel = sk
	for b in LEG_BONES:
		var bi := WardenSkeleton.find(sk, b)
		if bi >= 0:
			legs.append([bi, sk.get_bone_pose_rotation(bi)])
	for side in swing:
		var ai := WardenSkeleton.find(sk, "upper_arm." + String(side))
		var hi := WardenSkeleton.find(sk, "hand." + String(side))
		var ti := WardenSkeleton.find(sk, "thigh." + String(side))
		if ai >= 0 and hi >= 0 and ti >= 0:
			arms.append([ai, sk.get_bone_parent(ai), ti, hi, float(swing[side]), NAN, NAN])

## How far out in the loco blend space speed `spd` (m/s) wants the walk and run loops: out with the speed over
## "loco.run_speed" (the run ring's), a little run in the walk past its speed, then (nearly) the whole run ring from
## RUN_FROM of "loco.walk_speed" (no even blend of the two at a jog).
func ring(spd: float, lc: Dictionary, still: float) -> float:
	var walk := float(lc.get("walk_speed", 2.2))
	on_run = spd >= walk * (RUN_BACK if on_run else RUN_FROM)
	if spd < still:
		return 0.0
	var k := minf(spd / float(lc.get("run_speed", 4.6)), 1.0)
	return maxf(k, RUN_R_MIN) if on_run else k

## The walk and run loops' rate at speed `spd` with the blend `at` out from the idle (loco_pos.length()), and sets
## `gain` (the thighs' stretch). Between the rings the soles mix as the blend does; off the idle they scale with it.
func plan(spd: float, lc: Dictionary, at: float) -> float:
	var walk := float(lc.get("walk_speed", 2.2))
	var run := float(lc.get("run_speed", 4.6))
	var t := clampf((at - WALK_R) / (1.0 - WALK_R), 0.0, 1.0)
	var stride: Array = lc.get("stride", [1.0, 1.0])
	var foot: Array = lc.get("foot_mps", [walk, run])
	gain = lerpf(float(stride[0]), float(stride[1]), t)
	var walk_sole := sole(float(foot[0]), walk)
	var run_sole := sole(float(foot[1]), run)
	if lc.has("cadence"):      # (pinned at the run's speed, eased in over the walk to run band)
		run_sole = lerpf(run_sole, run / float(lc["cadence"]), clampf((spd - walk) / maxf(run - walk, 0.1), 0.0, 1.0))
	return rate(spd, lerpf(walk_sole, run_sole, t) * minf(at / WALK_R, 1.0))

## The sneak loops' rate ("crouch.foot_mps", "crouch.speed": its ring) with the blend `at` out from its idle.
static func crouch_rate(spd: float, cr: Dictionary, at: float) -> float:
	var speed := float(cr.get("speed", 2.4))
	var foot := float(cr.get("foot_mps", speed))
	return rate(spd, sole(foot, speed) * minf(at, 1.0))

## m/s a loop's planted soles run back at, or its ring's speed when they are too slow to plant: it glides.
static func sole(back: float, ring_mps: float) -> float:
	return back if back >= ring_mps * GLIDE_K else ring_mps

## The one rate rule: the ground speed over the speed the loop shown was authored at.
static func rate(spd: float, sole_mps: float) -> float:
	return clampf(spd / sole_mps, RATE_MIN, RATE_MAX) if sole_mps > 0.01 else 1.0

## After tree.advance. `legs_k`, `arm_k` 0..1: how much locomotion owns the legs and the arms this frame.
func apply(dt: float, legs_k: float, arm_k: float) -> void:
	legs_w = move_toward(legs_w, legs_k, FADE_RATE * dt)
	arm_w = move_toward(arm_w, arm_k, FADE_RATE * dt)
	var a := 1.0 - exp(-dt / MEAN_TAU)
	var k := 1.0 + (gain - 1.0) * legs_w
	for l in legs:
		var q := skel.get_bone_pose_rotation(l[0])
		var m: Quaternion = l[1]
		l[1] = m.slerp(q, a)
		if legs_w > 0.0:
			skel.set_bone_pose_rotation(l[0], (m * Quaternion.IDENTITY.slerp(m.inverse() * q, k)).normalized())
	for r in arms:
		var arm_p := _pitch(skel.get_bone_global_pose(r[3]).origin - skel.get_bone_global_pose(r[0]).origin)
		var leg_p := _pitch(skel.get_bone_global_pose(r[2]).basis.y)
		r[5] = arm_p if is_nan(r[5]) else lerp_angle(r[5], arm_p, a)     # (a first frame is its own mean)
		r[6] = leg_p if is_nan(r[6]) else lerp_angle(r[6], leg_p, a)
		if arm_w <= 0.0:
			continue
		var turn := (float(r[5]) - float(r[4]) * angle_difference(r[6], leg_p) - arm_p) * arm_w
		var pq := _basis_q(r[1])
		var q := skel.get_bone_pose_rotation(r[0])
		skel.set_bone_pose_rotation(r[0], pq.inverse() * Quaternion(Vector3.RIGHT, turn) * pq * q)

## How far forward (rad, + forward, -Z) a direction points from straight down.
func _pitch(dir: Vector3) -> float:
	return atan2(-dir.z, -dir.y)

func _basis_q(bi: int) -> Quaternion:
	if bi < 0:
		return Quaternion.IDENTITY
	return skel.get_bone_global_pose(bi).basis.orthonormalized().get_rotation_quaternion()
