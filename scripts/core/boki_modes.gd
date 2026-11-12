class_name BokiModes
extends RefCounted
## Where each Boki is found (docs/design/SERIES_BOKI_MODES.md): every Boki line lives in exactly one
## mode, with a rarity (common, rare, very_rare) and the lowest difficulty of that mode it turns up
## at, all from content/rules/boki_modes.json. Spawn code asks for a mode's pool and draws from it by
## rarity tickets; where and when a spawn happens stays with the caller (fixed spots, fixed timers).

const PATH := "res://content/rules/boki_modes.json"

static var _rules := {}
static var _by_kin := {}         # game species id -> its line's entry

## The whole rules file (read once).
static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		for line in _rules["lines"]:
			var entry: Dictionary = _rules["lines"][line]
			if entry.has("kin"):
				_by_kin[String(entry["kin"])] = entry
	return _rules

## A game species' {mode, rarity, min_difficulty}; empty if the file doesn't list it.
static func of(species: String) -> Dictionary:
	rules()
	return _by_kin.get(species, {})

## How many draw tickets a species gets, from its rarity.
static func tickets(species: String) -> int:
	return int(rules()["tickets"].get(String(of(species).get("rarity", "")), 0))

## The game species of a mode with one of these rarities, met at this difficulty or easier ("" for
## any), in Data.KIN order. Boss-egg kin (Data.is_rare) never spawn: they only hatch from their egg.
static func pool(mode: String, rarities: Array, difficulty := "") -> Array:
	var ladder: Array = rules()["modes"][mode]["difficulties"]
	var top := ladder.size() - 1 if difficulty == "" else ladder.find(difficulty)
	return Data.KIN.keys().filter(func(sp): return _spawns(sp, mode, rarities, ladder, top))

## The pool of one spawn site of a mode (modes.<mode>.sites.<site> lists its rarities).
static func site_pool(mode: String, site: String) -> Array:
	return pool(mode, rules()["modes"][mode]["sites"][site])

## One species from the pool, weighted by rarity tickets (one rng draw); "" if the pool is empty.
static func draw(species_pool: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for sp in species_pool:
		total += tickets(sp)
	var ticket := rng.randi_range(1, maxi(1, total))
	for sp in species_pool:
		ticket -= tickets(sp)
		if ticket <= 0:
			return sp
	return ""

static func _spawns(species: String, mode: String, rarities: Array, ladder: Array, top: int) -> bool:
	var entry := of(species)
	if entry.get("mode") != mode or not String(entry.get("rarity")) in rarities:
		return false
	return ladder.find(String(entry.get("min_difficulty"))) <= top and not Data.is_rare(species)
