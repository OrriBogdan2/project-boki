class_name WardenSkeleton
extends RefCounted
## The Warden armature of docs/art/wardens/RIG_CONTRACT.md: one bone per rig node HunterAnim poses
## (WardenGlb.BONES), each bone's head on its node's origin and its Y axis along the limb, in the rest pose
## Models.hunter builds (arms hanging, before HunterAnim puts the hands on the weapon). Builds that armature
## for a Warden from its procedural rig, and tells how far a .glb's armature is from it.

## Each bone's parent (root has none). Thighs hang from root: the legs are not under the hips in the rig.
const PARENT := {
	"root": "", "hips": "root", "head": "hips",
	"upper_arm.L": "hips", "forearm.L": "upper_arm.L", "hand.L": "forearm.L",
	"upper_arm.R": "hips", "forearm.R": "upper_arm.R", "hand.R": "forearm.R",
	"thigh.L": "root", "shin.L": "thigh.L", "thigh.R": "root", "shin.R": "thigh.R",
	"pauldron.L": "hips", "pauldron.R": "hips", "skirt": "hips", "cape": "hips", "scarf": "hips",
	"tail": "hips", "wings": "hips",
}
## The joint each limb bone points at (its Y axis); the hand and shin carry on in their parent's line.
const POINTS_AT := {
	"upper_arm.L": "forearm.L", "forearm.L": "hand.L", "upper_arm.R": "forearm.R", "forearm.R": "hand.R",
	"thigh.L": "shin.L", "thigh.R": "shin.R",
}
const CARRY_ON := {"hand.L": "forearm.L", "hand.R": "forearm.R", "shin.L": "thigh.L", "shin.R": "thigh.R"}
const REST_TOL := 0.01         # m a .glb bone's head may sit from its rig node

## Model-space rest transform of every rig node a bone follows (the procedural model as Models.hunter has
## built it, before HunterAnim's rest pose). Read once when the hunter is dressed.
static func rig_rest(root: Node3D) -> Dictionary:
	var out := {}
	for b in WardenGlb.BONES:
		var nd := root.get_node_or_null(String(WardenGlb.BONES[b])) as Node3D
		if nd != null:
			out[b] = WardenGlb.model_xf(root, nd)
	return out

## The contract armature for a rig rest (rig_rest): bones in parent-first order, unit-scale rests.
static func build(rest: Dictionary) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Armature"
	var glob := {}
	for b in WardenGlb.BONES:
		if not rest.has(b):
			continue
		glob[b] = Transform3D(_basis(b, rest), (rest[b] as Transform3D).origin)
		var bi := sk.add_bone(b)
		var par := String(PARENT[b])
		var local: Transform3D = glob[b]
		if par != "":
			sk.set_bone_parent(bi, sk.find_bone(par))
			local = (glob[par] as Transform3D).affine_inverse() * glob[b]
		sk.set_bone_rest(bi, local)
		sk.set_bone_pose(bi, local)
	return sk

## Y along the limb toward the next joint (a hand or shin keeps its parent's line); other bones stand up.
static func _basis(b: String, rest: Dictionary) -> Basis:
	var from := (rest[b] as Transform3D).origin
	var dir := Vector3.UP
	if POINTS_AT.has(b) and rest.has(POINTS_AT[b]):
		dir = (rest[POINTS_AT[b]] as Transform3D).origin - from
	elif CARRY_ON.has(b) and rest.has(CARRY_ON[b]):
		dir = from - (rest[CARRY_ON[b]] as Transform3D).origin
	var y := dir.normalized()
	var x := y.cross(Vector3.BACK)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()

## A contract bone in an imported armature: glTF tools write "upper_arm.L" as "upper_arm_L". -1 if absent.
static func find(sk: Skeleton3D, bone: String) -> int:
	var bi := sk.find_bone(bone)
	return bi if bi >= 0 else sk.find_bone(bone.replace(".", "_"))

## What keeps `sk` from being the contract armature for `rest`: a missing bone, a wrong parent, or a bone
## whose head is off its rig node; and, for a Warden with variant bones (`extra`: bone -> parent, WardenGlb.EXTRA),
## one of those missing or on the wrong parent. Empty when it matches.
static func mismatches(sk: Skeleton3D, rest: Dictionary, extra := {}) -> Array:
	var out: Array = []
	for b in extra:
		var bi := find(sk, b)
		if bi < 0:
			out.append("variant bone %s missing" % b)
		elif sk.get_bone_parent(bi) != find(sk, String(extra[b])):
			out.append("variant bone %s's parent is not %s" % [b, extra[b]])
	for b in WardenGlb.BONES:
		var bi := find(sk, b)
		if bi < 0:
			if not b in WardenGlb.OPTIONAL and rest.has(b):
				out.append("%s missing" % b)
			continue
		var par := String(PARENT[b])
		var pi := sk.get_bone_parent(bi)
		if par != "" and (pi < 0 or pi != find(sk, par)):
			out.append("%s's parent is not %s" % [b, par])
		if rest.has(b):
			var off := sk.get_bone_global_rest(bi).origin.distance_to((rest[b] as Transform3D).origin)
			if off > REST_TOL:
				out.append("%s sits %.3f m off its rig node" % [b, off])
	return out
