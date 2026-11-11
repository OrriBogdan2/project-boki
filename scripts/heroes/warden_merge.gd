class_name WardenMerge
extends RefCounted
## Fewer draw calls per Hunter: after WardenGlb._toon, the surfaces of one mesh whose toon materials came out
## identical (same shader, same parameters, same ink pass) are joined into one surface. The look is unchanged:
## the same material drew each of them. Surfaces a look animates by name stay apart (eyes, glow, card, void, flame).
## Then the ink: the surfaces of a skinned body that wear the same ink shell (one shared outline material) lose it,
## and one copy of the body made of those surfaces draws that shell instead: one draw for the line, not one a surface.

## Slots whose materials something else holds and changes at run time (WardenMood faces and lure, the cards).
const KEEP_APART := ["eyes", "glow", "card", "void", "flame"]
## (mesh id + grouping) -> the joined mesh, so one spawn pays the buffer read and the join, the rest reuse it.
static var _joined := {}

static func merge_equal(glb: Node) -> void:
	for node in glb.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh := mi.mesh as ArrayMesh
		if mesh == null or mesh.get_surface_count() < 2 or mesh.get_blend_shape_count() > 0:
			continue
		var groups := _groups(mi)
		if groups.size() == mesh.get_surface_count():
			continue
		var key := "%d:%s" % [mesh.get_instance_id(), str(groups)]
		if not _joined.has(key):
			_joined[key] = _join(mesh, groups)
		var mats: Array = groups.map(func(g): return mi.get_surface_override_material(g[0]))
		mi.mesh = _joined[key]
		for gi in mats.size():
			mi.set_surface_override_material(gi, mats[gi])

## The ink copies of a Hunter's model (`model` the Hunter's root), whose material ShieldLook swaps for the rim.
static func inks(model: Node) -> Array:
	var glb := model.get_node_or_null("Warden")
	return glb.get_meta("inks", []) if glb else []

static func join_inks(glb: Node) -> void:
	var made: Array = []
	for node in glb.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh := mi.mesh as ArrayMesh
		if mi.skin == null or mesh == null or mesh.get_blend_shape_count() > 0:
			continue
		for g in _ink_groups(mi):
			if g.size() < 2:
				continue
			var ink: Material = mi.get_surface_override_material(g[0]).next_pass
			for si in g:
				mi.get_surface_override_material(si).next_pass = null
			var key := "%d:ink%s" % [mesh.get_instance_id(), str(g)]
			if not _joined.has(key):
				_joined[key] = _join(mesh, [g])
			var shell := MeshInstance3D.new()
			shell.name = String(mi.name) + "_ink"       # (so a far_hide name pattern takes it with its body)
			shell.mesh = _joined[key]
			shell.skin = mi.skin
			shell.material_override = ink
			shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shell.layers = mi.layers
			mi.add_child(shell)
			shell.skeleton = shell.get_path_to(mi.get_node(mi.skeleton))
			made.append(shell)
	glb.set_meta("inks", made)

## Surface indices grouped by the shared ink shell they wear (a glow piece's own halo shell is never shared).
static func _ink_groups(mi: MeshInstance3D) -> Array:
	var out: Array = []
	var shells: Array = []
	for si in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(si)
		var slot := String(src.resource_name).get_slice("-", 0) if src else ""
		var mat := mi.get_surface_override_material(si)
		var ink := mat.next_pass as ShaderMaterial if mat else null
		if ink == null or ink.shader != Models.OUTLINE or slot in KEEP_APART:
			continue
		var home := -1
		for gi in out.size():
			if shells[gi] == ink and _compatible(mi.mesh, out[gi][0], si):
				home = gi
				break
		if home < 0:
			out.append([si])
			shells.append(ink)
		else:
			out[home].append(si)
	return out

## Surface indices grouped by equal material, in first-seen order.
static func _groups(mi: MeshInstance3D) -> Array:
	var out: Array = []
	for si in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(si)
		var slot := String(src.resource_name).get_slice("-", 0) if src else ""
		var mat := mi.get_surface_override_material(si)
		var home := -1
		if not slot in KEEP_APART and not String(src.resource_name).ends_with("-hot"):
			for gi in out.size():
				if _same(mat, mi.get_surface_override_material(out[gi][0])) and _compatible(mi.mesh, out[gi][0], si):
					home = gi
					break
		if home < 0:
			out.append([si])
		else:
			out[home].append(si)
	return out

static func _compatible(mesh: Mesh, a: int, b: int) -> bool:
	return mesh.surface_get_format(a) == mesh.surface_get_format(b) \
			and mesh.surface_get_primitive_type(a) == mesh.surface_get_primitive_type(b) \
			and mesh.surface_get_primitive_type(a) == Mesh.PRIMITIVE_TRIANGLES

## Same shader, every uniform equal, and the same next pass (the ink shell) on both.
static func _same(a: Material, b: Material) -> bool:
	if a == b:
		return true
	var sa := a as ShaderMaterial
	var sb := b as ShaderMaterial
	if sa == null or sb == null or sa.shader != sb.shader or sa.render_priority != sb.render_priority:
		return false
	for u in sa.shader.get_shader_uniform_list():
		if sa.get_shader_parameter(u.name) != sb.get_shader_parameter(u.name):
			return false
	return (sa.next_pass == null) == (sb.next_pass == null) \
			and (sa.next_pass == null or _same(sa.next_pass, sb.next_pass))

static func _join(mesh: ArrayMesh, groups: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for g in groups:
		var arrays: Array = mesh.surface_get_arrays(g[0])
		for k in range(1, g.size()):
			var more: Array = mesh.surface_get_arrays(g[k])
			var base: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			for t in Mesh.ARRAY_MAX:
				if t == Mesh.ARRAY_INDEX:
					var idx: PackedInt32Array = arrays[t]
					idx.append_array(PackedInt32Array(Array(more[t]).map(func(i): return i + base)))
					arrays[t] = idx
				elif arrays[t] != null:
					arrays[t].append_array(more[t])
		var fmt := mesh.surface_get_format(g[0]) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
		var at := out.get_surface_count() - 1
		out.surface_set_name(at, mesh.surface_get_name(g[0]))
		out.surface_set_material(at, mesh.surface_get_material(g[0]))      # (WardenMood reads the slot off it)
	return out
