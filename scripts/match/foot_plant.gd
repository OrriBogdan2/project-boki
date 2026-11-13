class_name FootPlant
extends RefCounted
## Where the lowest point of a boot sits for a leg pose, so HunterAnim can drop or lift the hips until the
## sole just touches the ground (the Empty, whose boots are the Models.hunter ones). Leg space: x right,
## y up, z back. And (plant) the feet of near Hunters put on the terrain under them.

const HIP := 0.44                  # m: the hip joint's height in Models.hunter's rest pose
const KNEE := 0.2                  # m: knee below the hip joint
## The sole's heel, middle and toe in the knee's space (m): the boot mesh's lowest points along its length (the toe
## tip curves up 1.9 cm, so the toe is the ball it rests on, not the tip).
const SOLE := [Vector3(0.0, -0.263, 0.03), Vector3(0.0, -0.268, -0.06), Vector3(0.0, -0.245, -0.16)]

## How far below the hip joint the boot's lowest point hangs, for the hip's turn (x forward, z out) and the
## knee's bend (x), all in radians.
static func reach(hip: float, knee: float, out: float) -> float:
	var leg := Basis.from_euler(Vector3(hip, 0.0, out))
	var shin := Basis(Vector3.RIGHT, knee)
	var low := 0.0
	for p in SOLE:
		low = maxf(low, -(leg * (Vector3(0.0, -KNEE, 0.0) + shin * (p as Vector3))).y)
	return low

# ==================================================================== feet on the terrain
## HunterAnim and the clips pose the legs for flat ground. On stairs, a stone or a tier lip each foot is moved onto
## the ground under it by a two-bone IK (hip and knee) and the hips drop for the lower foot, so feet neither float
## nor sink. Only the local Hunter and those near them, and never under animation LOD. A .glb body is planted on
## its bones once its clips have posed (WardenGlb's Sync calls bones); the procedural body on the rig nodes.
const META := "foot_plant"     # root meta: this FootPlant, for the .glb body's bones pass
const NEAR := 14.0             # m from the local player: Hunters this near get planted feet
const REACH_DOWN := 0.3        # m: the most a foot reaches down; lower ground is a ledge (it stays on the lip)
const REACH_UP := 0.3          # m: the most a foot lifts; higher ground is a wall or rock (it stays put)
const RATE := 30.0             # 1/s: how fast a swinging foot follows the ground, so a tile edge doesn't pop
const BODY_SLACK := 0.08       # m: a body this far off the terrain (mounted, on a train car) is left alone

var lift := Vector2.ZERO       # m, world: each foot's move onto the ground (left, right), eased
var drop := 0.0                # m, world: the hips' drop, eased
var world: World               # where the ground is, while on
var on := false                # planting this frame (near, not under animation LOD, standing on the terrain)
var weight := 0.0              # how much the pose stands (0 in the air, gliding, diving, mantling, rolling)
var ref := 0.0                 # m, world: the body's height in the game (on the ground: the ground under it)
var lag := 0.0                 # m, world: the drawn body's height off ref while it eases up a step, by weight
var posed := PackedInt32Array()                # the .glb bones the plant turns (_keep)
var kept: Array[Transform3D] = []              # their poses before it did, this frame
var wrote: Array[Transform3D] = []             # and after

## Whether h's feet are planted: the local Hunter and those within NEAR of them.
static func near(h: Hunter) -> bool:
	return h.is_local() or h.m.player == null or h.position.distance_to(h.m.player.position) < NEAR

## After a.update: plants the feet of a.model on w's ground. want: false under animation LOD or far away (the pose
## stays the clip's and nothing is sampled). y: the body's height in the game (Hunter.pos.y; the drawn body sits off
## it while it eases up a step, Hunter.step_vis: a terrace, or one of Tenzo's rocks onto a higher one, and the feet
## stay on the top meanwhile). r: the body's radius, so a rock it stands on counts as Ent.ground counts it.
func plant(a: HunterAnim, w: World, dt: float, want: bool, y := INF, r := 0.0) -> void:
	world = w
	var body := a.model.global_position
	var was := ref
	ref = body.y if is_inf(y) else y
	var off := minf(absf(ref - _ground(w, body, ref, r)), absf(ref - _ground(w, body, ref)))
	weight = (1.0 - a.air_k) * (1.0 - a.glide_k) * (1.0 - a.dive_k) * (1.0 - a.ledge_k)
	if a.roll_t >= 0.0 or off > BODY_SLACK:
		weight = 0.0
	lag = (body.y - ref) * weight
	if weight > 0.01 and absf(ref - was) > StoneStand.POP and absf(ref - was) < REACH_UP:
		lift -= Vector2.ONE * (ref - was)      # the body went up or down a step at once: the feet keep their height
	on = want
	if not on:
		lift = Vector2.ZERO
		drop = 0.0
	if bool(a.model.get_meta("glb", false)):
		a.model.set_meta(META, self)
		return
	if not on or a.knee_l == null or a.knee_r == null:
		return
	var lt := a.legs.global_transform
	if not _settle(lt * foot(a.leg_l, a.knee_l), lt * foot(a.leg_r, a.knee_r), body.y, dt):
		return
	a.rig.position += a.model.global_basis.inverse() * Vector3(0.0, -drop, 0.0)
	var up := a.legs.global_basis.inverse() * Vector3.UP
	_reach(a.leg_l, a.knee_l, up * (lift.x + drop - lag))
	_reach(a.leg_r, a.knee_r, up * (lift.y + drop - lag))

