class_name FarmUnlocks
extends RefCounted
## What a farm may build, and when (docs/decisions/0004-farm-building.md). A new farm starts with
## the few things in farm_build.json that have no requirement; everything else opens through farm level
## (points from play) or a milestone (first extraction, first boss, three Boki scanned) and is then
## drawn up by Hob (FarmBuilder). The numbers and the table are content/rules/farm_build.json. Level
## and milestones are read off the lifetime stats, so an old save works out its own level at once.
##
## Only layouts made by the farm-building pass (layout["fb"] = 1) are gated; older farms keep
## everything open, and anything already placed or in storage always stays usable.

static func rules() -> Dictionary:
	return Content.rules("farm_build")

## The Boki-base cut (farm_build.json "base_mode"): the economy is hidden, nothing is deleted.
static func base_mode() -> bool:
	return bool(rules().get("base_mode", false))

## Is the gating on for this save?
static func gated(d: Dictionary = Save.d) -> bool:
	return int(HomeLayout.of(d).get("fb", 0)) >= 1 and not Game.modding()

## A lifetime stat the rules count.
static func stat(k: String) -> int:
	return Progress.stat(k)

## Farm points: play turned into a number.
static func points() -> float:
	var p := 0.0
	var w: Dictionary = rules()["points"]
	for k in w:
		p += float(stat(String(k))) * float(w[k])
	return p

## Farm level, 1 and up (the length of the "levels" table at most).
static func level() -> int:
	var lv := 1
	var tb: Array = rules()["levels"]
	var p := points()
	for i in tb.size():
		if p >= float(tb[i]): lv = i + 1
	return lv

static func max_level() -> int:
	return (rules()["levels"] as Array).size()

## [points into this level, points this level takes] for a progress bar ([0, 0] at the top).
static func progress() -> Array:
	var tb: Array = rules()["levels"]
	var lv := level()
	if lv >= tb.size():
		return [0, 0]
	var a := float(tb[lv - 1])
	return [points() - a, float(tb[lv]) - a]

static func milestone_done(id: String) -> bool:
	var m: Dictionary = rules()["milestones"].get(id, {})
	return not m.is_empty() and stat(String(m["stat"])) >= int(m["n"])

static func milestone_name(id: String) -> String:
	return String(rules()["milestones"].get(id, {}).get("name", id))

## What an item needs ({} when nothing).
static func need_of(id: String) -> Dictionary:
	return rules()["unlock"].get(id, {})

## Does the farm owe this item to you (placed already, or in storage)?
static func owned(id: String) -> bool:
	if HomeLayout.CATALOG.has(id):
		return HomeLayout.count_of(id, Save.d) > 0
	return Save.has_building(id)

## Does the farm's level or milestone allow it? (Hob still has to draw it up: open().)
static func eligible(id: String) -> bool:
	var need := need_of(id)
	if need.has("level") and level() < int(need["level"]):
		return false
	if need.has("milestone") and not milestone_done(String(need["milestone"])):
		return false
	return true

## May it be built now? Anything with a requirement also needs Hob to have drawn it up (FarmBuilder).
static func open(id: String) -> bool:
	if id == SnackPatch.ID and not base_mode():
		return false
	if not gated():
		return true
	var need := need_of(id)
	if need.is_empty() or owned(id):
		return true
	return eligible(id) and FarmBuilder.drawn(id)

## Why it is locked, for the build menu ("" when it is open).
static func lock_text(id: String) -> String:
	if open(id):
		return ""
	var need := need_of(id)
	if need.has("milestone") and not milestone_done(String(need["milestone"])):
		return String(rules()["milestones"][need["milestone"]]["text"])
	if eligible(id):
		return "Ask %s to draw it up" % FarmBuilder.short_name()
	return "Farm level %d" % int(need.get("level", 1))

## Incubator cradle number n (6th, 7th, 8th): "" if you may buy it, else why not.
static func cradle_lock(n: int) -> String:
	if not gated():
		return ""
	var need := int(rules()["cradles"].get(str(n), 0))
	if level() >= need:
		return ""
	return "Cradle %d opens at farm level %d" % [n, need]

## Name of a build menu entry (a catalog item or one of the lots).
static func name_of(id: String) -> String:
	if HomeLayout.CATALOG.has(id): return String(HomeLayout.CATALOG[id]["name"])
	return String(Data.BUILDINGS.get(id, {}).get("name", id))
