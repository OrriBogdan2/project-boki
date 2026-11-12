class_name ModelsBake
## Gliders, mesh merging and the painted-part bake. Moved out of Models; callers still use the Models facade.


## A paraglider wing: arched across its span, rounded at the tips, striped in the given colours.
static func glider_mesh(cloth: Color, stripe: Color, edge: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 12
	var span := 1.05
	for side in [1.0, -1.0]:
		for k in segs:
			var x0 := -span + 2.0 * span * k / segs
			var x1 := -span + 2.0 * span * (k + 1) / segs
			var col: Color = stripe if k % 3 == 1 else (edge if k == 0 or k == segs - 1 else cloth)
			var pts := []
			for x in [x0, x1]:
				var u: float = absf(x) / span
				var y: float = -0.32 * u * u
				var chord: float = 0.42 * sqrt(maxf(0.0, 1.0 - pow(u, 3.0))) + 0.05
				pts.append(Vector3(x, y + side * 0.012, -chord * 0.55))
				pts.append(Vector3(x, y + side * 0.012, chord * 0.45))
			var n: Vector3 = Vector3.UP * side
			st.set_color(col)
			var order := [0, 2, 3, 0, 3, 1] if side > 0.0 else [0, 3, 2, 0, 1, 3]
			for i in order:
				st.set_normal(n)
				st.add_vertex(pts[i])
	return st.commit()

static func vtoon_outlined() -> ShaderMaterial:
	var m := ModelsBase.vtoon()
	m.set_shader_parameter("rim_amount", 0.5)
	if ModelsBase._outline_mat == null:
		ModelsBase._outline_mat = ShaderMaterial.new()
		ModelsBase._outline_mat.shader = ModelsBase.OUTLINE
	m.next_pass = ModelsBase._outline_mat
	return m

## A glider per canopy shape, merged once (merge_static) for every Hunter on a skin of that shape: [the canopy,
## its vertex colours still the colour weights (Gliders.canopy_material colours each Hunter's), the strings].
static var _glider_sets := {}
static func _glider_set(gskin: String) -> Array:
	var sheet := Gliders.canopy(gskin)
	if not _glider_sets.has(sheet):
		var g := Node3D.new()
		var canopy := MeshInstance3D.new()
		canopy.mesh = sheet
		canopy.material_override = vtoon_outlined()
		canopy.position = Vector3(0, 1.05, 0.02)
		g.add_child(canopy)
		var m_line := ModelsBase.toon(Color("5a4636"), false)
		for sx in [-1.0, -0.4, 0.4, 1.0]:
			var at := Vector3(0.42 * sx, 0.55, 0)
			ModelsBase.part(g, ModelsBase.cyl(0.008, 0.008, 1.0, 4), m_line, at, Vector3.ONE,
					Vector3(0, 0, -0.62 * sx))
		merge_static(g)
		var got := {}
		for ch in g.get_children():
			got[(ch as MeshInstance3D).material_override == m_line] = (ch as MeshInstance3D).mesh
		_glider_sets[sheet] = [got[false], got[true]]
		g.free()
	return _glider_sets[sheet]

## Bakes a node's plain mesh parts into one mesh per look, so a detailed character costs a handful
## of draw calls. Named parts (Head, ArmR, Halo, ...) and anything with children stay separate.
## `discard`: those parts are only freed (a body nothing will draw).
static func merge_static(node: Node3D, discard := false) -> void:
	var groups := {}
	var drop: Array = []
	for ch in node.get_children():
		if not (ch is MeshInstance3D) or ch.get_child_count() > 0 or not String(ch.name).begins_with("@"):
			continue
		if not ch.visible:
			continue
		var mi: MeshInstance3D = ch
		var mat: Material = mi.material_override
		if mat == null or mi.mesh == null:
			continue
		if discard:
			drop.append(mi)
			continue
		var key := _mat_key(mat)
		if not groups.has(key):
			groups[key] = {"mat": mat, "parts": []}
		for arrs in _part_y_surfaces(mi.mesh, mi.transform):
			(groups[key]["parts"] as Array).append([arrs, mi.transform])
		drop.append(mi)
	for key in groups:
		var g: Dictionary = groups[key]
		var mi := MeshInstance3D.new()
		mi.mesh = MeshArrays.merge(g["parts"])     # (no SurfaceTool: it reads every part back from the GPU)
		mi.material_override = g["mat"]
		ShadowPolicy.judge(mi)       # a merged clump of small parts is still small (item 94)
		node.add_child(mi)
	for d in drop:
		node.remove_child(d)
		d.free()

## A copy of a mesh whose UV2 holds the height range (bottom, top) the part spans once placed with
## xf, which the toon shader turns into the part's painted light-to-dark gradient and crease.
static func _with_part_y(mesh: Mesh, xf := Transform3D.IDENTITY) -> ArrayMesh:
	return MeshArrays.build(_part_y_surfaces(mesh, xf))

## A mesh's surfaces as arrays with that height range in UV2 (and plain white colours when it has none).
static func _part_y_surfaces(mesh: Mesh, xf: Transform3D) -> Array:
	var ab := xf * mesh.get_aabb()
	var out: Array = []
	for si in mesh.get_surface_count():
		var arrs: Array = MeshArrays.of(mesh, si)
		var n: int = (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var uv2 := PackedVector2Array(); uv2.resize(n); uv2.fill(Vector2(ab.position.y, ab.end.y))
		arrs[Mesh.ARRAY_TEX_UV2] = uv2
		if arrs[Mesh.ARRAY_COLOR] == null:
			var cw := PackedColorArray(); cw.resize(n); cw.fill(Color.WHITE)     # no baked occlusion: plain white
			arrs[Mesh.ARRAY_COLOR] = cw
		out.append(arrs)
	return out

static var _part_y_cache := {}
## Gives every toon-shaded part under `n` that isn't merged its own part range (in its own space).
static func bake_part_y(n: Node) -> void:
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.mesh and mi.mesh.get_surface_count() > 0 and mi.material_override is ShaderMaterial \
					and (mi.material_override as ShaderMaterial).shader == ModelsBase.TOON \
					and not (mi.mesh is ArrayMesh and ((mi.mesh as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2)):
				var id := mi.mesh.get_instance_id()
				if not _part_y_cache.has(id):
					_part_y_cache[id] = _with_part_y(mi.mesh)
				mi.mesh = _part_y_cache[id]
		for ch in c.get_children(): stack.append(ch)

## Sets a toon material's painted structure: its brushwork (see toon.gdshader's `surface`), the
## part gradient, the crease darkening and the form-shadow on edges.
static func painted(m: ShaderMaterial, surface := 0, grad := 0.22, crease_k := 0.26, edge := 0.24) -> ShaderMaterial:
	m.set_shader_parameter("surface", surface)
	m.set_shader_parameter("part_grad", grad)
	m.set_shader_parameter("crease", crease_k)
	m.set_shader_parameter("edge_dark", edge)
	return m

static func _mat_key(m: Material) -> String:
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		return "%s|%s|%s|%s|%s|%s" % [sm.shader.resource_path, str(sm.get_shader_parameter("albedo")), str(sm.get_shader_parameter("glow")), str(sm.get_shader_parameter("rim_amount")), str(sm.next_pass != null), str(sm.get_shader_parameter("use_vertex_color"))]
	return str(m.get_instance_id())

## Every toon material in a model, for the hit flash.
static func collect_mats(n: Node) -> Array:
	var out: Array = []
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D and (c as MeshInstance3D).material_override is ShaderMaterial:
			var sm := (c as MeshInstance3D).material_override as ShaderMaterial
			if sm.shader == ModelsBase.TOON and not out.has(sm):
				out.append(sm)
		for ch in c.get_children(): stack.append(ch)
	return out

static func m_trim0(c: Color) -> ShaderMaterial:
	return ModelsBase.toon(c.darkened(0.55).lerp(Color("3a2f2a"), 0.5))
