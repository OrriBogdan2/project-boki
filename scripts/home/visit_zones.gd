class_name VisitZones
extends RefCounted
## Visiting a friend whose garden has a hub and zones (briefs/design/GARDEN.md 10.7 step 10,
## docs/decisions/0022-garden-zones.md). The profile doc carries "hub_layout" and "zones"
## ({zone id: layout} for each open zone that has a layout of its own), and each Boki its "zone". The
## visitor lands in the friend's hub and hops through the same Waystone (HubWaystone). A doc without them
## (an older one, or from a farm without the garden) is the single island it always was. Layouts in a doc
## are untrusted: clean_layout keeps only what the island needs, and few of it.

const DECO_MAX := 160     # fixtures kept from one layout
const TILE_MAX := 100     # tiles: past the home map (HomeLayout.W)

## What your profile doc adds: the hub's layout and each open zone's. {} without the garden.
static func doc() -> Dictionary:
	if not FarmUnlocks.base_mode():
		return {}
	var zones := {}
	for id in GardenZones.ids():
		var L = Save.d.get("layout") if id == GardenZones.start() else Save.d.get("zones", {}).get(id, {}).get("layout")
		if GardenZones.is_open(id) and typeof(L) == TYPE_DICTIONARY:
			zones[id] = clean_layout(L)
	return {"hub_layout": clean_layout(Save.d.get("hub_layout", HubLayout.template())), "zones": zones}

## The snapshot keys a doc's hub and zones become ({} for an older doc).
static func clean(d: Dictionary) -> Dictionary:
	var src := Social.dict_of(d.get("zones"))
	var hub := clean_layout(d.get("hub_layout"))
	var zones := {}
	for id in GardenZones.ids():
		var L := clean_layout(src.get(id))
		if not L.is_empty():
			zones[id] = L
	return {} if hub.is_empty() or not zones.has(GardenZones.start()) else {"hub_layout": hub, "zones": zones}

## A layout with the island's shape, its buildings' lots and its fixtures; the rest HomeLayout.ensure fills in.
static func clean_layout(src) -> Dictionary:
	var L := Social.dict_of(src)
	if L.is_empty():
		return {}
	var deco: Array = []
	for ev in Social.arr_of(L.get("deco")):
		var e := Social.dict_of(ev)
		var id := Social.txt_of(e.get("id"))
		if HomeLayout.CATALOG.has(id) and deco.size() < DECO_MAX:
			deco.append({"u": deco.size() + 1, "id": id, "x": _tile(e.get("x")), "z": _tile(e.get("z")),
				"r": Social.int_of(e.get("r")) % 4})
	var lots := {}
	for b in Data.BUILDINGS:
		var p := Social.dict_of(Social.dict_of(L.get("b")).get(b))
		if not p.is_empty():
			lots[b] = {"x": _tile(p.get("x")), "z": _tile(p.get("z")), "r": Social.int_of(p.get("r")) % 4}
	var theme := Social.txt_of(L.get("theme"))
	return {"v": 1, "grow": clampi(Social.int_of(L.get("grow")), 0, HomeLayout.EXPAND.size()),
		"theme": theme if HomeLayout.THEMES.has(theme) else "meadow",
		"seed": clampi(Social.int_of(L.get("seed")), 0, 2147483646),
		"fs": clampi(Social.int_of(L.get("fs")), 0, 1), "sk": clampf(Social.num_of(L.get("sk"), 1.0), 0.3, 2.0),
		"uid": deco.size(), "deco": deco, "b": lots}

static func _tile(v) -> int:
	return clampi(Social.int_of(v), 0, TILE_MAX)

## Is this snapshot a friend's garden with a hub?
static func has(snap: Dictionary) -> bool:
	return snap.has("zones") and snap.has("hub_layout")

## Is zone `id` one the visited garden has open (with a layout)?
static func is_open(snap: Dictionary, id: String) -> bool:
	return (snap["zones"] as Dictionary).has(id)

## The snapshot Home shows for the hub or zone `id` of a visited garden. "all" is the whole thing, to hop with.
static func view(snap: Dictionary, id: String) -> Dictionary:
	var all: Dictionary = snap.get("all", snap)
	var z := id if id != "" else GardenZones.start()
	if z != GardenZones.HUB and not is_open(all, z):
		z = GardenZones.start()
	var v := all.duplicate()
	v["all"] = all
	v["layout"] = all["hub_layout"] if z == GardenZones.HUB else all["zones"][z]
	v["roster"] = [] if z == GardenZones.HUB else all["roster"].filter(func(r): return r.get("zone") == z)
	if z != GardenZones.start():       # the old island's own things (lots, bridges, crops) belong to the start zone
		for k in ["plots", "gh_plots", "buildings", "bridges"]:
			v[k] = []
	return v

## The visitor's Waystone: the hub and the friend's open zones, except where you are.
static func pick(h) -> void:
	var v: VBoxContainer = h._new_panel("%s's Waystone" % String(h.visit.get("name", "The")), 420.0)
	v.add_child(UI.label("Where to?", 14, UI.MUTED))
	if h.hway.here() != GardenZones.HUB:
		v.add_child(UI.button("The hub", func(): h.hway.hop(GardenZones.HUB), 360))
	for id in GardenZones.ids():
		if is_open(h.visit, id) and id != h.hway.here():
			v.add_child(UI.button(String(GardenZones.info(id)["name"]), func(): h.hway.hop(id), 360))
