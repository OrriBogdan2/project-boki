class_name KinSize
extends RefCounted
## How big a rigged Boki is: its species' size (content/kin/<id>.json size.cm) times M_PER_CM is the longest side of
## its body (width, height or length), whatever the glb's own scale. The game camera looks down, so a body's footprint
## decides how big it reads and equal heights would not (a long, low Prismander beside a tall Vespyx). The rig measures
## the mesh at build (extent) and its Flex is scaled by fit(), so Meshy models of any proportion land at the same
## look; the kin's own roll (Unique, Evo growth, Mutations) multiplies on top.

## The one display scale for every rigged Boki: world metres per data cm, at root scale 1. Data cm stay the truth for
## how big one is next to another; this only sets how big they all stand next to a hunter (a 28 cm starter is 0.81 m
## long, about 1200 px at the game camera). The match and, times Home's FARM_BOKI_SCALE, the farm draw it.
const M_PER_CM := 0.029

static var _sizes := {}  # species -> the Vector3 box of its model, measured at the first fit


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
	var b: Vector3 = _sizes[species]
	return target(species) / maxf(b[b.max_axis_index()], 0.01)


## The metres a species' model stands tall at fit 1 (the rig's own height, for its water line). Needs fit() first.
static func height(species: String) -> float:
	return float((_sizes[species] as Vector3).y)
