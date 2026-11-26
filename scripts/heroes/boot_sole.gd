class_name BootSole
extends RefCounted
## Where the soles of a .glb body are right now: the lowest vertex among those skinned to the foot, toe and shin
## bones, posed by the clips. The bones alone don't say (the ankle sits well above the sole, by a different gap
## for every hero), and the body's origin is not the sole either (the clips crouch and breathe). SkyDeck lifts a
## rider by it so the boots stand on the planks.

const FOOT_SHARE := 0.5  # a boot vertex: this much of its skin weight on the foot, toe and shin bones
## Reads so far (tooling: --loadin-fps-check counts them, a rider's read is a CPU skin of its boot vertices).
static var reads := 0

const META := "boot_sole"  # model meta: [[mesh, arrays, boot ids, weights, used bind ids]]


## The lowest boot vertex of `model` (Models.hunter's root) in world space; INF on a body with no .glb skeleton.
## The skin is read for the world y only: each bone's pose, bind and the skeleton's transform fold into one
## row (y = v . vertex + c) once per call, so a vertex costs a few dot products, not a matrix chain a weight.
static func low(model: Node3D) -> float:
	reads += 1
	var sk := WardenGlb.skeleton(model.get_node_or_null("Warden"))
	if sk == null:
		return INF
	if not model.has_meta(META):
		model.set_meta(META, _boots(sk))
	var g := sk.global_transform
	var gy := Vector3(g.basis.x.y, g.basis.y.y, g.basis.z.y)  # the skeleton's world y row
	var lowest := INF
	for e in model.get_meta(META):
		var mi: MeshInstance3D = e[0]
		var pts: PackedVector3Array = e[1][Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = e[1][Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = e[1][Mesh.ARRAY_WEIGHTS]
		var per: int = e[3]
		var rows := {}  # bind index -> [y row of the bone's skinning transform, its y offset]
		for bi in e[4]:
			var t: Transform3D = sk.get_bone_global_pose(_bone(sk, mi.skin, bi)) * mi.skin.get_bind_pose(bi)
			rows[bi] = [Vector3(gy.dot(t.basis.x), gy.dot(t.basis.y), gy.dot(t.basis.z)), gy.dot(t.origin)]
		var row_v := PackedVector3Array()
		var row_c := PackedFloat32Array()
		row_v.resize(mi.skin.get_bind_count())
		row_c.resize(mi.skin.get_bind_count())
		for bi in rows:
			row_v[bi] = rows[bi][0]
			row_c[bi] = rows[bi][1]
		for i in e[2]:
			var y := g.origin.y
			var base: int = i * per
			var p := pts[i]
			for j in per:
				var w := wts[base + j]
				if w > 0.0:
					var bi := bones[base + j]
					y += w * (row_v[bi].dot(p) + row_c[bi])
			lowest = minf(lowest, y)
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
			var used := {}
			for i in ids:
				for j in per:
					if wts[i * per + j] > 0.0:
						used[bones[i * per + j]] = true
			out.append([mi, arr, ids, per, used.keys()])
	return out
