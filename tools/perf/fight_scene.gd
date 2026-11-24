extends RefCounted
## The fight scene's draw inventory for --bench-fight (tools/perf_fight.gd): what the renderer is handed in a frame,
## to read against the engine's draw wait. Taken twice in the camp fight, at an FX peak and in a quiet spell, as
## "BENCH fight scene <tag> ..." lines over what the camera can see:
##   kinds: the visible GeometryInstance3D by class, the MultiMesh copies and the particle amounts;
##   materials: distinct materials and shaders on the visible surfaces (each distinct shader is a pipeline switch);
##   transparent: the see-through surfaces and the screen area their boxes cover, in screens (an overdraw ceiling;
##   an emitter, label or sprite counts once), with the owners covering most;
##   repeats: mesh+material pairs drawn as several MeshInstance3D copies (MultiMesh candidates: the renderer already
##   instances same-mesh copies, so a MultiMesh saves their per-object cull and transform work, not draw calls);
##   lods: the visible meshes with mesh LODs (the renderer draws a coarser index set when a mesh is small on
##   screen, in the shadow passes too) against those without, by triangles, and the biggest without;
##   hunter <arch>: a Hunter's model: mesh instances, surfaces, outline passes, distinct materials, shadow casters,
##   triangles, surfaces with LODs and bones (at the peak only).

const TOP := 12  # entries per line
const REPEAT_MIN := 3  # copies before a mesh+material pair counts as a MultiMesh candidate
const BLEND_MODES := ["blend_add", "blend_sub", "blend_mul", "blend_premul_alpha"]  # transparent-pass render_modes

var cam: Camera3D
var view: Vector2
var alpha_re := RegEx.create_from_string("\\bALPHA\\s*[-+*/]?=")  # a fragment writing ALPHA draws see-through


func report(root: Node, m: Match, viewport: Viewport, tag: String) -> void:
	cam = viewport.get_camera_3d()
	view = Vector2(viewport.get_visible_rect().size)
	if cam == null:
		return
	var seen: Array = []  # the visible GeometryInstance3D in the camera's view
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.is_visible_in_tree() and _in_view(gi):
			seen.append(gi)
	var head := "BENCH fight scene %s" % tag
	print("%s kinds: %s" % [head, _kinds(seen)])
	print("%s materials: %s" % [head, _materials(seen)])
	print("%s transparent: %s" % [head, _transparent(seen)])
	print("%s repeats (MultiMesh candidates, copies x tris): %s" % [head, _repeats(seen)])
	print("%s lods: %s" % [head, _lods(seen)])
	if tag == "peak":
		for h: Hunter in m.hunters:
			print("%s hunter %s %s: %s" % [head, h.pname, h.arch, _hunter(h)])


## Who made a node: the nearest ancestor with a name of its own (pooled and made nodes are mostly unnamed).
static func owner_name(n: Node) -> String:
	var up := n.get_parent()
	while up != null and String(up.name).begins_with("@"):
		up = up.get_parent()
	return String(up.name).rstrip("0123456789@") if up != null else ""


func _kinds(seen: Array) -> String:
	var by := {}
	var copies := 0
	var amount := 0
	var emitting := 0
	for gi in seen:
		var cls: String = gi.get_class()
		by[cls] = int(by.get(cls, 0)) + 1
		if gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
			var mm: MultiMesh = (gi as MultiMeshInstance3D).multimesh
			copies += mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
		elif gi is GPUParticles3D:
			amount += (gi as GPUParticles3D).amount
			emitting += 1 if (gi as GPUParticles3D).emitting else 0
		elif gi is CPUParticles3D:
			amount += (gi as CPUParticles3D).amount
			emitting += 1 if (gi as CPUParticles3D).emitting else 0
	var ks := by.keys()
	ks.sort_custom(func(a, b): return by[a] > by[b])
	var parts := ks.map(func(k): return "%s %d" % [k, by[k]])
	return "%s; multimesh copies %d; emitters emitting %d, amount %d" % [", ".join(parts), copies, emitting, amount]


func _materials(seen: Array) -> String:
	var mats := {}  # material instance id -> true
	var objs := {}  # shader instance id -> true
	var shaders := {}  # shader key -> surfaces using it
	var surfaces := 0
	var passes := 0
	var none := 0
	for gi in seen:
		for first in _surface_materials(gi):
			surfaces += 1
			if first == null:
				none += 1
				continue
			var mat: Material = first
			while mat != null:
				passes += 1
				mats[mat.get_instance_id()] = true
				if mat is ShaderMaterial and (mat as ShaderMaterial).shader:
					objs[(mat as ShaderMaterial).shader.get_instance_id()] = true
				var k := _shader_key(mat)
				shaders[k] = int(shaders.get(k, 0)) + 1
				mat = mat.next_pass
	var ks := shaders.keys()
	ks.sort_custom(func(a, b): return shaders[a] > shaders[b])
	var top := ks.slice(0, TOP).map(func(k): return "%s %d" % [k, shaders[k]])
	return (
		"surfaces %d (no material %d), passes %d, distinct materials %d, shader objects %d, distinct shaders %d: %s"
		% [surfaces, none, passes, mats.size(), objs.size(), shaders.size(), ", ".join(top)]
	)


