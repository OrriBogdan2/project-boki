class_name ShroudSkin
extends Skeleton3D
## The bones under the Empty's shroud. The rig is rigid pieces on pivots, so a cloth hung on one pivot can't follow
## two legs: a stride comes straight through it. These bones copy the pivots HunterAnim already moves (legs, knees,
## arms, elbows and the cloth springs), and the cloth is weighted to them by ShroudTailor, so a hem swings with the
## leg under it and a poncho lifts with the arm. Every bone's rest is identity: a bone's pose is simply how far its
## pivot has moved from the pose the cloth was built in. Lives on the torso, so the torso's own motion is free.

enum { TORSO, SKIRT, CAPE, SCARF, LEG_L, LEG_R, KNEE_L, KNEE_R, ARM_L, ARM_R, ELBOW_L, ELBOW_R, COUNT }
const NAMES := ["torso", "skirt", "cape", "scarf", "leg_l", "leg_r", "knee_l", "knee_r", "arm_l", "arm_r",
	"elbow_l", "elbow_r"]

var src: Array[Node3D] = []         # per bone, the pivot it copies (null: the torso, which never moves here)
var rest_inv: Array[Transform3D] = []

func _init() -> void:
	name = "ShroudBones"
	process_priority = 900         # after HunterAnim, whoever drives it
	for nm in NAMES:
		add_bone(nm)

## Which pivot each bone copies (a Dictionary of bone -> Node3D).
func follow(pivots: Dictionary) -> void:
	src.clear()
	src.resize(COUNT)
	for b in pivots:
		src[b] = pivots[b]

## Records the rest pose: each pivot relative to this skeleton, walking the local transforms up to `top` (the
## model is not in a tree yet, and nothing has moved).
func bind(top: Node3D) -> void:
	rest_inv.clear()
	rest_inv.resize(COUNT)
	var me := _chain(self, top)
	for b in COUNT:
		if src[b] != null:
			rest_inv[b] = (me.affine_inverse() * _chain(src[b], top)).affine_inverse()

static func _chain(n: Node3D, top: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != top and n != null:
		xf = n.transform * xf
		n = n.get_parent() as Node3D
	return xf

func _process(_dt: float) -> void:
	sync_pose()

## Copies the pivots onto the bones (each frame, and from tools that step the animation themselves).
func sync_pose() -> void:
	if rest_inv.is_empty() or not is_visible_in_tree():
		return
	var inv := global_transform.affine_inverse()
	for b in COUNT:
		if src[b] != null:
			var xf: Transform3D = inv * src[b].global_transform * rest_inv[b]
			set_bone_pose_position(b, xf.origin)
			set_bone_pose_rotation(b, xf.basis.get_rotation_quaternion())
			set_bone_pose_scale(b, xf.basis.get_scale())
