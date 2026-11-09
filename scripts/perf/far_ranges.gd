class_name FarRanges
extends RefCounted
## How far each class of scatter draws, and the merged far version of cliffs (DECISIONS 2026-11-08
## performance pass). Small clutter fades out first, trees later, boulders after them, cliffs last (their
## silhouette is what reads from the skyship). High and Ultra never drop a tree, boulder or cliff, so
## their looks don't change; the lower presets drop them past the range, cross-faded over FADE metres.
## Cliffs also get a far version past `near`: coarse-LOD copies batched over FAR_CHUNK-tile blocks (nine
## near batches become one draw), faded in as the detailed batches fade out.

const SMALL := 130.0         # m at High: grass, flowers, pebbles (x Settings q("draw"))
const BUSH := 160.0          # m at High: tall grass and undergrowth (x q("draw"))
const FADE := 10.0           # m a batch takes to dither out (or in)
const FAR_CHUNK := 48        # tiles: the far cliff version batches over blocks this wide
const MIN_LOD_TRIS := 240    # a mesh under this has nothing to simplify
const BIG_CLASSES := ["tree", "rock", "cliff"]
## Per preset, in metres from the camera, 0 = never dropped. `near`: where cliffs swap to the far version.
const BIG := {
	"ultra": {"tree": 0.0, "rock": 0.0, "cliff": 0.0, "near": 220.0},
	"high": {"tree": 0.0, "rock": 0.0, "cliff": 0.0, "near": 170.0},
	"medium": {"tree": 200.0, "rock": 170.0, "cliff": 300.0, "near": 130.0},
	"low": {"tree": 150.0, "rock": 130.0, "cliff": 230.0, "near": 100.0},
	"very_low": {"tree": 110.0, "rock": 95.0, "cliff": 170.0, "near": 70.0},
}

## The class of one scatter batch: its group's "far" hint ("tree", "rock" or "cliff"), or the name.
static func class_of(label: String, chunk: int, hint := "") -> String:
	if label.begins_with("Bushes"):
		return "bush"
	if hint in BIG_CLASSES:
		return hint
	if label.begins_with("Grass") or label.begins_with("Flowers") or label.begins_with("Pebbles") or chunk >= 32:
		return "small"
	return "rock"

## The draw distance in metres for a class (0 = unlimited).
static func end_of(cls: String) -> float:
	var k := float(Settings.q("draw"))
	match cls:
		"small": return SMALL * k
		"bush": return BUSH * k
	return float(_row()[cls])

static func _row() -> Dictionary:
	return BIG.get(Settings.quality(), BIG["high"])

## Hides `gi` past `end` m (not at all when end is 0), dithering out over FADE.
static func limit(gi: GeometryInstance3D, end: float) -> void:
	if end <= 0.0:
		return
	gi.visibility_range_end = end
	gi.visibility_range_end_margin = FADE
	gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

## Big scatter meshes get level-of-detail versions (fewer triangles far away), made once per mesh.
static var _lod_cache := {}
static func with_lods(m: Mesh) -> Mesh:
	return _lods(m)[0]

## The far version of a mesh: its coarsest LOD as a mesh of its own, or null when it has none.
static func coarse(m: Mesh) -> Mesh:
	return _lods(m)[1]

## [mesh with LODs, coarsest LOD alone or null] for one mesh (cached).
static func _lods(m: Mesh) -> Array:
	if not (m is ArrayMesh) or "--no-lod" in OS.get_cmdline_user_args():
		return [m, null]
	if _lod_cache.has(m):
		return _lod_cache[m]
	var am := m as ArrayMesh
	var out := [m, null]
	var tris := 0
	for si in am.get_surface_count():
		tris += am.surface_get_array_index_len(si) / 3
	if tris >= MIN_LOD_TRIS and am.get_blend_shape_count() == 0:
		var im := ImporterMesh.new()
		for si in am.get_surface_count():
			im.add_surface(am.surface_get_primitive_type(si), am.surface_get_arrays(si), [], {}, am.surface_get_material(si), am.surface_get_name(si))
		if im.get_method_argument_count("generate_lods") >= 3:
			im.call("generate_lods", 25.0, 60.0, [])
		else:
			im.call("generate_lods", 25.0, [])
		out = [im.get_mesh(), _coarsest(im, am)]
	_lod_cache[m] = out
	return out

static func _coarsest(im: ImporterMesh, am: ArrayMesh) -> Mesh:
	var far := ArrayMesh.new()
	for si in im.get_surface_count():
		var lods := im.get_surface_lod_count(si)
		if lods == 0:
			return null
		var arrays := im.get_surface_arrays(si)
		arrays[Mesh.ARRAY_INDEX] = im.get_surface_lod_indices(si, lods - 1)
		far.add_surface_from_arrays(am.surface_get_primitive_type(si), arrays)
	return far

## Cliff batch: the detailed MultiMesh gets `near` as its range, and the coarse copies of the same
## instances (items = [transform, colour]) are added in FAR_CHUNK blocks from there outward.
## Returns `near`, the range for the detailed batches, or 0 when the mesh has no far version (they keep the class range).
static func add_far_cliffs(parent: Node3D, items: Array, mesh: Mesh, mat: Material, label: String) -> float:
	var row := _row()
	var cm := coarse(mesh)
	if cm == null or float(row["near"]) <= 0.0:
		return 0.0
	var by := {}
	for it in items:
		var o: Vector3 = (it[0] as Transform3D).origin
		var key := Vector2i(int(o.x) / FAR_CHUNK, int(o.z) / FAR_CHUNK)
		if not by.has(key): by[key] = []
		by[key].append(it)
	for key in by:
		var list: Array = by[key]
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = cm
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k][0])
			mm.set_instance_color(k, list[k][1])
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_begin = float(row["near"])
		mi.visibility_range_begin_margin = FADE
		limit(mi, float(row["cliff"]))
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mi.name = "%s_far_%d_%d" % [label, key.x, key.y]
		parent.add_child(mi)
	return float(row["near"])
