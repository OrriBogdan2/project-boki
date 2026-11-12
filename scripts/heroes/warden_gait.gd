class_name WardenGait
extends RefCounted
## What a Hero's walk and run clips get from WardenClips so the feet and arms read at the speed he really moves
## (docs/art/ANIM_QUALITY_AUDIT.md). The clips are keyed at a stride that is short for 4.5 m/s, and some swing an arm
## the same side as its leg, so on top of the clip's own pose, once the tree has advanced:
##  - the move speed over the clip's foot speed ("loco.foot_mps": [walk, run]) is shared between playing the clip
##    faster (`plan`, the loco_rate scale) and a longer stride (the thigh and shin turn further about their running
##    mean), so a planted foot stays put on the floor without the cadence going frantic;
##  - "loco.arm_swing": {"L": gain, "R": gain} puts the arm on the opposite swing of its own side's leg: its pitch
##    about the side axis follows minus the leg's, around the arm's running mean (a static arm gets a swing too).
## Everything fades with how much the legs run the body (not in the air, a crouch, or a move that owns the body).

const LEG_BONES := ["thigh.L", "thigh.R"]
const MEAN_TAU := 0.8        # s: the running mean a stride or an arm swing is scaled around
const RATE_MIN := 0.6        # x: slowest the walk and run clips play
const RATE_MAX := 1.4        # x: fastest
const FADE_RATE := 8.0       # 1/s: the gait layer in and out

var skel: Skeleton3D
var gain := 1.0              # x: the thigh stretch at this speed
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

## The clip rate for speed `spd` (m/s) from the "loco" data, and sets `gain`: "stride": [walk, run] stretch of the
## thighs, "foot_mps": [walk, run] foot speed of the clips with it at rate 1 (m/s, tools/anim_audit.gd), between the
## rings at "walk_speed" and "run_speed".
func plan(spd: float, lc: Dictionary) -> float:
	var walk := float(lc.get("walk_speed", 2.2))
	var run := float(lc.get("run_speed", 4.6))
	var t := clampf((spd - walk) / maxf(run - walk, 0.1), 0.0, 1.0)
	var stride: Array = lc.get("stride", [1.0, 1.0])
	var foot: Array = lc.get("foot_mps", [walk, run])
	gain = lerpf(float(stride[0]), float(stride[1]), t)
	return clampf(spd / maxf(lerpf(float(foot[0]), float(foot[1]), t), 0.1), RATE_MIN, RATE_MAX)

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
