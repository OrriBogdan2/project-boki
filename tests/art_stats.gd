extends RefCounted

## Tooling (--art-stats): vertices, triangles and draw calls per hunter (each race) and per kin, and
## how long a build takes, cold (meshes made for the first time) and warm (from the caches).
static func stats() -> void:
	if "--art-stats-detail" in OS.get_cmdline_user_args():
		# draw calls per node of one hunter of each class (where the surfaces come from)
		for arch in HeroKit.ARCH_ORDER:
			var cls := String(HeroKit.ARCHES[arch]["cls"])
			var hd := Models.hunter(cls, Data.TEAM_COLORS[0], "rifle", "", {"race": 0, "hair": 1}, arch)
			var per := {}
			var st: Array = [hd]
			while not st.is_empty():
				var c: Node = st.pop_back()
				if c is MeshInstance3D and (c as MeshInstance3D).mesh and (c as MeshInstance3D).visible:
					var k := String(hd.get_path_to(c.get_parent()))
					per[k] = int(per.get(k, 0)) + (c as MeshInstance3D).mesh.get_surface_count()
					var tk := "tris " + k
					per[tk] = int(per.get(tk, 0)) + int(_count(c)[1])
				for ch in c.get_children(): st.append(ch)
			print("ART detail %s %s tris %d draws %d" % [arch, str(per), _count(hd)[1], _count(hd)[2]])
			hd.free()
	for r in Models.RACES.size():
		var t0 := Time.get_ticks_usec()
		var h := Models.hunter("medium", Data.TEAM_COLORS[0], "rifle", "", {"race": r, "hair": 1})
		var cold := Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		var h2 := Models.hunter("medium", Data.TEAM_COLORS[1], "rifle", "", {"race": r, "hair": 1})
		var warm := Time.get_ticks_usec() - t0
		var c := _count(h)
		print("ART hunter %-10s verts %6d  tris %6d  draws %3d  build cold %5.1f ms warm %5.1f ms" % [Models.LOOK_RACES[r], c[0], c[1], c[2], cold / 1000.0, warm / 1000.0])
		h.free(); h2.free()
	for sp in Data.KIN.keys():
		var t0 := Time.get_ticks_usec()
		var k := Models.kin(String(sp), {"level": 6})
		var cold := Time.get_ticks_usec() - t0
		var c := _count(k)
		print("ART kin %-10s verts %6d  tris %6d  draws %3d  build %5.1f ms" % [sp, c[0], c[1], c[2], cold / 1000.0])
		k.free()

static func _count(n: Node) -> Array:
	var v := 0; var t := 0; var d := 0
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh and (c as MeshInstance3D).visible:
			var m := (c as MeshInstance3D).mesh
			for si in m.get_surface_count():
				var a := m.surface_get_arrays(si)
				var nv: int = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				v += nv
				t += ((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if a[Mesh.ARRAY_INDEX] != null else nv) / 3
				d += 1
		for ch in c.get_children(): stack.append(ch)
	return [v, t, d]
