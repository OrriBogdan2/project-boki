class_name WardenBulk
extends RefCounted
## A body's "bulk" (archetype body.bulk: Mossy's 0.8, 20% narrower). Scaling the model root (bulk, 1, bulk) sheared
## everything the hands hold: a blade turning in the hand stretched and shrank (--clip-check drift 0.111 m). On a
## Warden drawn from its .glb, the skin is thinned instead: each bone's share of the mesh is scaled on the bone's
## two cross axes (a bone runs along its own +Y), so the body is narrower in every pose, limbs keep their length,
## the joints stay where the clips put them, and the props' bones (HELD) keep their shape. The bones and the
## root are untouched, so the hitbox ring and the weapon's anchors are as without bulk.

const HELD := ["x_weapon", "x_shield"]      # bones that carry what the Warden holds (a skinned hammer, a shield)

## The scale the root takes for this bulk: none on a .glb Warden (its skin is thinned here), the old (bulk, 1,
## bulk) on the procedural fallback, which has no skin to thin.
static func apply(root: Node3D, bulk: float) -> Vector3:
	var glb := root.get_node_or_null("Warden") as Node3D
	if is_equal_approx(bulk, 1.0):
		return Vector3.ONE
	if glb == null:
		return Vector3(bulk, 1.0, bulk)
	for node in glb.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if skel != null and mi.skin != null:
			mi.skin = thinned(mi.skin, skel, bulk)
	return Vector3.ONE

## A copy of `skin` whose bind poses scale each bone's part by (bulk, 1, bulk) in that bone's own frame
## (the skinned vertex is bone_pose * bind * v, so the scale goes in front of the bind).
static func thinned(skin: Skin, skel: Skeleton3D, bulk: float) -> Skin:
	var out := skin.duplicate() as Skin
	var cross := Basis.from_scale(Vector3(bulk, 1.0, bulk))
	for i in out.get_bind_count():
		var bone := String(out.get_bind_name(i))
		if bone == "":
			bone = skel.get_bone_name(out.get_bind_bone(i))
		if bone not in HELD:
			out.set_bind_pose(i, Transform3D(cross, Vector3.ZERO) * out.get_bind_pose(i))
	return out
