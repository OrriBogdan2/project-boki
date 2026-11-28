class_name PlateGap
extends RefCounted
## The top of a Hunter's visible model as drawn now (skinned vertices through the skeleton's current pose), for
## --warden-native-check: how far a plate at HudPlate.plate_offset clears the head in each state.

var tallest := ""  # the mesh that held the last top()
var _model: Node3D
var _meshes: Array = []  # [MeshInstance3D, [surface vertex arrays], [their bone indices], [their weights]]


## Reads the vertex arrays of every visible mesh under the model's "Warden" node once.
func _init(model: Node3D) -> void:
	_model = model
	for mi in model.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var surfs: Array = []
		for s in m.mesh.get_surface_count():
			surfs.append(m.mesh.surface_get_arrays(s))
		_meshes.append([m, surfs])


## Metres from the model's feet to the highest drawn vertex.
func top() -> float:
	var best := -INF
	for e: Array in _meshes:
		var m: MeshInstance3D = e[0]
		var skel := m.get_node_or_null(m.skeleton) as Skeleton3D if m.skin != null else null
		var xf: Array = []
		if skel:
			for b in m.skin.get_bind_count():
				var bone := m.skin.get_bind_bone(b)
				if bone < 0:
					bone = skel.find_bone(m.skin.get_bind_name(b))
				xf.append(skel.global_transform * skel.get_bone_global_pose(bone) * m.skin.get_bind_pose(b))
		for arr: Array in e[1]:
			var t := _surface_top(m, arr, xf)
			if t > best:
				best = t
				tallest = m.name
	return best - _model.global_position.y


func _surface_top(m: MeshInstance3D, arr: Array, xf: Array) -> float:
	if arr[Mesh.ARRAY_VERTEX] == null:
		return -INF
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights := PackedFloat32Array()
	if arr[Mesh.ARRAY_WEIGHTS] != null:
		weights = arr[Mesh.ARRAY_WEIGHTS]
	var skinned := not xf.is_empty() and weights.size() >= bones.size() and not bones.is_empty()
	var per := int(bones.size() / float(maxi(verts.size(), 1)))
	var hi_y := -INF
	for v in verts.size():
		var y := 0.0
		if skinned:
			for k in per:
				var w := weights[v * per + k]
				if w > 0.0:
					y += ((xf[bones[v * per + k]] as Transform3D) * verts[v]).y * w
		else:
			y = (m.global_transform * verts[v]).y
		hi_y = maxf(hi_y, y)
	return hi_y
