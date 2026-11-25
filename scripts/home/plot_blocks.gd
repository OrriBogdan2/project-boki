class_name PlotBlocks
extends RefCounted
## The tiles a crop bed (Models.plot) fills, so you and the Boki walk round a bed and along it, never through it.
## HomeBuild._apply_blockers turns them solid like any placed block.

const HALF := 0.75  # m from a bed's centre: a tile it covers by more than a hand's width is blocked (the slab is 1.7 m)


## The blocked tiles of every bed at `spots` (their centres, from Home._plot_spots).
static func tiles(spots: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for at: Vector3 in spots:
		for z in range(floori(at.z - HALF), floori(at.z + HALF) + 1):
			for x in range(floori(at.x - HALF), floori(at.x + HALF) + 1):
				out.append(Vector2i(x, z))
	return out
