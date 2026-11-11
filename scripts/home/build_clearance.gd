class_name BuildClearance
extends RefCounted
## Room to walk round what you build. A building (a house, a work station, a lot, a trough) keeps a ring of
## CLEAR_TILES round its footprint free of anything solid (other buildings, props, fences, trees, rocks and
## cliffs), and nothing solid goes down inside that ring of a building already standing. So no gap next to a
## building is narrower than a body, and nothing gets caught between two things. HomeBuild asks this before
## the path check (HomeBuild.keeps_paths), which also refuses a piece that would shut in a pocket of ground.

# tiles (1 m each) kept open round a building: wider than the player (0.76 m across) and a Boki (0.6 m)
const CLEAR_TILES := 1
const NEAR_TEXT := "Too close to the %s: leave room to walk"
const NEAR_ANY := "Too close to something: leave room to walk"
const NEAR_CLIFF := "Too close to the cliff: leave room to walk"

## "" if the held item may stand on `at` with room round it, else the reason. tag: what is being moved (its own
## tiles count as free).
static func reason(hb: HomeBuild, item: Dictionary, at: Array, tag: String) -> String:
	var holder := is_building(item)
	if not holder and not _solid_item(item):
		return ""
	var w: World = hb.h.world
	var mine := {}
	for c in at:
		mine[c] = true
	for c in at:
		for dz in range(-CLEAR_TILES, CLEAR_TILES + 1):
			for dx in range(-CLEAR_TILES, CLEAR_TILES + 1):
				var n := Vector2i(c.x + dx, c.y + dz)
				if mine.has(n) or not w.inb(n.x, n.y):
					continue
				var why := _ring_reason(hb, w.idx(n.x, n.y), tag, holder)
				if why != "":
					return why
	return ""

## Is this held item a building that keeps room round it?
static func is_building(item: Dictionary) -> bool:
	var kind := String(item.get("kind", ""))
	if kind == "b" or kind == "feeder":
		return true
	return kind == "deco" and _building_id(String(item.get("id", "")))

static func _building_id(id: String) -> bool:
	var c: Dictionary = HomeLayout.CATALOG.get(id, {})
	return HomeLayout.blocks(id) and String(c.get("cat", "")) in ["Buildings", "Work"]

static func _solid_item(item: Dictionary) -> bool:
	return String(item.get("kind", "")) == "deco" and HomeLayout.blocks(String(item.get("id", "")))

## Why tile i (in the ring round the footprint) is too close: for a building, anything solid on it; for a
## prop or fence, a building on it.
static func _ring_reason(hb: HomeBuild, i: int, tag: String, holder: bool) -> String:
	var o := String(hb.occ.get(i, ""))
	if o != "" and o == tag:
		return ""
	if o != "" and _building_tag(hb, o):
		return NEAR_TEXT % hb.occ_name(o).to_lower()
	if not holder:
		return ""
	if hb.wild_t.get(i, "") == "cliff" or hb.cliff_t.has(i):
		return NEAR_CLIFF
	if hb.h.world.kind[i] != World.T_BLOCK:
		return ""
	return NEAR_TEXT % hb.occ_name(o).to_lower() if o != "" else NEAR_ANY

## Does this occ tag belong to a building (a lot, a trough, a house or station)?
static func _building_tag(hb: HomeBuild, o: String) -> bool:
	if o.begins_with("b:") or o.begins_with("f:"):
		return true
	if not o.begins_with("d:"):
		return false
	var e := hb._deco_by_uid(int(o.substr(2)))
	return not e.is_empty() and _building_id(String(e["id"]))
