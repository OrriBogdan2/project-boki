class_name GardenXp
## XP a kin earns on the farm: feeding, petting, fetch, the training yard and the garden games. Numbers in
## content/rules/garden_xp.json (which also holds the level curve Game.xp_need reads). Level ups and
## evolutions go through Game.add_xp like a run's.

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/garden_xp.json"))
	return _rules

## A kin's first feed, pat and game of fetch each day pays `care` once (rec.xp_day, a day number a
## kind, lazy so old saves load); drill pays per training point. `now` is unix seconds (-1: the clock).
static func give(rec: Dictionary, action: String, points := 0, now := -1.0) -> void:
	var xp := int(rules()["drill_per_point"]) * points
	if action != "drill":
		if not _first_today(rec, action, now):
			return
		xp = int(rules()["care"])
	Game.add_xp(rec, xp, {})

## A finished garden game (GardenPrizes.settle) pays the Boki you backed: `play`, `win` for a win and
## `first_win` for the day's first win in that game. Only the games in rules().games pay.
static func play(id: String, rec: Dictionary, won: bool, first: bool) -> void:
	var r := rules()
	if not r["games"].has(id):
		return
	var xp := int(r["play"])
	if first:
		xp = int(r["first_win"])
	elif won:
		xp = int(r["win"])
	Game.add_xp(rec, xp, {})

static func _first_today(rec: Dictionary, kind: String, now: float) -> bool:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var today := int(now / float(GardenPrizes.rules()["day_s"]))
	var days: Dictionary = rec.get_or_add("xp_day", {})
	if int(days.get(kind, -1)) == today:
		return false
	days[kind] = today
	return true