## The .glb body's pass, once its clips have posed: the same plant on its root, thigh and shin bones.
## legs: [thigh.L, shin.L, thigh.R, shin.R] bone indices.
static func bones(root: Node3D, sk: Skeleton3D, legs: PackedInt32Array, dt: float) -> void:
	if not root.has_meta(META) or legs.size() != 4 or legs.has(-1):
		return
	var fp := root.get_meta(META) as FootPlant
	fp._restore(sk)
	if not fp.on:
		return
	var sx := sk.global_transform
	var foot_l := ankle(sk, legs[0], legs[1])
	var foot_r := ankle(sk, legs[2], legs[3])
	if not fp._settle(sx * foot_l, sx * foot_r, root.global_position.y, dt):
		return
	fp._keep(sk, legs)
	var up := sk.global_basis.inverse() * Vector3.UP
	var pelvis := sk.get_bone_parent(legs[0])
	if pelvis >= 0:
		var pose := sk.get_bone_global_pose(pelvis)
		pose.origin -= up * fp.drop
		sk.set_bone_global_pose(pelvis, pose)
		foot_l -= up * fp.drop
		foot_r -= up * fp.drop
	_reach_bones(sk, legs[0], legs[1], foot_l + up * (fp.lift.x + fp.drop - fp.lag))
	_reach_bones(sk, legs[2], legs[3], foot_r + up * (fp.lift.y + fp.drop - fp.lag))
	for i in fp.posed.size():
		fp.wrote[i] = sk.get_bone_pose(fp.posed[i])

## Notes the poses of the bones the plant turns (the legs' parent, thighs, shins, feet) before it turns them.
func _keep(sk: Skeleton3D, legs: PackedInt32Array) -> void:
	if posed.is_empty():
		posed.append(sk.get_bone_parent(legs[0]))
		for b in legs:
			posed.append(b)
		for b in [legs[1], legs[3]]:
			posed.append_array(sk.get_bone_children(b).slice(0, 1))
		posed = PackedInt32Array(Array(posed).filter(func(b): return b >= 0))
		kept.resize(posed.size())
		wrote.resize(posed.size())
		wrote.fill(Transform3D(Basis.IDENTITY * 0.0, Vector3.INF))
	for i in posed.size():
		kept[i] = sk.get_bone_pose(posed[i])

## Puts back the poses the plant wrote last frame on bones nothing has posed since (a bone no clip keys would
## otherwise keep last frame's plant and turn further every frame).
func _restore(sk: Skeleton3D) -> void:
	for i in posed.size():
		if sk.get_bone_pose(posed[i]).is_equal_approx(wrote[i]):
			sk.set_bone_pose(posed[i], kept[i])

## Eases lift and drop toward the ground under the feet at foot_l and foot_r (world); false when there is nothing to do.
## (lag is not eased: it follows the drawn body exactly.)
func _settle(foot_l: Vector3, foot_r: Vector3, body_y: float, dt: float) -> bool:
	var want := Vector2.ZERO
	if weight > 0.01:
		want = Vector2(_offset(world, foot_l, ref, body_y), _offset(world, foot_r, ref, body_y)) * weight
	var follow := 1.0 - exp(-RATE * dt)
	lift = lift.lerp(want, follow)
	if foot_l.y <= foot_r.y:       # the lower foot bears the weight: it stands on the ground at once (no float)
		lift.x = want.x
	else:
		lift.y = want.y
	drop = maxf(lerpf(drop, maxf(0.0, -minf(want.x, want.y)), follow), -minf(lift.x, lift.y))
	return absf(lift.x) > 0.001 or absf(lift.y) > 0.001 or drop > 0.001 or absf(lag) > 0.001

