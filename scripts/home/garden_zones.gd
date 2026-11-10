class_name GardenZones
extends RefCounted
## The garden's zones (briefs/design/GARDEN.md 10, docs/decisions/0022-garden-zones.md): which are
## open, who lives where and the two keys a locked one needs. Data: content/rules/garden_zones.json.
## On the save: Save.d["zones"] = {id: {"open": bool}} and rec["zone"] (missing = the start zone).
## "hub" is not a zone: it is the island with the Waystone (HubLayout) and nobody lives there.
## Only the zone you are in is loaded: its residents and your partner walk it. Each zone holds up to
## KinBox.farm_cap() Boki out; the rest sleep in the shared Burrow. Boki never change zone on their
## own: you move them (move(), through HubWaystone.send) or answer when one asks (wants()).

const HUB := "hub"

static var here := ""      # the zone the open Home shows (home.gd sets it; "" before one loads)

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

## The zone a Boki woken from the Burrow lives in: the one you are in (from the hub: the start zone).
static func current() -> String:
	return here if here != "" and here != HUB else start()

static func is_partner(rec: Dictionary) -> bool:
	return String(rec.get("uid", "")) == str(Save.d.get("active", ""))

## Who walks the zone you are in: its residents, and your partner wherever it lives.
static func out_here() -> Array:
	var z := current()
	return KinBox.farm().filter(func(r): return zone_of(r) == z or is_partner(r))

## How many more Boki can be out in a zone.
static func room(id: String) -> int:
	return KinBox.farm_cap() - residents(id).size()

## Why `rec` can't move to zone `id` now, or "".
static func why_not(rec: Dictionary, id: String) -> String:
	var nm := String(rec.get("name", "It"))
	if is_partner(rec):
		return "%s is your partner: it comes with you to every zone" % nm
	if KinBox.is_boxed(rec):
		return "%s is asleep in the Burrow" % nm
	if zone_of(rec) == id:
		return "%s already lives here" % nm
	if not is_open(id):
		return "%s is still asleep" % info(id).get("name", id)
	if room(id) <= 0:
		return "%s is full (%d out)" % [info(id)["name"], KinBox.farm_cap()]
	return ""

## Moves `rec` to zone `id`. Returns "" or why not.
static func move(rec: Dictionary, id: String) -> String:
	var why := why_not(rec, id)
	if why == "":
		rec["zone"] = id
	return why

## The open zone `rec` would thrive in and could move to (its strongest lean is one of its types), or "".
static func wants(rec: Dictionary) -> String:
	var best: String = Evo.lean(rec)[0]
	if best == "" or info(zone_of(rec)).get("types", []).has(best):
		return ""
	for id in ids():
		if info(id)["types"].has(best) and why_not(rec, id) == "":
			return id
	return ""

## The bag item that is a zone's first key (Loot.VALUABLES names it on a run, Econ banks it as an item).
static func wayseed(id: String) -> String:
	return "wayseed_" + id

## The still-locked zone whose Wayseed a lair in this biome holds, or "" (base mode only).
static func seed_zone_for(biome: String) -> String:
	if not FarmUnlocks.base_mode():
		return ""
	for id in ids():
		if not is_open(id) and info(id).get("lair_biomes", []).has(biome):
			return id
	return ""

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

## Both keys in hand: plants the Wayseed and wakes the zone. The Boki that leans toward it becomes its
## founder: it moves in, remembers the day and writes it in its journal. {"ok", "why", "founder"}.
static func attune(id: String) -> Dictionary:
	var keys := keys_for(id)
	if is_open(id) or not (keys["seed"] and keys["lean"]):
		return {"ok": false, "why": "%s needs both keys" % info(id).get("name", id)}
	var rec := leaner(id)
	var nm: String = info(id)["name"]
	Save.add_item(wayseed(id), -1)
	Save.d["zones"][id] = {"open": true, "founder": rec["uid"]}
	rec["zone"] = id
	Save.remember(rec, "zone", "the day I woke " + nm)
	CareJournal.note(rec, "woke " + nm)
	return {"ok": true, "why": "", "founder": rec}

## The Boki that woke the zone, or {} (the start zone, or one that has left).
static func founder(id: String) -> Dictionary:
	return Save.kin(String(Save.d.get("zones", {}).get(id, {}).get("founder", "")))
