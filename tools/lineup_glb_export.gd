extends RefCounted
## --lineup-shot --export-glb=<dir>: writes each Hunter of the lineup as one static .glb, posed in the held idle frame,
## at the size a match draws it (Models.hunter's scale x Hunter.VIS_SCALE), facing +Z, with the glb's own textures
## (no team tint, no toon shader), plus <dir>/ours.json: per Hunter the body top (props left out, PROP_WORDS) and
## the top with weapon and props, the head-top anchor (else the body top), in metres above the feet.
## For the admin height lineup page (/admin/lineup3d).


## Exports every Hunter in heroes (ids in the same order) and the table. prop_words: mesh-name words that mark a prop.
static func export_all(heroes: Array, ids: Array, dir: String, prop_words: Array) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var k: float = Hunter.VIS_SCALE
	var rows: Array = []
	for i in heroes.size():
		rows.append(_export_one(heroes[i] as Node3D, String(ids[i]), dir, k, prop_words))
	var f := FileAccess.open(dir.path_join("ours.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"vis_scale": k, "hunters": rows}, "\t"))
	f.close()


static func _export_one(h: Node3D, id: String, dir: String, k: float, prop_words: Array) -> Dictionary:
	var root := Node3D.new()
	root.name = id
	var base := Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO)
	base = base * Transform3D(Basis.IDENTITY, -h.global_position)
	var tops := Vector2(0.0, 0.0)  # (body, all)
	var tris := 0
	for node in h.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		var low := String(h.get_path_to(m)).to_lower()
		if not m.is_visible_in_tree() or m.mesh == null or low.begins_with("teamring") or low.contains("shadow"):
			continue
		if low.contains("ring"):
			continue
		var prop := false
		for w in prop_words:
			prop = prop or low.contains(w)
		if not m.mesh is ArrayMesh:  # (a QuadMesh card or other primitive: a fx sprite, not the model)
			print("LINEUP_GLB_SKIP %s %s %s" % [id, low, m.mesh.get_class()])
			continue
		var src: Mesh = m.bake_mesh_from_current_skeleton_pose() if m.skin != null else m.mesh
		var out := MeshInstance3D.new()
		out.name = ("prop_" if prop else "body_") + String(m.name)
		out.mesh = _plain(src, m)
		out.transform = base * m.global_transform
		root.add_child(out)
		var top := _top(out)
		tops.y = maxf(tops.y, top)
		if not prop:
			tops.x = maxf(tops.x, top)
		for s in out.mesh.get_surface_count():
			tris += int(out.mesh.surface_get_array_index_len(s) / 3.0)
	var doc := GLTFDocument.new()
	doc.image_format = "Lossy WebP"  # (PNG made 10-37 MB files; the page loads all 13 at once)
	doc.lossy_quality = 0.85
	var st := GLTFState.new()
	var path := dir.path_join(id + ".glb")
	var err := doc.append_from_scene(root, st)
	if err == OK:
		err = doc.write_to_filesystem(st, path)
	root.free()
	var anchor := WardenGlb.anchor(h, "anchor_head_top")
	var head: float = (anchor.global_position.y - h.global_position.y) * k if anchor else tops.x
	var src_glb := WardenGlb.path(id) if WardenGlb.uses_model(id) else "(procedural)"
	print(
		(
			"LINEUP_GLB %s src=%s head=%.3f body=%.3f all=%.3f tris=%d err=%d"
			% [id, src_glb, head, tops.x, tops.y, tris, err]
		)
	)
	return {
		"id": id,
		"name": String(Arch.def(id).get("base_name", id)),
		"file": id + ".glb",
		"src": src_glb,
		"head_h": snappedf(head, 0.001),
		"body_h": snappedf(tops.x, 0.001),
		"all_h": snappedf(tops.y, 0.001),
		"tris": tris,
		"model_scale": snappedf(h.scale.y, 0.0001)
	}


## A skin-free copy of src (position, normal, uv, colour, index), each surface on a plain textured material.
static func _plain(src: Mesh, m: MeshInstance3D) -> ArrayMesh:
	var am := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var keep := []
		keep.resize(Mesh.ARRAY_MAX)
		for a in [
			Mesh.ARRAY_VERTEX,
			Mesh.ARRAY_NORMAL,
			Mesh.ARRAY_TANGENT,
			Mesh.ARRAY_COLOR,
			Mesh.ARRAY_TEX_UV,
			Mesh.ARRAY_TEX_UV2,
			Mesh.ARRAY_INDEX
		]:
			keep[a] = arr[a]
		am.add_surface_from_arrays(src.surface_get_primitive_type(s), keep)
		am.surface_set_material(am.get_surface_count() - 1, _material(m, s))
	return am


## The surface's own glb material (the toon override set aside), else a plain one from the override's albedo.
static func _material(m: MeshInstance3D, s: int) -> Material:
	for c in [
		m.mesh.surface_get_material(s) if s < m.mesh.get_surface_count() else null,
		m.get_surface_override_material(s),
		m.material_override
	]:
		if c is BaseMaterial3D:
			var b := (c as BaseMaterial3D).duplicate() as BaseMaterial3D
			b.next_pass = null
			return b
	var out := StandardMaterial3D.new()
	for c in [m.get_surface_override_material(s), m.material_override]:
		if c is ShaderMaterial:
			var tex = (c as ShaderMaterial).get_shader_parameter("albedo_tex")
			var col = (c as ShaderMaterial).get_shader_parameter("albedo")
			if tex is Texture2D and (c as ShaderMaterial).get_shader_parameter("use_tex") == true:
				out.albedo_texture = tex
			if col is Color:
				out.albedo_color = col
			return out
	return out


## The highest vertex of a placed mesh, in its parent's space.
static func _top(mi: MeshInstance3D) -> float:
	var top := -INF
	for s in mi.mesh.get_surface_count():
		for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			top = maxf(top, (mi.transform * v).y)
	return top