## The terrain's top under p (a stone stand counts, for a body of radius r as Ent.ground counts it), m.
static func _ground(w: World, p: Vector3, body_y: float, r := 0.0) -> float:
	return StoneStand.top_under(w.dyn_walls, Vector3(p.x, body_y, p.z), r, w.ground_at(p.x, p.z))

## How far the ground under a foot at f sits above the body's (ref), 0 when it's out of the legs' reach.
static func _offset(w: World, f: Vector3, ground_ref: float, body_y: float) -> float:
	var d := _ground(w, f, body_y) - ground_ref
	return d if d > -REACH_DOWN and d < REACH_UP else 0.0

## The ankle (the shin's end) in the Legs node's space.
static func foot(leg: Node3D, knee: Node3D) -> Vector3:
	return leg.transform * (knee.transform * Vector3(0.0, -HunterAnim.SHIN, 0.0))

## The ankle in the skeleton's space: the shin's first child bone (the foot), or a thigh's length down the shin.
static func ankle(sk: Skeleton3D, thigh: int, shin: int) -> Vector3:
	var kids := sk.get_bone_children(shin)
	var tip := Vector3(0.0, sk.get_bone_rest(shin).origin.length(), 0.0)
	if not kids.is_empty():
		tip = sk.get_bone_rest(kids[0]).origin
	return sk.get_bone_global_pose(shin) * tip

## Two-bone IK in the Legs node's space: bends the knee and turns the hip so the ankle moves by move,
## keeping the knee a hinge bending the way the clip bent it.
static func _reach(leg: Node3D, knee: Node3D, move: Vector3) -> void:
	var thigh := HunterAnim.THIGH
	var shin := HunterAnim.SHIN
	var to := foot(leg, knee) + move - leg.position
	var span := clampf(to.length(), absf(thigh - shin) + 0.01, thigh + shin - 0.001)
	var bend := acos(clampf((span * span - thigh * thigh - shin * shin) / (2.0 * thigh * shin), -1.0, 1.0))
	knee.rotation.x = bend if knee.rotation.x > 0.0 else -bend
	var now := leg.basis * (Vector3(0.0, -thigh, 0.0) + knee.basis * Vector3(0.0, -shin, 0.0))
	leg.basis = Basis(Quaternion(now.normalized(), to.normalized())) * leg.basis

## Two-bone IK on the skeleton (its space): turns the thigh and shin bones so the ankle reaches tgt, the knee
## bending in the plane the clip bent it in; the foot keeps the clip's turn.
static func _reach_bones(sk: Skeleton3D, thigh: int, shin: int, tgt: Vector3) -> void:
	var tp := sk.get_bone_global_pose(thigh)
	var sp := sk.get_bone_global_pose(shin)
	var kids := sk.get_bone_children(shin)
	var foot := kids[0] if not kids.is_empty() else -1
	var fp := sk.get_bone_global_pose(foot) if foot >= 0 else Transform3D.IDENTITY
	var hip := tp.origin
	var knee := sp.origin
	var ankle := ankle(sk, thigh, shin)
	var upper := hip.distance_to(knee)
	var lower := knee.distance_to(ankle)
	var to := tgt - hip
	var span := clampf(to.length(), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var dir := to.normalized()
	var side := (knee - hip) - dir * (knee - hip).dot(dir)
	if side.length_squared() < 1e-8:
		side = tp.basis.z - dir * tp.basis.z.dot(dir)
	side = side.normalized()
	var ca := clampf((upper * upper + span * span - lower * lower) / (2.0 * upper * span), -1.0, 1.0)
	var knee_to := hip + dir * (upper * ca) + side * (upper * sqrt(1.0 - ca * ca))
	var turn_t := Basis(Quaternion((knee - hip).normalized(), (knee_to - hip).normalized()))
	sk.set_bone_global_pose(thigh, Transform3D(turn_t * tp.basis, hip))
	var shin_dir := turn_t * (ankle - knee)
	var turn_s := Basis(Quaternion(shin_dir.normalized(), (hip + dir * span - knee_to).normalized()))
	sk.set_bone_global_pose(shin, Transform3D(turn_s * turn_t * sp.basis, knee_to))
	if foot >= 0:
		sk.set_bone_global_pose(foot, Transform3D(fp.basis, sk.get_bone_global_pose(foot).origin))
