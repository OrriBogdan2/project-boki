class_name ZoneAffinity
extends RefCounted
## A Boki that suits the zone it lives in (garden_zones.json loves + affinity): each zone favours two
## types (the one its meals lean it to, Evo.lean) and one nature. A resident with either recovers joy
## faster and its toys now and then train one more point. One that does not suit its zone loses nothing.

## Does `rec` suit the zone it lives in? The data only: it holds wherever you are.
static func suits(rec: Dictionary) -> bool:
	var loved: Dictionary = GardenZones.info(GardenZones.zone_of(rec)).get("loves", {})
	return (loved.get("types", []) as Array).has(Evo.lean(rec)[0]) \
		or String(loved.get("nature", "")) == Care.nature(rec)

## Is it at work now: a resident of the zone you are in that suits it (base only, never in the hub).
static func active(rec: Dictionary) -> bool:
	return FarmUnlocks.base_mode() and GardenZones.here == GardenZones.zone_of(rec) and suits(rec)

## Joy it gains each minute, on top of the usual wear.
static func joy_per_min(rec: Dictionary) -> float:
	return float(GardenZones.rules()["affinity"]["joy_per_min"]) if active(rec) else 0.0

## Chance a toy gives one more stat point.
static func stat_bonus(rec: Dictionary) -> float:
	return float(GardenZones.rules()["affinity"]["stat_bonus"]) if active(rec) else 0.0

## The card's line for a Boki that suits its zone, or "".
static func line(rec: Dictionary) -> String:
	return "loves %s" % GardenZones.info(GardenZones.zone_of(rec))["name"] if suits(rec) else ""

## One line on the Care tab of a Boki's card (nothing when it does not suit its zone).
static func add_line(box: Container, rec: Dictionary) -> void:
	if FarmUnlocks.base_mode() and suits(rec):
		box.add_child(UI.para(line(rec), 12, UI.GOOD))
