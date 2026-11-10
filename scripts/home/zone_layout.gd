class_name ZoneLayout
extends RefCounted
## A built garden zone's island (briefs/design/GARDEN.md 10.7 step 7, docs/decisions/0022-garden-zones.md).
## A zone with a "build" in content/rules/garden_zones.json is laid out from that data every time you
## arrive: its theme, its island seed, the toys and the snack patch it has. While its Home is open the
## layout stands in for Save.d["layout"] (HomeLayout.of answers with `live`), so every system that reads
## the layout sees the zone. Nothing of it is saved except the snack patch's ripening timer, which lives
## in Save.d["zones"][id]["patch"]. Build mode is off there (HomeBuild.can_build): the zone is as it is.

static var live := {}          # the open Home's zone layout, or {} (Bramblebank, the hub, any other scene)

## Called when a Home opens in zone `id` ("" the start zone, "hub" the hub): sets or clears `live`.
static func enter(id: String) -> void:
	live = layout(id) if built(id) else {}

static func leave() -> void:
	live = {}

static func built(id: String) -> bool:
	return GardenZones.info(id).has("build")

## The zone's layout, a plain HomeLayout dictionary.
static func layout(id: String) -> Dictionary:
	var B: Dictionary = GardenZones.info(id)["build"]
	var L := HomeLayout.fresh()
	L["theme"] = String(B["theme"])
	L["themes"] = [String(B["theme"])]
	L["seed"] = int(B["seed"])
	L["sk"] = float(B["sk"])
	L["fs"] = 1
	for d in B["deco"]:
		var e := {"id": String(d[0]), "x": int(d[1]), "z": int(d[2]), "r": int(d[3])}
		if String(d[0]) == SnackPatch.ID:
			e = _kept_patch(id, e)
		e["u"] = HomeLayout._next_uid(L)
		(L["deco"] as Array).append(e)
	var c: Array = B["clear"]
	for z in range(int(c[1]), int(c[3]) + 1):
		for x in range(int(c[0]), int(c[2]) + 1):
			L["cleared"][HomeLayout.key(x, z)] = 1
	return L

## The snack patch's entry is the one kept on the save, so its timer survives leaving the zone.
static func _kept_patch(id: String, e: Dictionary) -> Dictionary:
	var zones: Dictionary = Save.d["zones"]
	if not zones.has(id):
		zones[id] = {"open": false}
	var kept: Dictionary = zones[id].get("patch", {})
	kept.merge(e, true)
	zones[id]["patch"] = kept
	return kept
