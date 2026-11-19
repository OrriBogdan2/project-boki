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
##  - "loco.bob": [walk, run] the hips' up and down about their running mean is scaled by it (0..1) for a clip that
##    bobs too far for the speed (Grimble 17 cm, Kael 16 cm at a run). The clip's bob is the root bone's, which the
##    thighs hang from too, so only the hips and what hangs from them (torso, arms, head) are held back: the feet stay
##    planted.
##  - the hips rise and fall with the legs' spread, the way a body moves over its feet: in a walk they are highest as
##    the legs pass (feet together) and lowest with the legs apart; in a run lowest as the legs pass (the push-off)
##    and highest with the legs apart (the flight). A clip keyed the other way round is pulled towards it, at most
##    BOB_FIX_MAX; "loco.bob_m": [walk, run] is the up and down travel that aims at (m). Only as far as the blend
##    points forward or back: a strafe's legs spread sideways, not in pitch, so it keeps its clip's own bob; and by
##    "loco.bob_fix": [walk, run] (default 1: 0 for a clip already in step, which the pull only roughens).
##  - "loco.foot_lock": [walk, run] (0..1, default 0) holds a foot where it came down while it is on the ground (the
##    lowest LOCK_BAND of its own height range), the ground under it going back at the body's speed, by the legs'
##    two-bone IK (FootPlant.reach_bones), at most LOCK_PULL of the leg off the clip's ankle; lifted, it eases back
##    onto the clip. For run clips whose planted foot sweeps back unevenly, which no playback rate keeps planted
##    (Albert, Lace, Neve). The ground's way is the blend's (`pos`), so a run-and-aim's turned legs lock true.
## Everything fades with how much the legs run the body (not in the air, a crouch, or a move that owns the body).

const LEG_BONES := ["thigh.L", "thigh.R"]
const MEAN_TAU := 0.8  # s: the running mean a stride or an arm swing is scaled around
const RATE_MIN := 0.6  # x: slowest the walk and run clips play
const RATE_MAX := 1.4  # x: fastest
const FADE_RATE := 8.0  # 1/s: the gait layer in and out
const BOB_M := [0.035, 0.06]  # m: the hips' up and down travel at a walk and at a run
const BOB_FIX_MAX := 0.04  # m: furthest the hips are moved off the clip's height to put the bob in step with the legs
const SPREAD_TAU := 2.0  # s: how fast the widest leg spread seen fades (a slower stride re-learns it)
const LOCK_BAND := 0.6  # share of an ankle's height range from its lowest that counts as on the ground
const LOCK_RANGE_TAU := 1.0  # s: how fast the ankle's lowest and highest seen ease toward its height
const LOCK_PULL := 0.6  # share of the leg's length the lock may hold the ankle off the clip's
const LOCK_EASE_TAU := 0.05  # s: a lifted foot easing back onto the clip

var skel: Skeleton3D
var bob := 1.0  # x: the hips' vertical travel at this speed
var bob_m := 0.035  # m: the hips' up and down travel at this speed
var bob_sign := -1.0  # -1 walk (high when the legs pass), +1 run (low when they pass), 0 between
var spread_mean := 0.0  # rad: running mean of the legs' pitch spread
var spread_peak := 0.0  # rad: the widest spread above the mean, fading
var pull := 1.0  # 0..1: how far the bob is pulled in step (forward or back, not sideways; "bob_fix")
var hips := -1  # hips bone index
var hips_rest_y := 0.0  # m: the hips' local height at rest (the clips key no hips position)
var hips_keyed := false  # the clips do key it (data "offset_bones": Motley's spring): their height, not the rest
var hips_y := NAN  # m: running mean of the hips' height (skeleton space)
var gain := 1.0  # x: the thigh stretch at this speed
var lock := 0.0  # 0..1: the foot lock at this speed ("foot_lock")
var ground_v := Vector3.ZERO  # m/s: the body's velocity in the legs' frame (the blend's way, x right, -z forward)
var legs_w := 0.0
var arm_w := 0.0
var legs: Array = []  # [bone index, running mean rotation]
var feet: Array = []  # [thigh, shin, leg length, lock offset, last clip ankle, lowest, highest, down]
var arms: Array = []  # [upper arm, its parent, same-side thigh, hand, gain, arm mean pitch, thigh mean pitch]
var walk_len := 1.0  # s: one cycle of the forward walk clip at rate 1
var run_len := 1.0  # s: of the forward run clip


