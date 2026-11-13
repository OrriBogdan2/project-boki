class_name ModeBoki
extends RefCounted
## Where each Boki is found, the owner's core principle 2 (docs/design/MODE_BOKI.md): content/rules/mode_boki.json
## lists the modes, each with a COMMON / RARE / VERY RARE spawn table and the difficulty each tier needs,
## plus Expedition's legendaries, a separate roll per match. Data only for now: no spawn reads it yet.

const TIERS := ["common", "rare", "very_rare"]
const LEGENDARY := "legendary"

static var _where := {}        # species -> [mode id, tier], built on first use

static func modes() -> Dictionary:
	return Content.rules("mode_boki")["modes"]

## The mode a species is found in, or "" when no mode lists it.
static func mode_of(species: String) -> String:
	return String(_index().get(species, ["", ""])[0])

## Its tier there: "common", "rare", "very_rare", "legendary", or "" when no mode lists it.
static func tier(species: String) -> String:
	return String(_index().get(species, ["", ""])[1])

static func _index() -> Dictionary:
	if not _where.is_empty():
		return _where
	for mode_id in modes():
		var mode: Dictionary = modes()[mode_id]
		for t in TIERS:
			for sp in mode["tiers"][t]["species"]:
				_where[sp] = [mode_id, t]
		for sp in mode.get("legendary", {}).get("species", []):
			_where[sp] = [mode_id, LEGENDARY]
	return _where
