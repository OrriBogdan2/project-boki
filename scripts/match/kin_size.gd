class_name KinSize
extends RefCounted
## How big a rigged Boki is: its species' size (content/kin/<id>.json size.cm) times M_PER_CM is the longest side of
## its body (width, height or length), whatever the glb's own scale. The game camera looks down, so a body's footprint
## decides how big it reads and equal heights would not (a long, low Prismander beside a tall Vespyx). The rig measures
## the mesh at build (extent) and its Flex is scaled by fit(), so Meshy models of any proportion land at the same
## look; the kin's own roll (Unique, Evo growth, Mutations) multiplies on top.

## World metres a Boki of 1 cm stands, at root scale 1. The match and, times Home's FARM_BOKI_SCALE, the farm draw it.
const M_PER_CM := 0.014

static var _extents := {}


## The metres of the longest side of the bind-pose box round a rig's meshes, in `model`'s own space.
static func extent(model: Node3D) -> float:
	var box := AABB()
	var first := true
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var to_model := Transform3D.IDENTITY
		var up: Node = mi
		while up != model:
			to_model = (up as Node3D).transform * to_model
			up = up.get_parent()
		box = to_model * mi.get_aabb() if first else box.merge(to_model * mi.get_aabb())
		first = false
	return box.size[box.size.max_axis_index()]


## The longest side a species' average one has, in metres.
static func target(species: String) -> float:
	return float(Unique.base_size(species)["cm"]) * M_PER_CM


## The scale that takes a species' `model` (just instanced, unscaled) to its target size. Measured once per species.
static func fit(species: String, model: Node3D) -> float:
	if not _extents.has(species):
		_extents[species] = extent(model)
	return target(species) / maxf(float(_extents[species]), 0.01)
