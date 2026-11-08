class_name FarmBuilder
extends RefCounted
## Hob Brackenridge's blueprints (content/rules/farm_builder.json, docs/decisions/0011-farm-builder-tutorial.md).
## Everything in farm_build.json "unlock" opens by farm level or milestone, but only becomes buildable
## once Hob has drawn it up (you talk to him). What he has drawn lives on the layout:
##   layout["hob"] = {given: [ids], told: how many pending blueprints the player was told about, met: talked once}
## A save from before him has layout["hob"] = {legacy: true}: the first look hands it everything it
## could already build, so nobody loses a building.

static func rules() -> Dictionary:
	return Content.rules("farm_builder")

## His names live with every NPC's in npc_talk.json.
static func short_name() -> String:
	return String(Content.rules("npc_talk")["speakers"]["hob"]["short"])

static func full_name() -> String:
	return String(Content.rules("npc_talk")["speakers"]["hob"]["name"])

## The saved state, made (or upgraded from a legacy marker) on the first look.
static func state() -> Dictionary:
	var lay := HomeLayout.of(Save.d)
	var st: Dictionary = lay.get("hob", {}) if typeof(lay.get("hob")) == TYPE_DICTIONARY else {}
	if st.is_empty() or bool(st.get("legacy", false)):
		var legacy := bool(st.get("legacy", false))
		st = {"given": [], "told": 0, "met": legacy}
		lay["hob"] = st
		if legacy:
			st["given"] = all_ids().filter(func(id): return FarmUnlocks.eligible(String(id)))
	return st

## Save migration v7 -> v8: a save with a Boki has played, so it skips the tutorial and Hob hands
## it the blueprints it already had (the legacy marker, resolved on the first look).
## Keyed by its own field (data.farm_builder), not the save version, so it holds however the version
## numbers end up; it runs from the v7 -> v8 step and again at load for any save that lacks the field.
static func migrate(data: Dictionary) -> void:
	if data.has("farm_builder"):
		return
	data["farm_builder"] = 1
	if (data.get("roster", []) as Array).is_empty():
		return
	if typeof(data.get("tutorial")) != TYPE_DICTIONARY:
		data["tutorial"] = {}
	data["tutorial"]["day1_done"] = true
	data["tutorial"]["ft"] = {"did": {}, "done": true, "skipped": false, "gift": true}
	if typeof(data.get("layout")) == TYPE_DICTIONARY:
		data["layout"]["hob"] = {"legacy": true}

static func all_ids() -> Array:
	return (FarmUnlocks.rules()["unlock"] as Dictionary).keys()

static func drawn(id: String) -> bool:
	return (state()["given"] as Array).has(id)

## Blueprints the farm has earned that Hob hasn't drawn yet.
static func pending() -> Array:
	return all_ids().filter(func(id): return FarmUnlocks.eligible(String(id)) and not drawn(String(id)))

## Does anything remain locked (so the menu says to talk to him)?
static func more_to_come() -> bool:
	return FarmUnlocks.gated() and all_ids().any(func(id): return not FarmUnlocks.open(String(id)))

## Hob draws up everything pending. Returns the ids.
static func draw_up() -> Array:
	var out := pending()
	var st := state()
	for id in out:
		(st["given"] as Array).append(id)
	st["told"] = 0
	st["met"] = true
	return out

## True once per batch of new blueprints: for the toast.
static func toast_due() -> bool:
	var n := pending().size()
	var st := state()
	if n <= int(st.get("told", 0)):
		return false
	st["told"] = n
	return true

## What he says after drawing up `ids` (none: the nothing-new line). Milestones first, then the highest level.
static func line_for(ids: Array, first_visit: bool) -> String:
	var lines: Dictionary = rules()["lines"]
	if ids.is_empty():
		return String(lines["first"] if first_visit else lines["nothing"])
	var top := 0
	for id in ids:
		var need := FarmUnlocks.need_of(String(id))
		if need.has("milestone") and lines.has(need["milestone"]):
			return String(lines[need["milestone"]])
		top = maxi(top, int(need.get("level", 0)))
	return String(lines.get("level_%d" % top, lines["nothing"]))

# ------------------------------------------------------------------ the build menu
## A tab that has nothing to build right now is hidden (the three fixed ones stay).
static func tab_shown(hb: HomeBuild, ct: String) -> bool:
	if not FarmUnlocks.gated() or ct in ["Buildings", "Upgrades", "Island"]:
		return true
	var keep: String = hb.cat
	hb.cat = ct
	var any := not hb._tab_items().is_empty()
	hb.cat = keep
	return any

## A lot with no unlock entry (the Challenge and Ransom houses) that has not turned up on this farm yet is not offered.
static func not_yet_arrived(lot: String, built: bool) -> bool:
	return FarmUnlocks.gated() and FarmUnlocks.need_of(lot).is_empty() and not built

## What a lot costs in materials on a farm under the building pass ({} = its gem price in Data.BUILDINGS).
static func lot_cost(b: String) -> Dictionary:
	if not FarmUnlocks.gated():
		return {}
	return (FarmUnlocks.rules().get("lots", {}).get(b, {}) as Dictionary).duplicate()

## "Talk to Hob for more" in the menu's footer while anything is still locked.
static func add_footer(foot: Control) -> void:
	if not more_to_come():
		return
	var l := UI.label(String(rules()["hint_more"]), 13, UI.GOLD)
	foot.add_child(l)
