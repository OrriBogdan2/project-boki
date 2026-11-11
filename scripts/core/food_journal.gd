class_name FoodJournal
extends RefCounted
## What each food does stays a "?" until some Boki has been fed it once; then it is known for every
## Boki from then on. Kept per save file in d["foods_fed"] (food keys). Care.feed records a meal.

## What the food does, in words (always the real text; use line() to show it to the player).
static func effect(f: String) -> String:
	if Care.FOODS.has(f): return String(Care.FOODS[f]["desc"])
	var grows := ""
	for af in Evo.AFF:
		if Evo.AFF[af]["food"] == f: grows = "Leans it %s: its colour shifts. " % String(Evo.AFF[af]["name"]).to_lower()
	return grows + "Fills it up."

static func known(f: String) -> bool:
	return (Save.d["foods_fed"] as Array).has(f)

## Notes a meal. True the first time this food is fed to any Boki.
static func learn(f: String) -> bool:
	if known(f): return false
	Save.d["foods_fed"].append(f)
	return true

## The effect line for a menu: the real text once known, else "?".
static func line(f: String) -> String:
	return "Effect: " + (effect(f) if known(f) else "?")

## Old saves: a food a Boki is known to have eaten counts as known. Its loved food, once found out,
## and any food named in a "was fed ..." memory. Keyed by the missing field, so it needs no version.
static func migrate(data: Dictionary) -> void:
	if data.has("foods_fed"): return
	var fed := []
	for rec in data.get("roster", []):
		var likes: Dictionary = rec.get("likes", {})
		if (rec.get("known", []) as Array).has("food") and likes.has("food"): fed.append(String(likes["food"]))
		for mem in rec.get("memory", []):
			var text := String(mem.get("text", "")).to_lower()
			if String(mem.get("kind", "")) != "fed": continue
			for f in Care.FOODS.keys() + Data.CROPS.keys():
				if text.contains(Care.food_name(f).to_lower()): fed.append(f)
	var seen := []
	for f in fed:
		if not seen.has(f): seen.append(f)
	data["foods_fed"] = seen
