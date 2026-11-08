class_name BlockPrune
extends RefCounted
## Clears lone blocked tiles from a generated map (Training Grounds, duel room): a one- or two-tile
## post is where a thrown or fired shot clips and nobody expects it. Whatever stays is a wall or a
## rock you can read. The same piece-finder backs tools/wall_size_check.gd.

## The smallest piece that stays: 3 tiles is the shortest run that reads as a wall, not a stump.
const MIN_TILES := 3
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

## Every connected group of blocked tiles in a world (corner-touching tiles are one piece).
static func pieces(world: World) -> Array:
	var seen := {}
	var found: Array = []
	for z in world.h:
		for x in world.w:
			var start := Vector2i(x, z)
			if world.kind[world.idx(x, z)] == World.T_BLOCK and not seen.has(start):
				found.append(_flood(world, start, seen))
	return found

static func _flood(world: World, start: Vector2i, seen: Dictionary) -> Array:
	var group: Array = []
	var queue: Array = [start]
	seen[start] = true
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_back()
		group.append(tile)
		for step in NEIGHBOURS:
			var next: Vector2i = tile + step
			if seen.has(next) or not world.inb(next.x, next.y):
				continue
			if world.kind[world.idx(next.x, next.y)] == World.T_BLOCK:
				seen[next] = true
				queue.append(next)
	return group

## Turns every piece under min_tiles back into open ground.
static func prune(world: World, min_tiles: int) -> void:
	for group: Array in pieces(world):
		if group.size() >= min_tiles:
			continue
		for tile: Vector2i in group:
			var i := world.idx(tile.x, tile.y)
			world.kind[i] = World.T_GROUND
			world.walls.erase(i)
			world.props.erase(i)
