class_name HubLayout
extends RefCounted
## The garden's hub (briefs/design/GARDEN.md 10.1, docs/decisions/0022-garden-zones.md): a small fixed
## island you arrive on. The Waystone stands in the middle (HubWaystone), the house north, the expedition
## portal and glider rack south (Home's fixed heart), the nest corner west (Nesting Nook, Incubator,
## Soul Shrine), the market stall and the games board east, the Burrow door south-west. No toys, no games
## and no residents: only your partner comes along, and an egg-minder while an egg waits (minder()). It is
## shown through Home's visit path: island() is the snapshot Home reads instead of your save. The fixtures
## are a fixed template (below) that you can't pick up; build mode there offers only the Garden tab.
## The layout is kept on the save as Save.d["hub_layout"] (absent in older saves: the template is built on first use).

const SEED := 7310        # the hub's island shape: the same for everyone
const SCALE := 0.55       # fs_shape scale: the smallest farm-start island, about 20 m across
const BOARD_AT := Vector3(46.0, 0, 36.5)   # the games board, east of the stall
const WALL_OFF := Vector3(0, 0, -2.4)      # m from the board to the Dash's showcase wall beside it
## [catalog id, tile x, tile z, turns]: the fixtures, with the tiles they stand on (south is turn 0).
const DECO := [["house", 36, 28, 0], ["nesting_nook", 26, 30, 0], ["market_stall", 43, 32, 0],
	["boki_burrow", 32, 35, 0]]
## The catalog ids only the hub has with the garden on (the Incubator stands with the Nook): no zone builds them.
const OWN := ["house", "nesting_nook", "market_stall", "boki_burrow"]
const SHRINE := {"x": 31, "z": 30, "r": 0}        # the Soul Shrine's lot: you build it there
## Tile rects [x0, z0, x1, z1] kept free of wild trees and rocks: round the Waystone, the board and its wall.
const CLEAR := [[36, 31, 41, 36], [45, 33, 47, 37]]

## The snapshot Home shows for the hub (the keys a visited island has, see Social.clean_island).
static func island() -> Dictionary:
	if typeof(Save.d.get("hub_layout")) != TYPE_DICTIONARY:
		Save.d["hub_layout"] = template()
	var d := {"layout": Save.d["hub_layout"]}
	HomeLayout.ensure(d)       # whole numbers after a reload
	(d["layout"]["inv"] as Dictionary).erase(SnackPatch.ID)      # (ensure grants the garden's snack patch)
	var walkers: Array = [Save.active_kin(), minder()].filter(func(r): return not r.is_empty())
	return {"hub": true, "name": "", "layout": d["layout"], "plots": [], "roster": walkers,
		"active": String(Save.d.get("active", ""))}

## The egg-minder (GARDEN.md 10.1): while an egg in the Nook still waits to be minded, the first Boki out
## with the Ember knack (BaseChore "mind") comes over from its zone to do it. It stays a resident there.
static func minder() -> Dictionary:
	var egg: Dictionary = Save.d.get("egg", {})
	if egg.is_empty() or egg.get("rare", false) or egg.get("minded", false) \
			or Time.get_unix_time_from_system() >= float(egg.get("t", 0.0)) \
			or int(Save.d.get("matches", 0)) >= int(egg.get("m", 0)):
		return {}
	for rec in KinBox.farm():
		if not GardenZones.is_partner(rec) and Work.of(rec).has("ember"):
			return rec
	return {}

static func template() -> Dictionary:
	var L := HomeLayout.fresh()
	L["seed"] = SEED
	L["fs"] = 1
	L["sk"] = SCALE
	for f in DECO:
		L["uid"] = int(L["uid"]) + 1
		(L["deco"] as Array).append({"u": L["uid"], "id": f[0], "x": f[1], "z": f[2], "r": f[3]})
	L["b"]["shrine"] = SHRINE.duplicate()
	return L

<<<<<<< HEAD
## Does the hub hold catalog piece `id` instead of layout `L`? With the garden on, the hub's house, Nook (with
## its Incubator), stall and Burrow are the only ones: the save's own layout (the start zone's) builds none of
## them. An older layout may still list some; they stay on the save for the farm with the garden off.
static func holds(L: Dictionary, id: String) -> bool:
	return FarmUnlocks.base_mode() and is_same(L, Save.d.get("layout")) and DECO.any(func(f): return f[0] == id)

||||||| 449fcaf48f
=======
## The save migration for the hub owning those (docs/decisions/0078-hub-owns-fixtures.md): with the garden on, the
## start zone's own house, Nook, stall and Burrow go to its storage (base_mode off sets them down again) and a
## higher tier carries over to the hub's; one still going up is taken down and pays back. The egg, the nest
## items and the Incubator are the save's (Save.d egg, nest_set, incubator): they follow the one Nook as they are.
static func claim(d: Dictionary) -> void:
	if not FarmUnlocks.base_mode() or not is_same(d, Save.d) or typeof(d.get("layout")) != TYPE_DICTIONARY:
		return
	var L: Dictionary = d["layout"]
	var mine: Array = (L["deco"] as Array).filter(func(e): return OWN.has(String(e["id"])))
	if mine.is_empty():
		return
	if typeof(d.get("hub_layout")) != TYPE_DICTIONARY:
		d["hub_layout"] = template()
	for e in mine:
		var id := String(e["id"])
		var built := not FarmSites.is_site(e)
		FarmSites.cancel(e)
		if built:
			L["inv"][id] = int(L["inv"].get(id, 0)) + 1
			for hub_e in d["hub_layout"]["deco"]:
				if String(hub_e["id"]) == id:
					hub_e["t"] = maxi(FarmSites.tier(hub_e), FarmSites.tier(e))
		(L["deco"] as Array).erase(e)

## Does Home `h` stand on an island that leaves those to the hub (the garden on, your own zone, not the hub)?
static func vacant(h) -> bool:
	return FarmUnlocks.base_mode() and h.visit.is_empty()

>>>>>>> origin/ext/farm-incubator-verify
static func is_hub(d: Dictionary) -> bool:
	return bool(d.get("hub", false))
