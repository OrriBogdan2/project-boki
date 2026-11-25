class_name PlotBlocks
extends RefCounted
## The tiles a crop bed (Models.plot) fills, so you and the Boki walk round a bed and along it, never through it.
## HomeBuild._apply_blockers turns them solid like any placed block.

const REACH := 2  # tiles from a bed's centre tile at which you can work it (its edge is a tile away)
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const HALF := 0.75  # m from a bed's centre: a tile it covers by more than a hand's width is blocked (the slab is 1.7 m)


## The blocked tiles of every bed at `spots` (their centres, from Home._plot_spots).
static func tiles(spots: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for at: Vector3 in spots:
		for z in range(floori(at.z - HALF), floori(at.z + HALF) + 1):
			for x in range(floori(at.x - HALF), floori(at.x + HALF) + 1):
				out.append(Vector2i(x, z))
	return out


## The tiles beside a bed (`beds`) that `shut(tile)` says are walled in on all four sides: you could not get into
## them, and the island's every open tile must be reachable.
static func pockets(beds: Array[Vector2i], shut: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in beds:
		for d: Vector2i in SIDES:
			var at := t + d
			if at in beds or at in out:
				continue
			if SIDES.all(func(n: Vector2i) -> bool: return shut.call(at + n)):
				out.append(at)
	return out
