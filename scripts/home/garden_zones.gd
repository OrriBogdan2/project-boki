class_name GardenZones
## Where each Boki lives (briefs/design/GARDEN.md 10.4). A Boki's zone is rec["zone"] (missing means Bramblebank,
## so old saves need no migration); a zone is open when Save.d["zones"] has its id (Bramblebank always is). Only
## the zone loaded (`here`) is simulated: home.gd spawns its residents and your partner, who follows you.
## Each zone holds as many Boki as the farm cap (KinBox.farm_cap); the rest wait in the shared Boki Burrow.
## Boki never change zone by themselves: you move them (ZoneMove, ZonePad) or answer their ask.

const DEFAULT := "bramblebank"

static var here := DEFAULT      # the zone this screen shows

static func rules() -> Dictionary:
	return Content.rules("garden_zones")

static func zone_of(rec: Dictionary) -> String:
	var z := String(rec.get("zone", DEFAULT))
	return z if (rules()["zones"] as Dictionary).has(z) else DEFAULT

static func zone_name(id: String) -> String:
	return String(rules()["zones"][id]["name"])

static func is_open(id: String) -> bool:
	return id == DEFAULT or (Save.d.get("zones", {}) as Dictionary).has(id)

static func open_ids() -> Array:
	return (rules()["zones"] as Dictionary).keys().filter(is_open)

static func is_partner(rec: Dictionary) -> bool:
	return String(rec.get("uid", "")) == str(Save.d.get("active", ""))

## The Boki out in a zone (the ones asleep in the Burrow belong to none).
static func out_in(id: String) -> Array:
	return KinBox.farm().filter(func(r): return zone_of(r) == id)

static func room(id: String) -> int:
	return KinBox.farm_cap() - out_in(id).size()

## Who walks the loaded zone: its residents, and your partner wherever you are.
static func out_here() -> Array:
	return KinBox.farm().filter(func(r): return is_partner(r) or zone_of(r) == here)

## Why `rec` can't go to `id` right now, or "".
static func why_not(rec: Dictionary, id: String) -> String:
	var nm := String(rec.get("name", "It"))
	if not (rules()["zones"] as Dictionary).has(id): return "There is no such place"
	if is_partner(rec): return "%s is your partner: it follows you to every zone" % nm
	if KinBox.is_boxed(rec): return "%s is asleep in the Boki Burrow" % nm
	if zone_of(rec) == id: return "%s already lives in %s" % [nm, zone_name(id)]
	if not is_open(id): return "%s is not open yet" % zone_name(id)
	if room(id) <= 0: return "%s is full (%d out)" % [zone_name(id), KinBox.farm_cap()]
	return ""

## Moves `rec` to zone `id`. Returns "" or why not.
static func move(rec: Dictionary, id: String) -> String:
	var why := why_not(rec, id)
	if why == "": rec["zone"] = id
	return why

## The open zone `rec` would thrive in but doesn't live in (it leans to one of its types), or "".
static func wants(rec: Dictionary) -> String:
	var lean := Evo.lean(rec)
	if float(lean[1]) < float(rules()["ask_lean"]): return ""
	var zones: Dictionary = rules()["zones"]
	if (zones[zone_of(rec)]["types"] as Array).has(lean[0]): return ""
	for id in open_ids():
		if (zones[id]["types"] as Array).has(lean[0]) and why_not(rec, id) == "": return id
	return ""
