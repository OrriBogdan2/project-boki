class_name BlockPrune
extends RefCounted
## Clears lone blocked tiles from a generated map (Training Grounds, duel room): a one- or two-tile
## post is where a thrown or fired shot clips and nobody expects it. Whatever stays is a wall or a
## rock you can read. The same piece-finder backs tools/wall_size_check.gd.

## Ground this small (tiles) sealed in by blockers on every side is filled in.
const POCKET_MAX := 6
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

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

## Every patch of ground (up to POCKET_MAX tiles) walled in by blockers on all four sides of every tile: a
## Hunter who lands there (a glide, a knock, the old rock hop) can't walk out. A body never fits through the
## corner gap between two diagonal blockers, so tiles connect only through their sides. Ground next to the
## abyss or a lower or higher terrace is never sealed.
static func pockets(world: World) -> Array:
	var seen := {}
	var found: Array = []
	for z in world.h:
		for x in world.w:
			var start := Vector2i(x, z)
			if seen.has(start) or not _open(world, start):
				continue
			var group: Array = []
			var sealed := true
			var queue: Array = [start]
			seen[start] = true
			while not queue.is_empty():
				var tile: Vector2i = queue.pop_back()
				group.append(tile)
				for step in SIDES:
					var next: Vector2i = tile + step
					if not world.inb(next.x, next.y):
						continue
					var k: int = world.kind[world.idx(next.x, next.y)]
					if k == World.T_BLOCK:
						continue
					var lv_next: int = world.level[world.idx(next.x, next.y)]
					if not _open(world, next) or lv_next != world.level[world.idx(tile.x, tile.y)]:
						sealed = false
						continue
					if not seen.has(next):
						seen[next] = true
						queue.append(next)
			if sealed and group.size() <= POCKET_MAX:
				found.append(group)
	return found

static func _open(world: World, tile: Vector2i) -> bool:
	return world.inb(tile.x, tile.y) and world.kind[world.idx(tile.x, tile.y)] == World.T_GROUND

## Fills every sealed pocket with rock.
static func fill_pockets(world: World) -> void:
	for group: Array in pockets(world):
		for tile: Vector2i in group:
			world.kind[world.idx(tile.x, tile.y)] = World.T_BLOCK
