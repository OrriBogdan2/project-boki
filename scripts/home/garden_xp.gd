class_name GardenXp
## XP a kin earns on the farm: feeding, petting, fetch, the training yard and the garden games. Numbers in
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

## A garden game played: game XP, game_win on a win, times first_win_mult on the day's first win in that
## game. Returns the XP given.
static func played(rec: Dictionary, won: bool, first: bool) -> int:
	var r := rules()
	var xp := int(r["game_win"]) if won else int(r["game"])
	if won and first:
		xp *= int(r["first_win_mult"])
	Game.add_xp(rec, xp, {})
	return xp
