class_name PaintMerge
extends RefCounted
## Models.merge_static for static props whose parts differ only in colour: every plain toon part's colour is baked
## into its vertex colours, so parts that share every other toon setting (outline, glow, gloss, brushwork) merge
## into one mesh with one shared material. A prop of a dozen colours draws as two or three meshes instead of a dozen
## (the hub's fixtures: GARDEN_PERF.md "Hub draws"). It looks the same: the toon shader reads the baked colour where
## it read the albedo (`color_srgb`, so it keeps the albedo's 8-bit sRGB precision).
## Parts the shader colours another way (vertex colours, textures, markings) merge as merge_static does.

## Painted materials by their settings, shared by every prop merged this way.
static var _painted := {}


## PaintMerge.node on `root` and on every plain node under it, as Models.merge_tree.
static func tree(root: Node3D) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D and not (n is MeshInstance3D):
			node(n)
		for ch in n.get_children():
			stack.append(ch)


## PaintMerge.node on `n`, which it returns (for a model builder's last line).
static func merged(n: Node3D) -> Node3D:
	node(n)
	return n


## Merges the unnamed, childless, visible mesh parts directly under `n` (as Models.merge_static with keep_casts):
## one mesh per painted look and shadow setting. Named parts stay, for the code that finds and changes them.
static func node(n: Node3D) -> void:
	var groups := {}
	var drop: Array = []
	for ch in n.get_children():
		var mi := ch as MeshInstance3D
		if mi == null or mi.get_child_count() > 0 or not String(mi.name).begins_with("@") or not mi.visible:
			continue
		var mat: Material = mi.material_override
		if mat == null or mi.mesh == null:
			continue
		var casts := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var paint := _paintable(mat)
		var key := (_paint_key(mat) if paint else Models._mat_key(mat)) + "|%s" % casts
		if not groups.has(key):
			groups[key] = {"mat": _painted_mat(mat, key) if paint else mat, "parts": [], "casts": casts}
		var albedo: Color = (mat as ShaderMaterial).get_shader_parameter("albedo") if paint else Color.WHITE
		for arrs in ModelsBake._part_y_surfaces(mi.mesh, mi.transform):
			if paint:
				_fill_color(arrs, albedo)
			(groups[key]["parts"] as Array).append([arrs, mi.transform])
		drop.append(mi)
	for key in groups:
		var g: Dictionary = groups[key]
		var merged := MeshInstance3D.new()
		merged.mesh = MeshArrays.merge(g["parts"])
		merged.material_override = g["mat"]
		if not g["casts"]:
			merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(merged)
	for d in drop:
		n.remove_child(d)
		d.free()


## A plain toon material: one albedo colour, no vertex colours, texture or markings of its own.
static func _paintable(mat: Material) -> bool:
	var sm := mat as ShaderMaterial
	if sm == null or sm.shader != Models.TOON:
		return false
	for flag in ["use_vertex_color", "vertex_ao", "use_tex"]:
		if sm.get_shader_parameter(flag) == true:
			return false
	var mark = sm.get_shader_parameter("mark_kind")
	return mark == null or int(mark) == 0


## Every setting of a toon material but its albedo, and whether it has an outline pass.
static func _paint_key(mat: Material) -> String:
	var sm := mat as ShaderMaterial
	var outline := sm.next_pass.get_instance_id() if sm.next_pass else 0
	var vals := PackedStringArray(["paint", str(outline)])
	for u in sm.shader.get_shader_uniform_list():
		var uname := String(u["name"])
		if uname != "albedo":
			vals.append("%s=%s" % [uname, str(sm.get_shader_parameter(uname))])
	return "|".join(vals)


static func _painted_mat(mat: Material, key: String) -> ShaderMaterial:
	if not _painted.has(key):
		var pm := (mat as ShaderMaterial).duplicate() as ShaderMaterial
		pm.set_shader_parameter("albedo", Color.WHITE)
		pm.set_shader_parameter("use_vertex_color", true)
		pm.set_shader_parameter("color_srgb", true)
		_painted[key] = pm
	return _painted[key]


static func _fill_color(arrs: Array, albedo: Color) -> void:
	var cols := PackedColorArray()
	cols.resize((arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	cols.fill(albedo)
	arrs[Mesh.ARRAY_COLOR] = cols
