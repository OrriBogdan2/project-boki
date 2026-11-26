class_name KinSize
extends RefCounted
## How tall a rigged Boki stands on screen: its species' size (content/kin/<id>.json size.cm) times M_PER_CM, whatever
## the glb's own scale. The rig measures the mesh at build (height), and its Flex is scaled by fit() so every Meshy model
## lands at its data height; the kin's own roll (Unique, Evo growth, Mutations) multiplies on top, as before.

## World metres a Boki of 1 cm stands, at root scale 1. The match and, times Home's FARM_BOKI_SCALE, the farm draw it.
const M_PER_CM := 0.014

static var _heights := {}


## The metres a rig's meshes stand tall in `model`'s own space, from the lowest to the highest bind-pose bound.
static func height(model: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var to_model := Transform3D.IDENTITY
		var up: Node = mi
		while up != model:
			to_model = (up as Node3D).transform * to_model
			up = up.get_parent()
		var box := to_model * mi.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	return maxf(hi - lo, 0.0)


## The height a species' average one stands at, in metres.
static func target(species: String) -> float:
	return float(Unique.base_size(species)["cm"]) * M_PER_CM


## The scale that takes a species' `model` (just instanced, unscaled) to its target height. Measured once per species.
static func fit(species: String, model: Node3D) -> float:
	if not _heights.has(species):
		_heights[species] = height(model)
	return target(species) / maxf(float(_heights[species]), 0.01)
