extends RefCounted
## --mesh-arrays-check (item 33): MeshArrays.merge builds the same mesh SurfaceTool.append_from did
## (vertices, normals, indices, part heights) without reading parts back from the renderer; a kept
## primitive's arrays follow it when it changes; WardenWarm readies only the Wardens a match can spawn.

var fails := 0

func ok(cond: bool, what: String) -> void:
	print("MESHARRAYS %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main: Node) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	var lathe := Models.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.2, 0.1), Vector2(0, 0.4)]), 12)
	var squashed := Basis.from_euler(Vector3(0.3, 1.1, 0)).scaled(Vector3(1, 2, 0.5))
	var xfs := [Transform3D(squashed, Vector3(1, 2, 3)), Transform3D(Basis.IDENTITY, Vector3(0, -1, 0))]
	var meshes: Array = [sphere, lathe]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = []
	for i in 2:
		st.append_from(meshes[i], 0, xfs[i])
		parts.append([MeshArrays.of(meshes[i], 0), xfs[i]])
	var want := st.commit().surface_get_arrays(0)
	var got: Array = MeshArrays.of(MeshArrays.merge(parts), 0)
	var wv: PackedVector3Array = want[Mesh.ARRAY_VERTEX]
	var gv: PackedVector3Array = got[Mesh.ARRAY_VERTEX]
	var wi: PackedInt32Array = want[Mesh.ARRAY_INDEX]
	var gi: PackedInt32Array = got[Mesh.ARRAY_INDEX]
	ok(wv.size() == gv.size() and wi.size() == gi.size(), "same vertex and index counts as SurfaceTool")
	var gap_v := 0.0
	var gap_n := 0.0
	for k in mini(wv.size(), gv.size()):
		gap_v = maxf(gap_v, wv[k].distance_to(gv[k]))
		gap_n = maxf(gap_n, (want[Mesh.ARRAY_NORMAL][k] as Vector3).distance_to(got[Mesh.ARRAY_NORMAL][k]))
	ok(gap_v < 0.001, "same vertices (worst gap %.5f)" % gap_v)
	ok(gap_n < 0.001, "same normals (worst gap %.5f)" % gap_n)
	var kept_v: PackedVector3Array = MeshArrays.of(lathe, 0)[Mesh.ARRAY_VERTEX]
	ok(kept_v == lathe.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "a built mesh keeps the arrays it was made from")
	sphere.radius = 0.5
	sphere.height = 1.0
	await main.get_tree().process_frame
	var top := 0.0
	for v in (MeshArrays.of(sphere, 0)[Mesh.ARRAY_VERTEX] as PackedVector3Array): top = maxf(top, v.y)
	ok(absf(top - 0.5) < 0.01, "a primitive that changed is read again (top %.2f)" % top)
	var m := Match.new()
	m.opts = {"training": true, "teams": 1, "squad": 1, "arch": "mage"}
	ok(WardenWarm.archs(m) == ["mage"], "alone, only your Warden is readied")
	m.opts = {"teams": 6, "squad": 3}
	ok(WardenWarm.archs(m) == Arch.ids(), "with bots, every Warden is readied")
	m.free()
	print("MESHARRAYS DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)
