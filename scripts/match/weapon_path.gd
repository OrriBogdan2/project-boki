class_name WeaponPath
extends RefCounted
## The fixed weapon path: on every even level a hunter's signature weapon takes the next step on its
## hero's path (content/rules/weapon_path.json), with nothing to choose. The steps are WeaponUps
## upgrades, so they stack with the same perks found as orbs. Skill points and ability ranks are
## separate and unchanged (Hunter.gain_xp).

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/weapon_path.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## A hero's five steps (levels 2, 4, 6, 8, 10).
static func path_of(arch: String) -> Array:
	var p: Dictionary = rules().get("paths", {})
	return p.get(arch, rules().get("default", []))

## The step for an even level: "" on odd levels, level 1, or an empty path.
static func step_for(arch: String, lvl: int) -> String:
	if lvl < 2 or lvl % 2 != 0:
		return ""
	var steps := path_of(arch)
	if steps.is_empty():
		return ""
	return String(steps[clampi(lvl / 2 - 1, 0, steps.size() - 1)])

## Applies this level's step and returns what improved ({perk, name, desc, col, icon, n}), {} on an
## odd level. A step an orb already maxed is replaced by the next plain upgrade still open.
static func on_level(h, lvl: int) -> Dictionary:
	var id := step_for(h.arch, lvl)
	if id == "":
		return {}
	if not h.perk_open(id):
		id = ""
		for alt in ["hotload", "quickfeed", "longreach", "deepmag"]:
			if h.perk_open(alt):
				id = alt
				break
		if id == "":
			return {}
	h.add_perk(id)
	var pd: Dictionary = Data.PERKS[id]
	return {"perk": id, "name": pd["name"], "desc": pd["desc"], "col": pd["col"], "icon": pd["icon"], "n": h.perk_n(id)}
