class_name WardenDropPose
extends RefCounted
## The drop's two shared body poses (docs/decisions/0061-rocket-drop.md), worn by every Hero over
## its clips or its rig: "ride", braced and holding on aboard the squad rocket (DropRocket.seat), and "skydive",
## belly to the ground with the arms and legs spread, banking with the steer, which eases off into the glider-open
## clip when the canopy opens. One pose set for all, content/rules/drop_poses.json: the body line and each limb are
## aimed along a direction in the body's own frame, read off each armature's rest (docs/art/wardens/RIG_CONTRACT.md),
## so the same numbers fit every Hero. Runs after the clips (WardenGlb's Sync), before the hands and blade are read.

const FILE := "res://content/rules/drop_poses.json"
const LIMBS := ["upper_arm", "forearm", "thigh", "shin"]   # parents first
const SIDES := {"L": -1.0, "R": 1.0}                        # which way "out" points along the body's right
const LEAN_RATE := 5.0       # 1/s: the skydive's bank and tip follow the steer
static var _poses := {}

var root: Node3D
var skel: Skeleton3D
var frame := Basis.IDENTITY  # skeleton space, from the rest: x the body's right, y up (hips to head), z back
var aims := {}               # bone name -> [bone index, its limb axis in its own space]
var ride_w := 0.0
var dive_w := 0.0
var steer := Vector2.ZERO    # the skydive's flat velocity over its top speed: x right, y ahead

static func poses() -> Dictionary:
	if _poses.is_empty():
		_poses = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return _poses

## Null when the armature lacks the bones the poses aim.
static func make(model: Node3D, sk: Skeleton3D) -> WardenDropPose:
	var p := WardenDropPose.new()
	p.root = model
	p.skel = sk
	return p if p._setup() else null

func _setup() -> bool:
	var rest := {}
	for b in ["root", "hips", "head", "hand.L", "hand.R"] + _limb_bones():
		var bi := WardenSkeleton.find(skel, b)
		if bi < 0:
			return false
		rest[b] = skel.get_bone_global_rest(bi)
		aims[b] = [bi, Vector3.ZERO]
	var up := ((rest["head"] as Transform3D).origin - (rest["hips"] as Transform3D).origin).normalized()
	var right := (rest["upper_arm.R"] as Transform3D).origin - (rest["upper_arm.L"] as Transform3D).origin
	right = (right - up * right.dot(up)).normalized()
	frame = Basis(right, up, right.cross(up))
	for b in _limb_bones():
		var from := (rest[b] as Transform3D).origin
		var dir: Vector3
		if WardenSkeleton.POINTS_AT.has(b):
			dir = (rest[WardenSkeleton.POINTS_AT[b]] as Transform3D).origin - from
		else:
			dir = from - (rest[WardenSkeleton.CARRY_ON[b]] as Transform3D).origin
		aims[b][1] = ((rest[b] as Transform3D).basis.inverse() * dir).normalized()
	aims["head"][1] = ((rest["head"] as Transform3D).basis.inverse() * up).normalized()
	return true

func _limb_bones() -> Array:
	var out: Array = []
	for side in SIDES:
		for l in LIMBS:
			out.append(l + "." + side)
	return out

## After the clips (or the rig) have posed the bones.
func step(dt: float) -> void:
	var s: Dictionary = root.get_meta(WardenClips.STATE, {})
	var ride: Dictionary = poses()["ride"]
	var dive: Dictionary = poses()["skydive"]
	var diving := bool(s.get("skydive", false))
	ride_w = move_toward(ride_w, 1.0 if bool(s.get("rocket", false)) else 0.0, dt / float(ride["fade"]))
	var dive_fade := float(dive["fade"]) if diving else float(dive["open"])
	dive_w = move_toward(dive_w, 1.0 if diving else 0.0, dt / dive_fade)
	if ride_w > 0.0:
		_apply(ride, ride_w, Quaternion.IDENTITY)
	if dive_w <= 0.0:
		steer = Vector2.ZERO
		return
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var face := float(s.get("face", 0.0))
	var flat := Vector2(vel.x, vel.z) / Hunter.DIVE_SPEED
	# (the model faces -Z at yaw 0: its right and ahead)
	var goal := Vector2(flat.dot(Vector2(cos(face), -sin(face))), flat.dot(Vector2(-sin(face), -cos(face))))
	steer = steer.lerp(goal.limit_length(1.0), 1.0 - exp(-dt * LEAN_RATE))
	var line := _dir(dive["body"])
	var lean := Quaternion(line, deg_to_rad(float(dive["lean"])) * steer.x) \
			* Quaternion(frame.x, -deg_to_rad(float(dive["pitch"])) * steer.y)
	_apply(dive, dive_w, lean)

## Turns the body onto the pose's line (about the hips, `lean` on top), then aims each limb and the head along it.
func _apply(p: Dictionary, w: float, lean: Quaternion) -> void:
	var line := _dir(p["body"])
	var body := lean * Quaternion(frame.y, line)
	var hips := skel.get_bone_global_pose(int(aims["hips"][0])).origin
	var torso := skel.get_bone_global_pose(int(aims["head"][0])).origin - hips
	var turn := Quaternion.IDENTITY.slerp(lean * Quaternion(torso.normalized(), line), w)
	var ri := int(aims["root"][0])
	var g := skel.get_bone_global_pose(ri)
	skel.set_bone_global_pose(ri, Transform3D(Basis(turn) * g.basis, hips + turn * (g.origin - hips)))
	for side in SIDES:
		for l in LIMBS:
			var d: Array = p[l]
			var v := Vector3(float(d[0]) * float(SIDES[side]), float(d[1]), -float(d[2]))
			_aim(l + "." + side, body * (frame * v).normalized(), w)
	_aim("head", body * _dir(p["head"]), w)

## A [up, front] line in the skeleton's space.
func _dir(d: Array) -> Vector3:
	return (frame * Vector3(0.0, float(d[0]), -float(d[1]))).normalized()

## Turns a bone (its children with it) so its limb axis heads `want`, `w` of the way.
func _aim(b: String, want: Vector3, w: float) -> void:
	var bi := int(aims[b][0])
	var g := skel.get_bone_global_pose(bi)
	var now := (g.basis * (aims[b][1] as Vector3)).normalized()
	var q := Quaternion.IDENTITY.slerp(Quaternion(now, want), w)
	skel.set_bone_global_pose(bi, Transform3D(Basis(q) * g.basis, g.origin))
