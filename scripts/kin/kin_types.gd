class_name KinTypes
extends RefCounted
## The 18 Boki types (the owner's table, briefs/boki-art/GAME_RULES_NOV8.md): a species has one type and
## optionally a second (kin_v2 "theme", "theme2"). Identity only, no chart. ALIASES maps the ids that
## saves, content files and peers may still send onto these.

## id -> display name and badge colour, in the order the Field Book lists them.
const TYPES := {
	"normal": {"name": "Normal", "col": Color("a9b0bf")},
	"fire": {"name": "Fire", "col": Color("ff7a3a")},
	"water": {"name": "Water", "col": Color("4ab0ff")},
	"grass": {"name": "Grass", "col": Color("6fd86a")},
	"spore": {"name": "Spore", "col": Color("9ccf6a")},
	"electric": {"name": "Electric", "col": Color("ffd84a")},
	"ice": {"name": "Ice", "col": Color("a6eeff")},
	"rock": {"name": "Rock", "col": Color("9c8266")},
	"psychic": {"name": "Psychic", "col": Color("8f8cff")},
	"flying": {"name": "Flying", "col": Color("6fe0cf")},
	"dragon": {"name": "Dragon", "col": Color("4a72d8")},
	"dark": {"name": "Dark", "col": Color("6a5a8a")},
	"poison": {"name": "Poison", "col": Color("b98cff")},
	"bug": {"name": "Bug", "col": Color("f2c24a")},
	"steel": {"name": "Steel", "col": Color("cbb48a")},
	"fairy": {"name": "Fairy", "col": Color("cfdcff")},
	"crystal": {"name": "Crystal", "col": Color("ff9fd0")},
	"sound": {"name": "Sound", "col": Color("6fb6ff")},
}

## The ids used before the rename -> the standard id.
const ALIASES := {
	"ember": "fire", "tide": "water", "bloom": "grass", "storm": "electric", "frost": "ice", "stone": "rock",
	"gravity": "psychic", "tempest": "flying", "wyrm": "dragon", "shadow": "dark", "venom": "poison",
	"swarm": "bug", "titan": "steel", "lunar": "fairy", "prism": "crystal", "echo": "sound", "wild": "normal",
}

## An id as the game spells it now: old ids map over, anything else is lower-cased and left as it is.
static func canon(id: String) -> String:
	var low := id.strip_edges().to_lower()
	return String(ALIASES.get(low, low))

static func name_of(id: String) -> String:
	var t := canon(id)
	return String(TYPES[t]["name"]) if TYPES.has(t) else t.capitalize()

static func col_of(id: String) -> Color:
	return TYPES.get(canon(id), {}).get("col", Color("a9b0bf"))

## A species' types, first one first (one or two). Empty for an unknown species.
static func of_species(sp: Dictionary) -> Array:
	var out: Array = []
	for key in ["type", "type2"]:
		var t := canon(String(sp.get(key, "")))
		if t != "" and t != "none":
			out.append(t)
	return out

## "Fire" or "Fire / Flying", for cards and the Field Book.
static func label(sp: Dictionary) -> String:
	var names: Array = []
	for t in of_species(sp):
		names.append(name_of(t))
	return " / ".join(names)
