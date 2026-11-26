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
## 0.8 m long). The match and, times Home's FARM_BOKI_SCALE, the farm draw it.
const M_PER_CM := 0.029
## A Boki's read (m) per metre of data length: the starters' own share at the length fit, so they keep their size.
const READ_SHARE := 0.66
const PITCHES := [57.0, 20.0]  # degrees down from level the read is averaged over (CamRig match, FarmCam)
const YAWS := 4  # turns of the model (evenly round half a circle) the read is averaged over

static var _sizes := {}  # species -> the Vector3 box of its model, measured at the first fit
static var _reads := {}  # species -> its model's read (m) at fit 1, measured at the first fit


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


## The longest side a species' average one has, in metres.
static func target(species: String) -> float:
	return float(Unique.base_size(species)["cm"]) * M_PER_CM


## The scale that takes a species' `model` (just instanced, unscaled) to its target size. Measured once per species.
static func fit(species: String, model: Node3D) -> float:
	if not _sizes.has(species):
		_sizes[species] = box(model)
		_reads[species] = read(model)
	return target(species) * READ_SHARE / maxf(float(_reads[species]), 0.01)


## The metres a model reads as (in `model`'s own space): the square root of the area its meshes' silhouette (their
## vertices' convex hull) covers, averaged over YAWS turns at each of PITCHES, the pitches' areas multiplied together
## (a geometric mean, so neither view outweighs the other).
static func read(model: Node3D) -> float:
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
		# only the corners of each mesh's 3D convex hull can be on a silhouette's hull (exact, and a few hundred
		# points instead of tens of thousands)
		for v in mi.mesh.create_convex_shape(true, false).points:
			pts.append(to_model * v)
	var all := 1.0
	for p in PITCHES:
		var area := 0.0
		for i in YAWS:
			area += cover(pts, deg_to_rad(p), PI * float(i) / YAWS)
		all *= area / YAWS
	return sqrt(pow(all, 1.0 / PITCHES.size()))


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
