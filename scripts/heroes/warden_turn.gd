class_name WardenTurn
extends RefCounted
## Turning on the spot on a Hero's clips (the model's TurnStep, which HunterAnim ticks): the root bone and the legs
## on it turn back by the step's lag while the hips take it back, so the feet stay put and the upper body follows
## the aim. In a step the other foot is planted where it stood (its leg reaches back for it) and the stepping foot
## lifts and swings round, then is held where it lands; the body shifts over planted feet a wide stance can no
## longer reach. Moving, a shot or a cast lets the feet go. Run by WardenClips after the clips' pose.

const REACH := 0.995          # of the leg's length: the farthest a planted foot is reached for
const SETTLE := 0.3           # s: the body drifts back over its middle when the feet let it
const RELEASE := 0.1          # s: a planted foot comes back under the body when a step is cancelled

var model: Node3D
var skel: Skeleton3D
var bi_root := -1
var bi_hips := -1
var thighs: Array[int] = []
var shins: Array[int] = []
var shin_len: Array[float] = []      # m (skeleton space): shin head to ankle
var leg_len: Array[float] = []       # m (skeleton space): hip to ankle, the leg straight
var pin: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]     # world: where a planted foot stays
var pin_w: Array[float] = [0.0, 0.0]                       # how much each foot holds to its pin
var off := Vector3.ZERO       # world, level: the body shifted over its planted feet
var stepping := false        # a step was under way last frame
var seen := 0                 # the last TurnStep.serial handled

## null when the skeleton has no legs to step with.
static func make(m: Node3D, sk: Skeleton3D) -> WardenTurn:
	var w := WardenTurn.new()
	w.model = m
	w.skel = sk
	w.bi_root = WardenSkeleton.find(sk, "root")
	w.bi_hips = WardenSkeleton.find(sk, "hips")
	for side in ["L", "R"]:
		var th := WardenSkeleton.find(sk, "thigh." + side)
		var sh := WardenSkeleton.find(sk, "shin." + side)
		if th < 0 or sh < 0:
			return null
		w.thighs.append(th)
		w.shins.append(sh)
		w.shin_len.append(_shin_len(sk, sh))
		w.leg_len.append(sk.get_bone_rest(sh).origin.length() + w.shin_len[-1])
	return w if w.bi_root >= 0 and w.bi_hips >= 0 else null

## The shin's length: to its foot bone, or the rig's shin-to-thigh ratio of the thigh.
static func _shin_len(sk: Skeleton3D, sh: int) -> float:
	for c in sk.get_bone_children(sh):
		if sk.get_bone_name(c).begins_with("foot"):
			return sk.get_bone_rest(c).origin.length()
	return sk.get_bone_rest(sh).origin.length() * HunterAnim.SHIN / HunterAnim.THIGH

func step(dt: float) -> void:
	var ts := model.get_meta(TurnStep.META, null) as TurnStep
	if ts == null:
		return
	var lag := ts.lag_at(model.rotation.y)
	if absf(lag) < 0.001 and ts.t < 0.0 and pin_w[0] <= 0.0 and pin_w[1] <= 0.0 \
			and off.length_squared() < 0.000001:
		return
	_turn_legs(lag)
	var to_world := skel.global_transform
	_settle(to_world, dt, ts.held)
	if ts.serial != seen:
		seen = ts.serial
		_plant(1 - ts.swing, to_world)
	elif stepping and ts.t < 0.0 and ts.held:
		_plant(ts.swing, to_world)
	stepping = ts.t >= 0.0
	_hold(to_world)
	for f in 2:
		if not ts.held:
			pin_w[f] = move_toward(pin_w[f], 0.0, dt / RELEASE)
		elif ts.t >= 0.0 and f == ts.swing:
			pin_w[f] = minf(pin_w[f], 1.0 - smoothstep(0.0, 1.0, ts.progress()))
		if pin_w[f] > 0.0:
			_reach(f, ankle(f).lerp(to_world.affine_inverse() * pin[f], pin_w[f]))
		_lift(f, ts.lift(f))

## A foot held where it stands (one a step pivots on, or one just put down).
func _plant(f: int, to_world: Transform3D) -> void:
	if pin_w[f] < 1.0:
		pin[f] = to_world * ankle(f)
		pin_w[f] = 1.0

