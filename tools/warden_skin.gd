extends RefCounted
## Checks' helper: where a skinned mesh's vertices are in the world in its skeleton's current pose (each through
## its bones, as the GPU skins them). A 3D Warden's mesh AABB is its rest pose's; this is the posed body.

static func points(mi: MeshInstance3D) -> PackedVector3Array:
	var sk := mi.get_node(mi.skeleton) as Skeleton3D
	var to_bone: Array = []
	for bi in mi.skin.get_bind_count():
		var bone := mi.skin.get_bind_bone(bi)
		if bone < 0:
			bone = sk.find_bone(mi.skin.get_bind_name(bi))
		to_bone.append(sk.global_transform * sk.get_bone_global_pose(bone) * mi.skin.get_bind_pose(bi))
	var out := PackedVector3Array()
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for vi in pos.size():
			var p := Vector3.ZERO
			for k in 4:
				p += ((to_bone[bones[vi * 4 + k]] as Transform3D) * pos[vi]) * ws[vi * 4 + k]
			out.append(p)
	return out
