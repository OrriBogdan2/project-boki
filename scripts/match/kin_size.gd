class_name KinSize
extends RefCounted
## How big a rigged Boki is: its species' size (content/kin/<id>.json size.cm) times M_PER_CM, read the way a player
## reads it, by the screen it covers. A Boki's "read" is the square root of the area its silhouette covers, averaged
## over turns of the model and over both views it is seen from (the match camera's 57 degrees and the farm's low
## third-person 20 degrees), and fit() scales the Flex so that read is READ_SHARE of its data length. The longest side
## alone would not do: a tall, narrow Vespyx and a low, long Prismander of the same length read 1.2x apart from the
## farm's low view. Meshy models of any proportion land at the same look; the kin's own roll (Unique, Evo growth,
## Mutations) multiplies on top.

## The one display scale for every rigged Boki: world metres per data cm, at root scale 1. Data cm stay the truth for
## how big one is next to another; this only sets how big they all stand next to a hunter (a 28 cm starter is about
## 0.8 m long). The match draws it at this scale.
const M_PER_CM := 0.029

## The farm's own display scale, metres per data cm at root scale 1: its camera sits much further back, so a Boki is
## drawn bigger there. Home's FARM_BOKI_SCALE is this over M_PER_CM, so changing M_PER_CM resizes the match and leaves
## the farm as it is.
const FARM_M_PER_CM := 0.04437

## A Boki's idle read (m) per metre of data length: set so the starters keep, on average, the size they stood at
## when the bind pose was fit by its longest side (0.66 of the bind read, x0.82 for idle's tuck).
const READ_SHARE := 0.54
const PITCHES := [57.0, 20.0]  # degrees down from level the read is averaged over (CamRig match, FarmCam)
## Each species' read (m, at fit 1) in its idle pose, the way a player sees it: content/rules/kin_read.json, written by
## `--kin-size-check --write` (CPU-skinned, slow, so not at run time). A bind pose spreads tails and limbs that idle
## tucks in, by a different share per species (Mycroll and Prismander curl to ~0.7 of their bind length, Vespyx
## stands as bound), so measuring the bind pose left the starters reading 1.25x apart on the farm. A species missing
## from it (a new model before the next --write) is measured in its bind pose at its first fit.
const READS := "kin_read"
const YAWS := 4  # turns of the model (evenly round half a circle) the read is averaged over

static var _sizes := {}  # species -> the Vector3 box of its model, measured at the first fit
static var _reads := {}  # species -> its model's read (m) at fit 1, from READS or measured at the first fit


## The metres of the bind-pose box round a rig's meshes, in `model`'s own space.
static func box(model: Node3D) -> Vector3:
	var all := AABB()
	var first := true
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var to_model := Transform3D.IDENTITY
		var up: Node = mi
		while up != model:
			to_model = (up as Node3D).transform * to_model
			up = up.get_parent()
		all = to_model * mi.get_aabb() if first else all.merge(to_model * mi.get_aabb())
		first = false
	return all.size


## A species' average one's data length in metres (size.cm x M_PER_CM); fit() makes it read READ_SHARE of that.
static func target(species: String) -> float:
	return float(Unique.base_size(species)["cm"]) * M_PER_CM


## The scale that takes a species' `model` (just instanced, unscaled) to its target size. Measured once per species.
static func fit(species: String, model: Node3D) -> float:
	if not _sizes.has(species):
		_sizes[species] = box(model)
		var known: Dictionary = Content.rules(READS).get("reads", {})
		_reads[species] = float(known[species]) if known.has(species) else read(model)
	return target(species) * READ_SHARE / maxf(float(_reads[species]), 0.01)


## The metres a model reads as (in `model`'s own space): the square root of the area its meshes' silhouette (their
## vertices' convex hull) covers, averaged over YAWS turns at each of PITCHES, the pitches' reads multiplied together
## (a geometric mean, so neither view outweighs the other). `posed`: skinned meshes as their skeleton holds them now
## (every vertex skinned on the CPU: tools only).
static func read(model: Node3D, posed := false) -> float:
	var pts := points(model, posed)
	var all := 1.0
	for p in PITCHES:
		all *= read_at(pts, p)
	return pow(all, 1.0 / PITCHES.size())


## The m `pts` read as from `pitch` degrees down: the root of their hull's area, averaged over YAWS turns.
static func read_at(pts: PackedVector3Array, pitch: float) -> float:
	var area := 0.0
	for i in YAWS:
		area += cover(pts, deg_to_rad(pitch), PI * float(i) / YAWS)
	return sqrt(area / YAWS)


## The points of `model`'s meshes, in its own space, that can make its silhouette: the corners of each mesh's 3D convex
## hull (exact, and a few hundred points instead of tens of thousands), or, `posed`, every vertex as skinned now.
static func points(model: Node3D, posed := false) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var to_model := Transform3D.IDENTITY
		var up: Node = mi
		while up != model:
			to_model = (up as Node3D).transform * to_model
			up = up.get_parent()
		if posed and mi.skin != null:
			pts.append_array(skinned(mi, mi.get_node(mi.skeleton) as Skeleton3D, to_model))
			continue
		for v in mi.mesh.create_convex_shape(true, false).points:
			pts.append(to_model * v)
	return pts


## Every vertex of `mi` as `skel` poses it now, through `to` (`mi`'s own space to the caller's; skinning poses in
## it). Godot's own bake_mesh_from_current_skeleton_pose fails headless ("skin registered with a valid skeleton"),
## so: linear blend skinning, each vertex the weighted sum of its bones' global pose times their bind pose.
static func skinned(mi: MeshInstance3D, skel: Skeleton3D, to: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var binds: Array[Transform3D] = []
	for i in mi.skin.get_bind_count():
		var bone := mi.skin.get_bind_bone(i)
		if bone < 0:
			bone = skel.find_bone(mi.skin.get_bind_name(i))
		binds.append(to * skel.get_bone_global_pose(bone) * mi.skin.get_bind_pose(i))
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(verts.size(), 1)
		for v in verts.size():
			var at := Vector3.ZERO
			for j in per:
				var w := weights[v * per + j]
				if w > 0.0:
					at += (binds[bones[v * per + j]] * verts[v]) * w
			out.append(at)
	return out


## The m2 the convex hull of `pts` covers seen from `pitch` radians down, the points turned `yaw` round up first.
static func cover(pts: PackedVector3Array, pitch: float, yaw: float) -> float:
	var turn := Basis(Vector3.UP, yaw)
	var flat := PackedVector2Array()
	flat.resize(pts.size())
	for i in pts.size():
		var w := turn * pts[i]
		flat[i] = Vector2(w.x, w.y * cos(pitch) - w.z * sin(pitch))
	var hull := Geometry2D.convex_hull(flat)
	var area := 0.0
	for j in hull.size() - 1:
		area += hull[j].x * hull[j + 1].y - hull[j + 1].x * hull[j].y
	return absf(area) * 0.5


## The metres a species' model stands tall at fit 1 (the rig's own height, for its water line). Needs fit() first.
static func height(species: String) -> float:
	return float((_sizes[species] as Vector3).y)
