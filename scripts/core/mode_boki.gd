class_name ModeBoki
extends RefCounted
## Where each Boki is found, the owner's core principle 2 (docs/design/MODE_BOKI.md): content/rules/mode_boki.json
## lists the modes, each with a COMMON / RARE / VERY RARE spawn table and the difficulty each tier needs,
## plus Expedition's legendaries, a separate roll per match. The spawn pools read it only while the file's
## "live" flag is on (default off: the pools keep drawing Data.common_kin).

const TIERS := ["common", "rare", "very_rare"]
const LEGENDARY := "legendary"

static var _where := {}        # species -> [mode id, tier], built on first use

static func modes() -> Dictionary:
	return Content.rules("mode_boki")["modes"]

## `pool` (the species a spawn site draws from) cut down to `mode_id`'s species whose tier is open at `level`
## (the difficulty gate_doc counts). With the "live" flag off, `pool` comes back as it was.
static func offer(pool: Array, mode_id: String, level: int) -> Array:
	if not bool(Content.rules("mode_boki").get("live", false)):
		return pool
	var tiers: Dictionary = modes()[mode_id]["tiers"]
	return pool.filter(func(sp): return mode_of(sp) == mode_id and level >= int(tiers[tier(sp)]["gate"]))

## One species of that offer, drawn with `r`.
static func draw(pool: Array, mode_id: String, level: int, r: RandomNumberGenerator) -> String:
	var fits := offer(pool, mode_id, level)
	return String(fits[r.randi_range(0, fits.size() - 1)])

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
