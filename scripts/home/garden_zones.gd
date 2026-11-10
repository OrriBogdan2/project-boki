class_name GardenZones
extends RefCounted
## The garden's zones (briefs/design/GARDEN.md 10, docs/decisions/0022-garden-zones.md): which are
## open, who lives where and the two keys a locked one needs. Data: content/rules/garden_zones.json.
## On the save: Save.d["zones"] = {id: {"open": bool}} and rec["zone"] (missing = the start zone).
## "hub" is not a zone: it is the island with the Waystone (HubLayout) and nobody lives there.

const HUB := "hub"

static func rules() -> Dictionary:
	return Content.rules("garden_zones")

static func ids() -> Array:
	return (rules()["zones"] as Dictionary).keys()

static func info(id: String) -> Dictionary:
	return rules()["zones"].get(id, {})

static func start() -> String:
	return String(rules()["start"])

## A new save's zones: the start zone open, the rest locked.
static func fresh() -> Dictionary:
	return {start(): {"open": true}}

## An older save: the start zone open and every Boki living in it.
static func migrate(data: Dictionary) -> void:
	if typeof(data.get("zones")) != TYPE_DICTIONARY:
		data["zones"] = fresh()
	for rec in data.get("roster", []):
		if not rec.has("zone"):
			rec["zone"] = start()

static func zone_of(rec: Dictionary) -> String:
	return String(rec.get("zone", start()))

static func is_open(id: String) -> bool:
	return bool(Save.d.get("zones", fresh()).get(id, {}).get("open", false))

## The Boki out (not in the Burrow) whose home is this zone.
static func residents(id: String) -> Array:
	return KinBox.farm().filter(func(r): return zone_of(r) == id)

## The bag item that is a zone's first key (GARDEN.md 10.3; the item itself comes with the unlock step).
static func wayseed(id: String) -> String:
	return "wayseed_" + id

## A Boki out on the base that leans far enough toward the zone to wake it (the second key), or {}.
static func leaner(id: String) -> Dictionary:
	var need := float(rules()["lean_key"])
	for rec in KinBox.farm():
		for t in info(id).get("types", []):
			if float(rec.get("lean", {}).get(t, 0.0)) >= need:
				return rec
	return {}

## The two keys of a locked zone: {"seed": have the Wayseed, "lean": have a Boki leaning toward it}.
static func keys_for(id: String) -> Dictionary:
	return {"seed": int(Save.d.get("items", {}).get(wayseed(id), 0)) > 0, "lean": not leaner(id).is_empty()}
