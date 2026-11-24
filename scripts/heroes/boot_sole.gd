class_name BootSole
extends RefCounted
## Where the soles of a .glb body are right now: the lowest vertex among those skinned to the foot, toe and shin
## bones, posed by the clips. The bones alone don't say (the ankle sits well above the sole, by a different gap
## for every hero), and the body's origin is not the sole either (the clips crouch and breathe). SkyDeck lifts a
## rider by it so the boots stand on the planks.

const FOOT_SHARE := 0.5  # a boot vertex: this much of its skin weight on the foot, toe and shin bones
const META := "boot_sole"  # model meta: [[mesh instance, its arrays, the boot vertex ids, weights per vertex]]


## The lowest boot vertex of `model` (Models.hunter's root) in world space; INF on a body with no .glb skeleton.
static func low(model: Node3D) -> float:
	var sk := WardenGlb.skeleton(model.get_node_or_null("Warden"))
	if sk == null:
		return INF
	if not model.has_meta(META):
		model.set_meta(META, _boots(sk))
	var lowest := INF
	for e in model.get_meta(META):
		var mi: MeshInstance3D = e[0]
		var pts: PackedVector3Array = e[1][Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = e[1][Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = e[1][Mesh.ARRAY_WEIGHTS]
		var per: int = e[3]
		for i in e[2]:
			var q := Vector3.ZERO
			for j in per:
				var w := wts[i * per + j]
				if w > 0.0:
					var bi := bones[i * per + j]
					q += w * (sk.get_bone_global_pose(_bone(sk, mi.skin, bi)) * mi.skin.get_bind_pose(bi) * pts[i])
			lowest = minf(lowest, (sk.global_transform * q).y)
	return lowest


static func _bone(sk: Skeleton3D, skin: Skin, bind: int) -> int:
	var b := skin.get_bind_bone(bind)
	return b if b >= 0 else sk.find_bone(skin.get_bind_name(bind))


## The skinned meshes of the body and, in each surface, the vertices that are boots.
static func _boots(sk: Skeleton3D) -> Array:
	var out: Array = []
	for node in sk.get_parent().find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin == null or mi.mesh == null:
			continue
		var feet := PackedInt32Array()
		for b in mi.skin.get_bind_count():
			var n := sk.get_bone_name(_bone(sk, mi.skin, b)).to_lower()
			if "foot" in n or "toe" in n or "shin" in n:
				feet.append(b)
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var pts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := int(bones.size() / float(pts.size()))
			var ids := PackedInt32Array()
			for i in pts.size():
				var share := 0.0
				for j in per:
					if feet.has(bones[i * per + j]):
						share += wts[i * per + j]
				if share >= FOOT_SHARE:
					ids.append(i)
			out.append([mi, arr, ids, per])
	return out
