class_name WardenAimLead
extends RefCounted
## The aim lead on a Hero's clips: the head turns to the cursor first, the chest a little behind it, the legs last
## (parity: the source's heroes read the aim before the shot). The model as a whole already faces the cursor
## (Hunter.face), so each part is a damped follower of it: the leg line (bone root) lags the most, the chest (bone
## hips) leads it by at most CHEST_MAX, the head by at most HEAD_MAX. Off under full-body clips, mantles and
## downed (weight 0), so a move's own pose is never turned.

const HIPS_RATE := 6.0        # 1/s: the legs catch up with the cursor while standing
const HIPS_RATE_MOVING := 7.0  # 1/s: and while walking, so the stride keeps pointing where he goes
const CHEST_RATE := 12.0      # 1/s: the chest follows the cursor
const HEAD_RATE := 22.0       # 1/s: the head follows it first
const RESET_RATE := 30.0      # 1/s: every part comes back square while the layer is off
const CHEST_MAX := 0.5236     # rad (30 deg): the most the chest leads the legs
const HEAD_MAX := 1.0472      # rad (60 deg): the most the head leads the legs
const ON_RATE := 8.0          # 1/s: the layer's weight easing in
const MOVING := 0.25          # m/s: faster than this he is walking

var weight := 0.0             # 0..1: how much of the lead shows
var legs := 0.0               # rad: how far each part sits behind the cursor (the model's facing), + counter-clockwise
var chest := 0.0
var head := 0.0
var face_prev := NAN

## 1 when the layer may show: not under a full-body clip (act_w; an upper-body move passes 0), not on the rig's own
## pose (mantle, ledge: proc_w), not dead or downed, not gliding or diving (the air tilt owns the root bone there:
## HunterAnim AIR_TILT, WardenClips._air_tilt; a yaw lag laid on top turns the body off the rig, --glide-bank-check).
static func allowed(s: Dictionary, act_w: float, proc_w: float) -> float:
	if bool(s.get("dead", false)) or bool(s.get("downed", false)):
		return 0.0
	if bool(s.get("gliding", false)) or bool(s.get("diving", false)):
		return 0.0
	return (1.0 - act_w) * (1.0 - proc_w)

## One frame: follow the facing in state s, then lay the turns on the skeleton's yaw about each bone's own origin.
func apply(skel: Skeleton3D, s: Dictionary, act_w: float, proc_w: float, dt: float) -> void:
	var face := float(s.get("face", 0.0))
	var dface := 0.0 if is_nan(face_prev) else wrapf(face - face_prev, -PI, PI)
	face_prev = face
	var goal := allowed(s, act_w, proc_w)
	# (eases in; goes out as fast as the clip comes in)
	weight = minf(move_toward(weight, goal, dt * ON_RATE), goal)
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var hips_rate := HIPS_RATE_MOVING if Vector2(vel.x, vel.z).length() > MOVING else HIPS_RATE
	var reset := goal <= 0.0
	legs = _follow(legs, dface, RESET_RATE if reset else hips_rate, dt)
	chest = _follow(chest, dface, RESET_RATE if reset else CHEST_RATE, dt)
	head = _follow(head, dface, RESET_RATE if reset else HEAD_RATE, dt)
	legs = clampf(legs, chest - CHEST_MAX, chest + CHEST_MAX)       # the legs are dragged along past the limits
	legs = clampf(legs, head - HEAD_MAX, head + HEAD_MAX)
	if weight <= 0.0:
		return
	_turn(skel, "root", legs * weight)
	_turn(skel, "hips", (chest - legs) * weight)
	_turn(skel, "head", (head - chest) * weight)

## The cursor moved on by dface: a part's lag grows by it, then eases back to zero.
static func _follow(lag: float, dface: float, rate: float, dt: float) -> float:
	return wrapf(lag - dface, -PI, PI) * exp(-rate * dt)

static func _turn(skel: Skeleton3D, bone: String, yaw: float) -> void:
	var bi := WardenSkeleton.find(skel, bone)
	if bi < 0 or absf(yaw) < 0.0001:
		return
	var pose := skel.get_bone_global_pose(bi)
	pose.basis = Basis(Vector3.UP, yaw) * pose.basis
	skel.set_bone_global_pose(bi, pose)