func _init(sk: Skeleton3D, swing: Dictionary, walk_s: float, run_s: float, keyed := false) -> void:
	skel = sk
	walk_len = walk_s
	run_len = run_s
	hips_keyed = keyed
	for b in LEG_BONES:
		var bi := WardenSkeleton.find(sk, b)
		if bi >= 0:
			legs.append([bi, sk.get_bone_pose_rotation(bi)])
			var si := WardenSkeleton.find(sk, String(b).replace("thigh", "shin"))
			if si >= 0:
				var span := sk.get_bone_global_rest(si).origin.distance_to(sk.get_bone_global_rest(bi).origin)
				feet.append([bi, si, 2.0 * span, Vector3.ZERO, Vector3.ZERO, INF, -INF, false])
	hips = WardenSkeleton.find(sk, "hips")
	if hips >= 0:
		hips_rest_y = sk.get_bone_pose_position(hips).y
	for side in swing:
		var ai := WardenSkeleton.find(sk, "upper_arm." + String(side))
		var hi := WardenSkeleton.find(sk, "hand." + String(side))
		var ti := WardenSkeleton.find(sk, "thigh." + String(side))
		if ai >= 0 and hi >= 0 and ti >= 0:
			arms.append([ai, sk.get_bone_parent(ai), ti, hi, float(swing[side]), NAN, NAN])


## The loco_rate scale for speed `spd` (m/s) at `w` of the way from the walk ring to the run ring, from the "loco"
## data, and sets `gain` and `bob`: "stride": [walk, run] stretch of the thighs, "foot_mps": [walk, run] foot speed of
## the clips with it at rate 1 (m/s, tools/anim_audit.gd), "bob": [walk, run]. "side_foot_mps" (optional, same shape)
## is the strafe loops' own, mixed in by how far `pos` (the blend position, x right, y forward) points sideways. The
## walk plays stretched to the run's cycle (WardenClips._gait_loop), so the blend steps as one cycle of the blended
## length and covers the blended stride: the rate that keeps that stride planted at this speed, clamped as the clips
## feel it (a hasted run, up to HunterMove.speed_cap, keeps its feet planted instead of sliding at RATE_MAX).
## (Held at a speed, `w` is the speed's share from "walk_speed" to "run_speed".)
func plan(spd: float, lc: Dictionary, pos: Vector2, w: float) -> float:
	var stride: Array = lc.get("stride", [1.0, 1.0])
	var foot: Array = lc.get("foot_mps", [lc.get("walk_speed", 2.2), lc.get("run_speed", 4.6)])
	var side: Array = lc.get("side_foot_mps", foot)
	var side_k := absf(pos.x) / maxf(absf(pos.x) + absf(pos.y), 0.01)
	var walk_mps := lerpf(float(foot[0]), float(side[0]), side_k)
	var run_mps := lerpf(float(foot[1]), float(side[1]), side_k)
	gain = lerpf(float(stride[0]), float(stride[1]), w)
	var fl: Array = lc.get("foot_lock", [0.0, 0.0])
	lock = lerpf(float(fl[0]), float(fl[1]), w)
	ground_v = Vector3(pos.x, 0.0, -pos.y).normalized() * spd
	var b: Array = lc.get("bob", [1.0, 1.0])
	bob = lerpf(float(b[0]), float(b[1]), w)
	var bm: Array = lc.get("bob_m", BOB_M)
	bob_m = lerpf(float(bm[0]), float(bm[1]), w)
	bob_sign = clampf((w - 0.5) * 4.0, -1.0, 1.0)
	var bf: Array = lc.get("bob_fix", [1.0, 1.0])
	pull = (1.0 - side_k) * lerpf(float(bf[0]), float(bf[1]), w)
	var cycle := lerpf(walk_len, run_len, w)
	var reach := lerpf(walk_mps * walk_len, run_mps * run_len, w)  # m a foot travels in a cycle
	var top := RATE_MAX * maxf(1.0, spd / maxf(run_mps, 0.1))  # hasted past the run clip: ceiling grows
	return clampf(spd * cycle / maxf(reach, 0.01), RATE_MIN, top) * run_len / cycle


