class_name FarmWater
extends RefCounted
## Placing by the water (docs/decisions/0011-farm-builder-tutorial.md, numbers in docs/FARM_LOOP.md).
## Water is a pond, a river you painted, or the wild water the island came with: all of it lives in
## layout["water"]. Within reach tiles of it a crop patch waters itself (its plots are tended without
## you or the rain) and grows grow_mul() times as fast; a trough tops itself up from your pantry like a
## hopper. Away from water you water the patch and fill the trough yourself. Build mode shows a water
## drop and what you get over the patch or trough you are placing; the tutorial's crop step points at the water.

static func _rule(k: String, def: float) -> float:
	return float(FarmUnlocks.rules().get("water", {}).get(k, def))

static func reach() -> int:
	return int(_rule("reach", 2))

## How much faster a crop by the water grows (1.25: each stage takes 1 / 1.25 of the time).
static func grow_mul() -> float:
	return _rule("grow", 1.25)

## Seconds one growth stage of plot i in arr ("plots" or "gh_plots") takes while you're home.
static func stage_s(d: Dictionary, arr: String, i: int) -> float:
	var s := Data.WATER_TIME * (0.5 if arr == "gh_plots" else 1.0)
	if arr == "plots" and plot_near(d, i):
		s /= grow_mul()
	return FarmCropGuide.stage_time(s)

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

## Is a trough (a Save.d feeders entry) by water?
static func near_feeder(d: Dictionary, f: Dictionary) -> bool:
	return near_cells(d, [Vector2i(int(floor(float(f.get("x", 0.0)))), int(floor(float(f.get("z", 0.0)))))])

## The plot panel's line for a patch by the water.
static func plot_note() -> String:
	return "By the water: it waters itself and grows %d%% faster." % roundi((grow_mul() - 1.0) * 100.0)

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