func _transparent(seen: Array) -> String:
	var surfaces := 0
	var things := 0
	var screens := 0.0
	var by := {}  # owner -> screens
	for gi in seen:
		var n := 0
		if gi is GPUParticles3D or gi is CPUParticles3D or gi is Label3D or gi is Sprite3D:
			n = 1
		else:
			for mat in _surface_materials(gi):
				n += 1 if _see_through(mat) else 0
		if n == 0:
			continue
		surfaces += n
		things += 1
		var area := _screen_area(gi) / (view.x * view.y) * n
		screens += area
		var k := "%s<%s" % [gi.get_class(), owner_name(gi)]
		by[k] = float(by.get(k, 0.0)) + area
	var ks := by.keys()
	ks.sort_custom(func(a, b): return by[a] > by[b])
	var top := ks.slice(0, TOP).map(func(k): return "%s %.2f" % [k, by[k]])
	return (
		"%d things, %d see-through surfaces, boxes cover %.1f screens: %s"
		% [things, surfaces, screens, ", ".join(top)]
	)


func _repeats(seen: Array) -> String:
	var by := {}  # mesh+materials key -> [copies, tris, name]
	for gi in seen:
		if not gi is MeshInstance3D or (gi as MeshInstance3D).mesh == null:
			continue
		var mi := gi as MeshInstance3D
		var ids := _surface_materials(mi).map(func(mat): return str(mat.get_instance_id()) if mat else "-")
		var key := "%d|%s" % [mi.mesh.get_instance_id(), "|".join(ids)]
		var g: Array = by.get(key, [0, _tris(mi.mesh), _mesh_name(mi)])
		g[0] += 1
		by[key] = g
	var ks := by.keys().filter(func(k): return by[k][0] >= REPEAT_MIN)
	ks.sort_custom(func(a, b): return by[a][0] > by[b][0])
	var total := 0
	for k in ks:
		total += by[k][0]
	var top := ks.slice(0, TOP).map(func(k): return "%s x%d (%.1fk)" % [by[k][2], by[k][0], by[k][0] * by[k][1] / 1000.0])
	return "%d groups, %d copies: %s" % [ks.size(), total, ", ".join(top)]


func _lods(seen: Array) -> String:
	var with_n := 0
	var with_tris := 0
	var without: Array = []  # [tris, name] of the meshes with no LODs
	for gi in seen:
		var mesh := _mesh_of(gi)
		if mesh == null or gi is GPUParticles3D or gi is CPUParticles3D:
			continue
		var tris := _tris(mesh)
		if _lod_surfaces(mesh) > 0:
			with_n += 1
			with_tris += tris
		else:
			var nm := _mesh_name(gi as MeshInstance3D) if gi is MeshInstance3D else "%s<%s" % [gi.get_class(), owner_name(gi)]
			without.append([tris, nm])
	without.sort_custom(func(a, b): return a[0] > b[0])
	var all_without := 0
	for w in without:
		all_without += w[0]
	var top := without.slice(0, TOP).map(func(w): return "%s %.1fk" % [w[1], w[0] / 1000.0])
	return (
		"with %d meshes %.0fk tris, without %d meshes %.0fk tris: %s"
		% [with_n, with_tris / 1000.0, without.size(), all_without / 1000.0, ", ".join(top)]
	)


## How many of a mesh's surfaces carry LOD index sets.
static func _lod_surfaces(mesh: Mesh) -> int:
	var n := 0
	for si in mesh.get_surface_count():
		var sd := RenderingServer.mesh_get_surface(mesh.get_rid(), si)
		n += 1 if (sd.get("lods", []) as Array).size() > 0 else 0
	return n


func _hunter(h: Hunter) -> String:
	if h.model == null:
		return "no model"
	var meshes := 0
	var surfaces := 0
	var next_passes := 0
	var casters := 0
	var tris := 0
	var lod_surfaces := 0
	var mats := {}
	for n in h.model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		meshes += 1
		tris += _tris(mi.mesh)
		lod_surfaces += _lod_surfaces(mi.mesh)
		casters += 1 if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0
		for first in _surface_materials(mi):
			surfaces += 1
			var mat: Material = first
			while mat != null:
				mats[mat.get_instance_id()] = true
				mat = mat.next_pass
				next_passes += 1 if mat != null else 0
	var bones := 0
	var skels := h.model.find_children("*", "Skeleton3D", true, false)
	for s in skels:
		bones += (s as Skeleton3D).get_bone_count()
	var line := (
		"meshes %d, surfaces %d (+%d next passes), materials %d, casters %d, %.1fk tris, lods on %d surfaces, "
		+ "skeletons %d (%d bones), %.0f m"
	)
	return (
		line
		% [
			meshes,
			surfaces,
			next_passes,
			mats.size(),
			casters,
			tris / 1000.0,
			lod_surfaces,
			skels.size(),
			bones,
			cam.global_position.distance_to(h.model.global_position)
		]
	)


