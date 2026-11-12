class_name PickupSfx
extends RefCounted
## The pickup sound for what you pick up, by item category (content/rules/pickup_sfx.json): armour
## clink, weapon heft, gem chime, consumable pop, or the generic one. The category comes from the item's
## data (gear slot, treasure, belt item), never from its name.

const RULES := "res://content/rules/pickup_sfx.json"

static var _r: Dictionary = {}

static func _rules() -> Dictionary:
	if _r.is_empty():
		_r = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	return _r

## The sound for category `cat` ("generic" if the rules do not know it).
static func cue(cat: String) -> String:
	var cues: Dictionary = _rules()["cues"]
	return String(cues.get(cat, cues["generic"]))

## The sound for a piece of gear, by the slot its data gives it.
static func of_gear(id: String) -> String:
	return cue(String((_rules()["gear_kind"] as Array)[Gear.slot_of(id)]))

## The sound for a carried item ({t: "gear" | "val", id, ...}).
static func of(it: Dictionary) -> String:
	if String(it.get("t", "")) == "val":
		return cue(String(_rules()["valuable"]))
	return of_gear(String(it.get("id", "")))

## The sound for a ground pickup of Match._collect (a belt item, a gem, a seed, a key).
static func of_kind(kind: String) -> String:
	if UtilityBelt.is_item(kind):
		return cue(String(_rules()["belt"]))
	return cue(String((_rules()["kinds"] as Dictionary).get(kind, "generic")))
