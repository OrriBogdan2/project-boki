class_name WardenReach
extends RefCounted
## An arm that reaches out to a point in the world (Grimble's Deep Reach, owner playtest 11-11): his own arm, not a
## drawn one. While a kit sets the root meta TIP, the upper arm and forearm lie straight along the line from the
## shoulder to the tip, the forearm stretches so the hand (and everything riding it: his slime hand and bone crescent)
## sits at the tip, and the hand turns down the line. The clips can't move it meanwhile, so it holds still on the aim
## line whatever the body plays (no flailing); it eases in from the clip's wind-up and back to the clips after.
## Data "reach": {"bones": [upper arm, forearm, hand], "grip": m from the hand joint to the middle of what it grips,
## "max_stretch": how far the forearm may stretch (default: as far as the tip), "level": the arm lies level whatever
## the tip's height}. A second instance, data "gun_reach" on the meta GUN_TIP, holds his gun arm straight out along the
## aim without stretching (Brass Broadside); `aim` turns its hand so the gun's muzzle (not the bone) points down the arm.

const TIP := "reach_tip"  # root meta: the world point the hand reaches to; unset (or INF) when the arm is home
const GUN_TIP := "gun_reach_tip"  # root meta: the same for the gun arm ("gun_reach")
const IN_RATE := 14.0  # 1/s: the arm takes the aim line (0.07 s out of the wind-up)
const OUT_RATE := 9.0  # 1/s: and gives it back to the clips (0.11 s)
const GIRTH := 1.6  # x: the forearm's thickness once stretched to 3x and more (a long reach is no string)
const RETRACT := 70.0  # skeleton units (m at size 1)/s: the hand comes home down the line (full reach 0.13 s)

var skel: Skeleton3D
var bones: Array = []  # [upper arm, forearm, hand] bone indices
var grip := 0.0  # m: wrist to the middle of the hand's grip
var max_stretch := 99.0  # x the forearm's length it may stretch to
var meta := TIP  # the root meta that holds this arm's tip
var level := false  # the arm lies level (the tip's height is the shoulder's)
var aim := Vector3.ZERO  # the hand's own direction that points down the line (ZERO: the bone's length)
var w := 0.0  # how much the reach owns the arm
var tip := Vector3.INF  # the last tip, in skeleton space (kept while the arm eases home)


## Null when the data has no `key` ("reach" or "gun_reach").
static func make(sk: Skeleton3D, d: Dictionary, key := "reach") -> WardenReach:
	var rd: Dictionary = d.get(key, {})
	if rd.is_empty():
		return null
	var r := WardenReach.new()
	r.skel = sk
	for b in rd["bones"]:
		r.bones.append(WardenSkeleton.find(sk, String(b)))
	if r.bones.has(-1):
		return null
	r.grip = float(rd["grip"])
	r.max_stretch = float(rd.get("max_stretch", 99.0))
	r.level = bool(rd.get("level", false))
	return r


## Every reach arm the data names, for a model on Meshy's own skeleton: "reach" (the Deep Reach, root meta TIP) and
## "gun_reach" (the gun arm, GUN_TIP; its hand turns so the holster's `muzzle` points down the arm).
static func make_all(sk: Skeleton3D, d: Dictionary, holster: Dictionary) -> Array:
	var out := []
	for key in ["reach", "gun_reach"]:
		var r := make(sk, d, key)
		if r == null:
			continue
		if key == "gun_reach":
			r.meta = GUN_TIP
			var m: Array = holster.get("hand", {}).get("muzzle", [])
			if m.size() == 3:
				r.aim_rest(Vector3(float(m[0]), float(m[1]), float(m[2])))
		out.append(r)
	return out


## Before the clips advance, on a skeleton whose clips key no scale (Meshy's): the arm's stretch of the last frame goes,
## or each frame would stretch the stretched arm again.
func rest_scale() -> void:
	for bi: int in bones:
		skel.set_bone_pose_scale(bi, skel.get_bone_rest(bi).basis.get_scale())


## The hand points its `rest_dir` (a direction in the skeleton's rest pose, as the gun socket's muzzle) down the arm.
func aim_rest(rest_dir: Vector3) -> void:
	aim = (skel.get_bone_global_rest(bones[2]).basis.inverse() * rest_dir).normalized()


## After the clips. `world_tip`: the root's TIP meta (INF when the arm is home). Let go, the hand comes back down the
## line at RETRACT, then the arm eases back into the clips.
func apply(dt: float, world_tip: Vector3) -> void:
	var out := world_tip.is_finite()
	if out:
		tip = skel.global_transform.affine_inverse() * world_tip
	if not tip.is_finite():
		return
	# (the clip's pose of all three first: laying the forearm moves the hand's)
	var now: Array = bones.map(func(bi: int) -> Transform3D: return skel.get_bone_global_pose(bi))
	var shoulder: Vector3 = now[0].origin
	var upper_len := shoulder.distance_to(now[1].origin)
	var fore_len := maxf((now[1].origin as Vector3).distance_to(now[2].origin), 0.01)
	var own := upper_len + fore_len + grip
	var to := tip - shoulder
	if level:
		to.y = 0.0
	if not out:
		to = to.limit_length(maxf(own, to.length() - RETRACT * dt))
		tip = shoulder + to
	var home := not out and to.length() <= own + 0.001
	if home:
		w = move_toward(w, 0.0, OUT_RATE * dt)
	else:
		w = move_toward(w, 1.0, IN_RATE * dt)
	if w <= 0.0:
		tip = Vector3.INF
		return
	if to.length() < 0.01:
		return
	var dir := to.normalized()
	# the forearm stretches to put the grip on the tip; nearer than the arm's own length it just points there
	var stretch := clampf((to.length() - own) / fore_len + 1.0, 1.0, max_stretch)
	var elbow := shoulder + dir * upper_len
	_lay(bones[0], now[0], shoulder, dir, 1.0)
	_lay(bones[1], now[1], elbow, dir, stretch)
	_lay(bones[2], now[2], elbow + dir * fore_len * stretch, dir, 1.0, aim)


## Bone `bi` (the clip's pose `now`) laid at `at` along `dir` (its +Y), turned the shortest way so it keeps the
## clip's roll, `stretch` along its length (and thicker with it); mixed over the clip's pose by `w`.
func _lay(bi: int, now: Transform3D, at: Vector3, dir: Vector3, stretch: float, own_axis := Vector3.ZERO) -> void:
	var along := now.basis.y.normalized() if own_axis == Vector3.ZERO else (now.basis * own_axis).normalized()
	var turn := Basis(Quaternion(along, dir)) if along.dot(dir) > -0.999 else Basis(now.basis.x.normalized(), PI)
	var girth := lerpf(1.0, GIRTH, clampf((stretch - 1.0) / 2.0, 0.0, 1.0))
	var b := (turn * now.basis).scaled_local(Vector3(girth, stretch, girth))
	skel.set_bone_global_pose(bi, now.interpolate_with(Transform3D(b, at), w))
