class_name FarmWater
extends RefCounted
## Crops by the water (docs/decisions/0011-farm-builder-tutorial.md). A crop patch within REACH tiles of
## water (a pond, a river you painted, or the wild water the island came with: all of them live in
## layout["water"]) waters itself: its plots are tended without you or the rain. Build mode says
## "near water" in green over the patch you are placing, and the tutorial's crop step points at the water.

static func reach() -> int:
	return int(FarmUnlocks.rules().get("water", {}).get("reach", 2))

static func tiles(d: Dictionary) -> Dictionary:
	return HomeLayout.of(d).get("water", {})

## Is any water within reach of these tiles (the tiles themselves count)?
static func near_cells(d: Dictionary, cells: Array) -> bool:
	var wt := tiles(d)
	if wt.is_empty() or cells.is_empty():
		return false
	var r := reach()
	for c in cells:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if wt.has(HomeLayout.key(c.x + dx, c.y + dz)):
					return true
	return false

## The tiles a deco entry (the patch) stands on.
static func cells_of_entry(e: Dictionary) -> Array:
	var sz := HomeLayout.size_of(String(e["id"]), int(e.get("r", 0)))
	return HomeLayout.cells_of([int(e["x"]), int(e["z"]), int(e["x"]) + sz.x - 1, int(e["z"]) + sz.y - 1])

static func near_entry(d: Dictionary, e: Dictionary) -> bool:
	return near_cells(d, cells_of_entry(e))

## Is plot i (Save.d.plots, four to each patch in the order they were put down) by water?
static func plot_near(d: Dictionary, i: int) -> bool:
	var fx := HomeLayout.fixtures(d, "farm")
	var p := i / 4
	return p < fx.size() and near_entry(d, fx[p])

## The water tile nearest to a point (tile coordinates), or Vector2i(-1, -1) if there is none.
static func nearest(d: Dictionary, from: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for k in tiles(d):
		var c := HomeLayout.unkey(String(k))
		var dd := Vector2(c.x + 0.5, c.y + 0.5).distance_to(from)
		if dd < bd:
			bd = dd
			best = c
	return best

static func tip() -> String:
	return String(FarmUnlocks.rules().get("water", {}).get("tip", ""))
