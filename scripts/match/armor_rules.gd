class_name ArmorRules
extends RefCounted
## The armor tiers from content/rules/armor.json (docs/ARMOUR_PARITY.md), as Hunter.ARMOR_TIERS rows:
## [name, colour, xp to reach, damage reduction (0..1), durability].

const RULES_PATH := "res://content/rules/armor.json"

static var _pitch_empty := -1.0  # "confirm" pitch_empty, read on the first armour hit


static func tiers() -> Array:
	var out: Array = []
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	for t in d["tiers"]:
		out.append([String(t["name"]), Color(String(t["col"])), float(t["xp"]), float(t["dr"]), float(t["dur"])])
	return out


## The pitch of the armour ring for a hit on `e`: 1 on a full shell, down to the rules' "confirm" pitch_empty as it
## runs out (the shell left after this hit), so the ring tells how close the break is.
static func confirm_pitch(e: Ent) -> float:
	if not e is Hunter or (e as Hunter).max_armor <= 0.0:
		return 1.0
	var left := clampf((e as Hunter).armor / (e as Hunter).max_armor, 0.0, 1.0)
	if _pitch_empty < 0.0:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_pitch_empty = float(d["confirm"]["pitch_empty"])
	return lerpf(_pitch_empty, 1.0, left)