## After tree.advance. `legs_k`, `arm_k` 0..1: how much locomotion owns the legs and the arms this frame.
func apply(dt: float, legs_k: float, arm_k: float) -> void:
	legs_w = move_toward(legs_w, legs_k, FADE_RATE * dt)
	arm_w = move_toward(arm_w, arm_k, FADE_RATE * dt)
	var a := 1.0 - exp(-dt / MEAN_TAU)
	var k := 1.0 + (gain - 1.0) * legs_w
	if hips >= 0:
		var hp := skel.get_bone_pose_position(hips)
		# (a clip that keys the hips set this frame's height; else it is the rest plus last frame's offset of ours)
		var base := hp.y if hips_keyed else hips_rest_y
		var gy := skel.get_bone_global_pose(hips).origin.y - (hp.y - base)  # (the clip's, without our offset)
		hips_y = gy if is_nan(hips_y) else lerpf(hips_y, gy, a)
		var dev := (gy - hips_y) * bob
		hp.y = base - (gy - hips_y) * (1.0 - bob) * legs_w
		hp.y += clampf(_bob_target(a, dt) - dev, -BOB_FIX_MAX, BOB_FIX_MAX) * legs_w * pull
		skel.set_bone_pose_position(hips, hp)
	for l in legs:
		var q := skel.get_bone_pose_rotation(l[0])
		var m: Quaternion = l[1]
		l[1] = m.slerp(q, a)
		if legs_w > 0.0:
			skel.set_bone_pose_rotation(l[0], (m * Quaternion.IDENTITY.slerp(m.inverse() * q, k)).normalized())
	_lock_feet(dt)
	for r in arms:
		var arm_p := _pitch(skel.get_bone_global_pose(r[3]).origin - skel.get_bone_global_pose(r[0]).origin)
		var leg_p := _pitch(skel.get_bone_global_pose(r[2]).basis.y)
		r[5] = arm_p if is_nan(r[5]) else lerp_angle(r[5], arm_p, a)  # (a first frame is its own mean)
		r[6] = leg_p if is_nan(r[6]) else lerp_angle(r[6], leg_p, a)
		if arm_w <= 0.0:
			continue
		var turn := (float(r[5]) - float(r[4]) * angle_difference(r[6], leg_p) - arm_p) * arm_w
		var pq := _basis_q(r[1])
		var q := skel.get_bone_pose_rotation(r[0])
		skel.set_bone_pose_rotation(r[0], pq.inverse() * Quaternion(Vector3.RIGHT, turn) * pq * q)


## The foot lock ("foot_lock"), skeleton space: a foot on the ground keeps its spot as the clip sweeps it back.
func _lock_feet(dt: float) -> void:
	var on := lock * legs_w
	if on <= 0.0:
		for f in feet:
			f[3] = Vector3.ZERO
			f[7] = false
		return
	var ground := ground_v * dt / skel.global_basis.get_scale()  # how far the body moved over the ground
	var a := 1.0 - exp(-dt / LOCK_RANGE_TAU)
	var back := 1.0 - exp(-dt / LOCK_EASE_TAU)
	for f in feet:
		var ank := FootPlant.ankle(skel, f[0], f[1])
		f[5] = minf(ank.y, lerpf(f[5], ank.y, a)) if f[5] < INF else ank.y
		f[6] = maxf(ank.y, lerpf(f[6], ank.y, a)) if f[6] > -INF else ank.y
		var down := ank.y <= float(f[5]) + LOCK_BAND * maxf(float(f[6]) - float(f[5]), 0.02)
		var off: Vector3 = f[3]
		if down and f[7]:
			off += f[4] - ank - ground  # the spot stays as the clip's ankle moves and the ground goes by
			off.y = 0.0
		elif not down:
			off = off.lerp(Vector3.ZERO, back)
		off = off.limit_length(LOCK_PULL * float(f[2]))
		f[3] = off
		f[4] = ank
		f[7] = down
		if off.length_squared() > 1e-8:
			FootPlant.reach_bones(skel, f[0], f[1], ank + off * on)


## How far forward (rad, + forward, -Z) a direction points from straight down.
func _pitch(dir: Vector3) -> float:
	return atan2(-dir.z, -dir.y)


func _basis_q(bi: int) -> Quaternion:
	if bi < 0:
		return Quaternion.IDENTITY
	return skel.get_bone_global_pose(bi).basis.orthonormalized().get_rotation_quaternion()


## Where the hips should be about their mean (m): `bob_m` of travel, with the legs' pitch spread: the thighs' angle
## apart, as a share of the widest seen. `a`: the running-mean step of this frame, `dt` its length.
func _bob_target(a: float, dt: float) -> float:
	if legs.size() < 2:
		return 0.0
	var spread := absf(
		angle_difference(
			_pitch(skel.get_bone_global_pose(legs[0][0]).basis.y), _pitch(skel.get_bone_global_pose(legs[1][0]).basis.y)
		)
	)
	spread_mean = lerpf(spread_mean, spread, a)
	spread_peak = maxf(spread - spread_mean, spread_peak * exp(-dt / SPREAD_TAU))
	return bob_sign * 0.5 * bob_m * clampf((spread - spread_mean) / maxf(spread_peak, 0.05), -1.0, 1.0)
