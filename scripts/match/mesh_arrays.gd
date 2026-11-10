class_name MeshArrays
extends RefCounted
## Procedural meshes' surface arrays, kept on the CPU. Mesh.surface_get_arrays and
## SurfaceTool.append_from read a mesh back from the renderer, and on a GPU's GL driver every read
## waits for the GPU: merging a hunter's parts read back each part twice, hundreds of stalls a
## hunter (item 33: up to 950 ms a hunter under the loading screen on an RTX 4070).

const KEPT := &"surf_arrays"     # mesh meta: one arrays Array per surface

## A triangle mesh with one surface per arrays Array, which it keeps so nothing reads them back.
static func build(surfaces: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	for arrs in surfaces:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	am.set_meta(KEPT, surfaces)
	return am

## Surface `si` of `mesh` as arrays (a copy the caller may change): the kept copy, else read back
## once and kept (the shared, cached part meshes are read once a game, not once a hunter).
static func of(mesh: Mesh, si: int) -> Array:
	var kept: Array = mesh.get_meta(KEPT, [])
	if kept.size() != mesh.get_surface_count():
		kept = []
		for s in mesh.get_surface_count():
			kept.append(mesh.surface_get_arrays(s))
		mesh.set_meta(KEPT, kept)
		if mesh is PrimitiveMesh:
			# a primitive rebuilds when its size or segments change: the kept copy goes then
			mesh.changed.connect(_forget.bind(weakref(mesh)), CONNECT_ONE_SHOT)
	return (kept[si] as Array).duplicate()

static func _forget(ref: WeakRef) -> void:
	var mesh := ref.get_ref() as Mesh
	if mesh:
		mesh.remove_meta(KEPT)

## One triangle mesh from parts [arrays, transform], like SurfaceTool.append_from without the read-backs.
## Every part needs vertices and normals; missing UVs, colours and tangents are filled in.
static func merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	var tans := PackedFloat32Array()
	var idx := PackedInt32Array()
	var with_tan := parts.any(func(p): return p[0][Mesh.ARRAY_TANGENT] != null)
	for p in parts:
		var a: Array = p[0]
		var xf: Transform3D = p[1]
		var base := verts.size()
		var n := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		verts.append_array(xf * (a[Mesh.ARRAY_VERTEX] as PackedVector3Array))
		for nv in (a[Mesh.ARRAY_NORMAL] as PackedVector3Array):
			norms.append((xf.basis * nv).normalized())      # (as SurfaceTool turns them)
		uvs.append_array(_or_filled(a[Mesh.ARRAY_TEX_UV], n, Vector2.ZERO))
		uv2s.append_array(_or_filled(a[Mesh.ARRAY_TEX_UV2], n, Vector2.ZERO))
		cols.append_array(_or_filled(a[Mesh.ARRAY_COLOR], n, Color.WHITE))
		if with_tan:
			_append_tangents(tans, a[Mesh.ARRAY_TANGENT], n, xf.basis)
		if a[Mesh.ARRAY_INDEX] == null:
			for k in n:
				idx.append(base + k)
		else:
			for i in (a[Mesh.ARRAY_INDEX] as PackedInt32Array):
				idx.append(base + i)
	var arrs := []
	arrs.resize(Mesh.ARRAY_MAX)
	arrs[Mesh.ARRAY_VERTEX] = verts
	arrs[Mesh.ARRAY_NORMAL] = norms
	arrs[Mesh.ARRAY_TEX_UV] = uvs
	arrs[Mesh.ARRAY_TEX_UV2] = uv2s
	arrs[Mesh.ARRAY_COLOR] = cols
	if with_tan:
		arrs[Mesh.ARRAY_TANGENT] = tans
	arrs[Mesh.ARRAY_INDEX] = idx
	return build([arrs])

## `src` when the part has it, else `n` copies of `fill` (PackedVector2Array or PackedColorArray).
static func _or_filled(src: Variant, n: int, fill: Variant) -> Variant:
	if src != null:
		return src
	var out: Variant = PackedColorArray() if fill is Color else PackedVector2Array()
	out.resize(n)
	out.fill(fill)
	return out

## A part's tangents (xyz turned by its basis, w kept), or a default one per vertex when it has none.
static func _append_tangents(tans: PackedFloat32Array, src: Variant, n: int, b: Basis) -> void:
	if src == null:
		for k in n:
			tans.append_array([1.0, 0.0, 0.0, 1.0])
		return
	var t: PackedFloat32Array = src
	for k in n:
		var v := (b * Vector3(t[k * 4], t[k * 4 + 1], t[k * 4 + 2])).normalized()
		tans.append_array([v.x, v.y, v.z, t[k * 4 + 3]])