## The first-pass materials of a visible thing's surfaces (null where a surface has none), whatever draws it.
func _surface_materials(gi: GeometryInstance3D) -> Array:
	var out: Array = []
	var mesh := _mesh_of(gi)
	if mesh == null:
		return out
	for si in mesh.get_surface_count():
		var mat: Material = gi.material_override
		if gi is MeshInstance3D:
			mat = (gi as MeshInstance3D).get_active_material(si)
		elif mat == null:
			mat = mesh.surface_get_material(si)
		out.append(mat)
	return out


static func _mesh_of(gi: GeometryInstance3D) -> Mesh:
	if gi is MeshInstance3D:
		return (gi as MeshInstance3D).mesh
	if gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
		return (gi as MultiMeshInstance3D).multimesh.mesh
	if gi is CPUParticles3D:
		return (gi as CPUParticles3D).mesh
	if gi is GPUParticles3D:
		return (gi as GPUParticles3D).draw_pass_1
	return null


## What the renderer compiles for a material: a ShaderMaterial's shader (by file, or by code when made in a script),
## or a standard material's feature set.
static func _shader_key(mat: Material) -> String:
	if mat is ShaderMaterial:
		var sh := (mat as ShaderMaterial).shader
		if sh == null:
			return "shader:none"
		return sh.resource_path.get_file() if sh.resource_path != "" else "code:%d" % sh.code.hash()
	if mat is BaseMaterial3D:
		var b := mat as BaseMaterial3D
		return "std t%d b%d s%d c%d d%d" % [b.transparency, b.blend_mode, b.shading_mode, b.cull_mode, b.depth_draw_mode]
	return mat.get_class()


## Whether a surface's material (or one of its next passes) draws in the transparent pass.
func _see_through(first: Material) -> bool:
	var mat := first
	while mat != null:
		if mat is BaseMaterial3D:
			var b := mat as BaseMaterial3D
			if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or b.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
				return true
			if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
				return true
		elif mat is ShaderMaterial and (mat as ShaderMaterial).shader:
			var code: String = (mat as ShaderMaterial).shader.code
			for mode in BLEND_MODES:
				if code.contains(mode):
					return true
			if alpha_re.search(code) != null:
				return true
		mat = mat.next_pass
	return false


## Whether the camera can see any of a thing's box (a rough cull, like the renderer's frustum test).
func _in_view(gi: GeometryInstance3D) -> bool:
	var box := gi.global_transform * gi.get_aabb()
	if cam.is_position_in_frustum(box.get_center()):
		return true
	for i in 8:
		if cam.is_position_in_frustum(box.get_endpoint(i)):
			return true
	return _screen_area(gi) > 0.0


## The screen area (px^2) of a thing's box: the rectangle round its projected corners, clipped to the view. A box
## reaching behind the camera counts as the whole view; one wholly behind it as none.
func _screen_area(gi: GeometryInstance3D) -> float:
	var box := gi.global_transform * gi.get_aabb()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var behind := 0
	for i in 8:
		var corner := box.get_endpoint(i)
		if cam.is_position_behind(corner):
			behind += 1
			continue
		var p := cam.unproject_position(corner)
		lo = lo.min(p)
		hi = hi.max(p)
	if behind == 8:
		return 0.0
	if behind > 0:
		return view.x * view.y
	return Rect2(lo, hi - lo).intersection(Rect2(Vector2.ZERO, view)).get_area()


static func _tris(mesh: Mesh) -> int:
	var n := 0
	for si in mesh.get_surface_count():
		if mesh is ArrayMesh:
			var il := (mesh as ArrayMesh).surface_get_array_index_len(si)
			n += int((il if il > 0 else (mesh as ArrayMesh).surface_get_array_len(si)) / 3.0)
		else:
			n += int(mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX].size() / 3.0)
	return n


static func _mesh_name(mi: MeshInstance3D) -> String:
	if mi.mesh.resource_path != "":
		return mi.mesh.resource_path.get_file()
	var nm := String(mi.name).rstrip("0123456789@")
	return "%s<%s" % [mi.get_class() if nm.begins_with("@") else nm, owner_name(mi)]
