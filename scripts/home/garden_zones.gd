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
const LEDGE_R := 2          # tiles each way round the Stump Shove stump kept free of wild

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

## The loaded zone's own layout. The start zone keeps Save.d["layout"]; any other zone keeps its own in
## Save.d["zones"][id]["layout"], made from its garden_zones.json entry the first time it is read (so an
## older save needs no migration). {} for the start zone, the hub, a visit and anything but the save.
static func layout(d: Dictionary) -> Dictionary:
	if here == "" or here == HUB or here == start() or not is_same(d, Save.d) or not info(here).has("layout"):
		return {}
	var z: Dictionary = d["zones"].get(here, {})
	if z.is_empty():
		return {}
	if not z.has("layout"):
		z["layout"] = _made(info(here))
	return z["layout"]

static func _made(def: Dictionary) -> Dictionary:
	var spec: Dictionary = def["layout"]
	var L := HomeLayout.fresh()
	L["theme"] = def["theme"]
	L["themes"] = [def["theme"]]
	L["seed"] = int(spec["seed"])
	L["fs"] = 1
	L["fb"] = 1
	L["sk"] = float(spec["sk"])
	for s in spec["deco"]:
		var e := {"u": HomeLayout._next_uid(L), "id": String(s[0]), "x": int(s[1]), "z": int(s[2]), "r": 0}
		(L["deco"] as Array).append(e)
	return L

## The tiles round the Stump Shove stump of the zone you are in (kept free of wild).
static func ledge_tiles(w: World) -> Array[int]:
	var out: Array[int] = []
	var at: Array = info(current()).get("shove_at", [])
	for dz in range(-LEDGE_R, LEDGE_R + 1):
		for dx in range(-LEDGE_R, LEDGE_R + 1):
			if not at.is_empty() and w.inb(int(at[0]) + dx, int(at[1]) + dz):
				out.append(w.idx(int(at[0]) + dx, int(at[1]) + dz))
	return out

## What the snack patch grows in the zone you are in.
static func snacks() -> Array:
	return info(current()).get("snacks", SnackPatch.rules()["snacks"])

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
