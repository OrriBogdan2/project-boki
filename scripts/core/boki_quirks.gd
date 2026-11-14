class_name BokiQuirks
extends RefCounted
## Small true-to-life details about each kind of Boki (content/rules/boki_quirks.json, from the
## Bokidex): a quirk and a note on its sexes, shown on its Field Book page, and a few that are real
## behaviour: the female share at hatch, how fast it gets hungry, how rain sits with it, and
## whether it senses rain coming. A species with no entry behaves like any other Boki.

const PATH := "res://content/rules/boki_quirks.json"
const RARE_SCALE := 10000      # a rare trait's chance is drawn in 1/10000ths
const EVEN_SHARE := 0.5      # female share for a species with no sex note: half and half

static var _data := {}

## The whole data file (read once).
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data

## The Bokidex id for a species: its display name in lower case (Rampartoad -> "rampartoad").
static func key(species: String) -> String:
	return String(Data.KIN.get(species, {}).get("name", species)).to_lower()

static func _value(section: String, species: String, fallback: Variant) -> Variant:
	return (data().get(section, {}) as Dictionary).get(key(species), fallback)

## Its quirk, one sentence ("" if it has none).
static func quirk(species: String) -> String:
	return String(_value("quirk", species, ""))

## How its sexes work ("" for the usual half and half).
static func sex_note(species: String) -> String:
	return String(_value("sexNote", species, ""))

## Share of its hatchlings that are female (0..1).
static func female_share(species: String) -> float:
	return float(_value("female_share", species, EVEN_SHARE))

## Its sex at hatch, from the egg's seed: the usual coin flip (Unique.sex_for_seed) unless its
## kind leans one way, then a draw against its female share. Same seed, same answer.
static func sex_for(species: String, seed: int) -> String:
	var share := female_share(species)
	if share == EVEN_SHARE:
		return Unique.sex_for_seed(seed)
	return "f" if posmod(hash("%d|sex" % seed), 1000) < int(share * 1000.0) else "m"

## Writes a new Boki's sex into its rolls (Save.new_kin, and Care.breed after it inherits).
static func set_sex(rec: Dictionary) -> void:
	rec["dna"]["sex"] = sex_for(String(rec["species"]), int(rec["dna"]["seed"]))

## The rare trait a species can hatch with (content/rules/boki_quirks.json "rare_trait"): {} if none.
static func rare_def(species: String) -> Dictionary:
	return _value("rare_trait", species, {})

## Its rare trait at hatch, from the egg's seed: "" or the trait id. Same seed, same answer.
static func rare_trait_for(species: String, seed: int) -> String:
	var def := rare_def(species)
	if def.is_empty():
		return ""
	var odds := roundi(float(def["chance"]) * RARE_SCALE)
	return String(def["id"]) if posmod(hash("%d|rare" % seed), RARE_SCALE) < odds else ""

## Rolls a new Boki's rare trait into rec["rare"] ("" for none); nothing for a species with no trait.
static func set_rare_trait(rec: Dictionary) -> void:
	var seed: Variant = Unique.of(rec).get("seed", null)
	if seed != null and not rare_def(String(rec["species"])).is_empty():
		rec["rare"] = rare_trait_for(String(rec["species"]), int(seed))

## Does this Boki carry that rare trait? (Evo's 'trait' branches ask.)
static func has_trait(rec: Dictionary, id: String) -> bool:
	return String(rec.get("rare", "")) == id

## The rare trait this Boki carries, as {id, name, note} (the card's badge); {} if none.
static func rare_of(rec: Dictionary) -> Dictionary:
	var id := String(rec.get("rare", ""))
	if id == "":
		return {}
	for def in (data().get("rare_trait", {}) as Dictionary).values():
		if def is Dictionary and def["id"] == id:
			return def
	return {}

## An older save's Boki of a species with a rare trait roll for it once on load (kept in the save after).
static func migrate(save_data: Dictionary) -> void:
	for rec in save_data.get("roster", []):
		if typeof(rec) == TYPE_DICTIONARY and not rec.has("rare"):
			set_rare_trait(rec)

## How much faster than usual its food need drains.
static func food_rate(species: String) -> float:
	return float(_value("food_rate", species, 1.0))

## Joy it gains (or loses, if negative) per minute out in the rain.
static func rain_joy(species: String) -> float:
	return float(_value("rain_joy", species, 0.0))

## How many seconds ahead it senses rain (0: it doesn't).
static func storm_sense_s(species: String) -> float:
	return float(_value("storm_sense", species, 0.0))
