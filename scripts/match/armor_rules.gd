class_name ArmorRules
extends RefCounted
## The armor tiers from content/rules/armor.json (docs/ARMOUR_PARITY.md), as Hunter.ARMOR_TIERS rows:
## [name, colour, xp to reach, damage reduction (0..1), durability].

const RULES_PATH := "res://content/rules/armor.json"

static func tiers() -> Array:
	var out: Array = []
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	for t in d["tiers"]:
		out.append([String(t["name"]), Color(String(t["col"])), float(t["xp"]), float(t["dr"]), float(t["dur"])])
	return out
