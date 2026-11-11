class_name WardenReach
extends RefCounted
## An arm that reaches out to a point in the world (Grimble's Abyssal Hand, owner playtest 11-11): his own arm, not a
## drawn one. While a kit sets the root meta TIP, the upper arm and forearm lie straight along the line from the
## shoulder to the tip, the forearm stretches so the hand (and everything riding it: his slime hand and bone crescent)
## sits at the tip, and the hand turns down the line. The clips can't move it meanwhile, so it holds still on the aim
## line whatever the body plays (no flailing); it eases in from the clip's wind-up and back to the clips after.
## Data "reach": {"bones": [upper arm, forearm, hand], "grip": m from the hand joint to the middle of what it grips}.

const TIP := "reach_tip"     # root meta: the world point the hand reaches to; unset (or INF) when the arm is home
const IN_RATE := 14.0        # 1/s: the arm takes the aim line (0.07 s out of the wind-up)
const OUT_RATE := 9.0        # 1/s: and gives it back to the clips (0.11 s)
const RETRACT := 70.0        # skeleton units (m at size 1)/s: the hand comes home down the line (full reach 0.13 s)

var skel: Skeleton3D
var bones: Array = []        # [upper arm, forearm, hand] bone indices
var grip := 0.0              # m: wrist to the middle of the hand's grip
var w := 0.0                 # how much the reach owns the arm
var tip := Vector3.INF       # the last tip, in skeleton space (kept while the arm eases home)

## Null when the data has no "reach".
static func make(sk: Skeleton3D, d: Dictionary) -> WardenReach:
	var rd: Dictionary = d.get("reach", {})
	if rd.is_empty():
		return null
	var r := WardenReach.new()
	r.skel = sk
	for b in rd["bones"]:
		r.bones.append(WardenSkeleton.find(sk, String(b)))
	if r.bones.has(-1):
		return null
	r.grip = float(rd["grip"])
	return r

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
	var stretch := maxf(1.0, (to.length() - own) / fore_len + 1.0)
	var elbow := shoulder + dir * upper_len
	_lay(bones[0], now[0], shoulder, dir, 1.0)
	_lay(bones[1], now[1], elbow, dir, stretch)
	_lay(bones[2], now[2], elbow + dir * fore_len * stretch, dir, 1.0)

## Bone `bi` (the clip's pose `now`) laid at `at` along `dir` (its +Y), turned the shortest way so it keeps the
## clip's roll, `stretch` along its length; mixed over the clip's pose by `w`.
func _lay(bi: int, now: Transform3D, at: Vector3, dir: Vector3, stretch: float) -> void:
	var along := now.basis.y.normalized()
	var turn := Basis(Quaternion(along, dir)) if along.dot(dir) > -0.999 else Basis(now.basis.x.normalized(), PI)
	var b := (turn * now.basis).scaled_local(Vector3(1.0, stretch, 1.0))
	skel.set_bone_global_pose(bi, now.interpolate_with(Transform3D(b, at), w))