## The legs (on the root bone) turned by lag about the model's upright axis (where it turns, not the bone's
## head, so the feet stay put); the hips take it back.
func _turn_legs(lag: float) -> void:
	var to_sk := skel.global_transform.affine_inverse()
	var par := skel.get_bone_parent(bi_root)
	if par >= 0:
		to_sk = skel.get_bone_global_pose(par).affine_inverse() * to_sk
	var at := to_sk * model.global_position
	var turn := Transform3D(Basis((to_sk.basis * Vector3.UP).normalized(), lag), Vector3.ZERO)
	turn.origin = at - turn.basis * at
	var was := skel.get_bone_pose(bi_root)
	var now := turn * was
	skel.set_bone_pose_position(bi_root, now.origin)
	skel.set_bone_pose_rotation(bi_root, now.basis.get_rotation_quaternion())
	var hips := now.affine_inverse() * was * skel.get_bone_pose(bi_hips)
	skel.set_bone_pose_position(bi_hips, hips.origin)
	skel.set_bone_pose_rotation(bi_hips, hips.basis.get_rotation_quaternion())

## The body (the root bone) shifted level by `off`, which drifts back to its middle (SETTLE).
func _settle(to_world: Transform3D, dt: float, held: bool) -> void:
	off = off.lerp(Vector3.ZERO, 1.0 - exp(-dt / (SETTLE if held else RELEASE)))
	var root := skel.get_bone_global_pose(bi_root)
	root.origin += to_world.basis.inverse() * off
	skel.set_bone_global_pose(bi_root, root)

## The body shifted over the planted feet just enough that each leg still reaches its pin (a wide stance turning
## round its middle takes a hip off its foot).
func _hold(to_world: Transform3D) -> void:
	var to_sk := to_world.affine_inverse()
	var up := (to_sk.basis * Vector3.UP).normalized()
	var root := skel.get_bone_global_pose(bi_root)
	for i in 2:
		var by := Vector3.ZERO
		for f in 2:
			if pin_w[f] < 1.0:
				continue
			var v := to_sk * pin[f] - skel.get_bone_global_pose(thighs[f]).origin
			var level := v - up * v.dot(up)
			var most := sqrt(maxf(0.0, (REACH * leg_len[f]) ** 2 - v.dot(up) ** 2))
			if level.length() > most:
				by += level.normalized() * (level.length() - most)
		if by.length_squared() <= 0.0:
			return
		root.origin += by
		skel.set_bone_global_pose(bi_root, root)
		off += to_world.basis * by

## A foot's ankle, skeleton space.
func ankle(f: int) -> Vector3:
	return skel.get_bone_global_pose(shins[f]) * Vector3(0, shin_len[f], 0)

## The ankle to `to` (skeleton space): the knee bent so the leg reaches that far, then the thigh aimed at it.
func _reach(f: int, to: Vector3) -> void:
	var hip := skel.get_bone_global_pose(thighs[f]).origin
	var knee := skel.get_bone_global_pose(shins[f])
	var at := ankle(f)
	var want := hip.distance_to(to)
	var axis := (knee.origin - hip).cross(at - knee.origin)
	if axis.length_squared() > 0.000001:
		# the shin turned about the knee's hinge; of the two ways, the one that brings the ankle nearest `want`
		var a := hip.distance_to(knee.origin)
		var b := knee.origin.distance_to(at)
		var bend := acos(clampf((a * a + b * b - minf(want, (a + b) * 0.999) ** 2) / (2.0 * a * b), -1.0, 1.0)) \
				- acos(clampf((a * a + b * b - hip.distance_squared_to(at)) / (2.0 * a * b), -1.0, 1.0))
		axis = axis.normalized()
		var best := Basis(axis, bend)
		if absf(hip.distance_to(knee.origin + best * (at - knee.origin)) - want) \
				> absf(hip.distance_to(knee.origin + Basis(axis, -bend) * (at - knee.origin)) - want):
			best = Basis(axis, -bend)
		knee.basis = best * knee.basis
		skel.set_bone_global_pose(shins[f], knee)
	_aim(f, ankle(f), to)

## The thigh turned about the hip so the ankle at `from` goes to `to`.
func _aim(f: int, from: Vector3, to: Vector3) -> void:
	var hip := skel.get_bone_global_pose(thighs[f])
	var a := from - hip.origin
	var b := to - hip.origin
	if a.cross(b).length_squared() < 0.0000001:
		return
	hip.basis = Basis(Quaternion(a.normalized(), b.normalized())) * hip.basis
	skel.set_bone_global_pose(thighs[f], hip)

## The knee forward by `raise` (rad) about the legs' side axis, the shin folded back under it.
func _lift(f: int, raise: float) -> void:
	if raise <= 0.0:
		return
	var side := skel.get_bone_global_pose(bi_root).basis.x.normalized()
	var hip := skel.get_bone_global_pose(thighs[f])
	hip.basis = Basis(side, raise) * hip.basis
	skel.set_bone_global_pose(thighs[f], hip)
	var knee := skel.get_bone_global_pose(shins[f])
	knee.basis = Basis(side, -raise * TurnStep.FOLD) * knee.basis
	skel.set_bone_global_pose(shins[f], knee)
