class_name GardenXp
## XP a kin earns on the farm: feeding, petting, fetch and the training yard. Numbers in
## content/rules/garden_xp.json. Level ups and evolutions go through Game.add_xp like a run's.

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/garden_xp.json"))
	return _rules

## action: "feed", "pet" or "fetch" (love: the kin's favourite); "drill" takes the points scored.
static func give(rec: Dictionary, action: String, love := false, points := 0) -> void:
	var r := rules()
	var xp := int(r["drill_per_point"]) * points
	if action != "drill":
		xp = int(r[action + "_love"]) if love else int(r[action])
	Game.add_xp(rec, xp, {})
