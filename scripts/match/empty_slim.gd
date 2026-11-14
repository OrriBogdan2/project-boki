class_name EmptySlim
extends RefCounted
## Brings a built Empty inside the Hunter budget (15k triangles, 8 materials, LODs on). The procedural body is drawn
## for a close camera and comes to about 33k triangles, most of it smooth limbs that lose nothing at a third of
## that; this reduces each part's triangle list in place, with a further LOD for distance. The head under the void
## shell never shows, so it goes. Runs once a model is built (Shrouds.bind), before its materials are collected.

const BODY_KEEP := 0.23             # of each body part's triangles
const SHELL_KEEP := 0.5             # of the void shell's: it is the silhouette of the head
const LOD_KEEP := 0.45              # of those again, at a distance
const MIN_TRIS := 40                # a part this small is left alone
const MAX_ERROR := 0.05             # how far the reduction may move a surface (of the part's size)
## Parts that keep their triangles: the cloth is reduced when it is baked, and these are not the body.
const SKIP := ["ShroudBones", "Glider", "Gun", "TeamRing"]

static func apply(model: Node3D) -> void:
	var head := model.find_child("Head", true, false) as MeshInstance3D
	if head:
		head.mesh = ArrayMesh.new()
	var swap: Dictionary = model.get_meta("shroud_swap", {})
	model.remove_meta("shroud_swap")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if g.mesh == null or g.mesh.get_surface_count() == 0 or _skipped(g, model):
			continue
		g.material_override = swap.get(g.material_override, g.material_override)
		g.mesh = slim(g.mesh, SHELL_KEEP if g.name == "Hollow" else BODY_KEEP)

static func _skipped(n: Node, top: Node) -> bool:
	while n != top:
		if String(n.name) in SKIP:
			return true
		n = n.get_parent()
	return false

## A copy of a mesh with `keep` of its triangles, and a lower LOD. Vertices stay as they are, so normals, vertex
## colours and any bones are kept; only the triangle lists change. An engine build without the simplifier gets the
## mesh back untouched.
static func slim(mesh: Mesh, keep: float) -> Mesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.create_from(mesh, s)
		st.index()
		var arrs := st.commit_to_arrays()
		var src: PackedInt32Array = arrs[Mesh.ARRAY_INDEX]
		var tris := src.size() / 3
		if tris < MIN_TRIS:
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
			continue
		var idx := reduce(arrs, keep)
		if idx.is_empty():
			return mesh
		arrs[Mesh.ARRAY_INDEX] = idx
		var far := reduce(arrs, LOD_KEEP)
		var lods := {} if far.is_empty() else {0.05: far}
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs, [], lods)
	return out

## `keep` of a surface's triangle list.
static func reduce(arrs: Array, keep: float) -> PackedInt32Array:
	var plain := []
	plain.resize(Mesh.ARRAY_MAX)
	plain[Mesh.ARRAY_VERTEX] = arrs[Mesh.ARRAY_VERTEX]
	plain[Mesh.ARRAY_NORMAL] = arrs[Mesh.ARRAY_NORMAL]
	plain[Mesh.ARRAY_INDEX] = arrs[Mesh.ARRAY_INDEX]
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plain)
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	var want := int((arrs[Mesh.ARRAY_INDEX] as PackedInt32Array).size() * keep) / 3 * 3
	return st.generate_lod(MAX_ERROR, want)
