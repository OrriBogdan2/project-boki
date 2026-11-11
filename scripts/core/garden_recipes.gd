class_name GardenRecipes
extends RefCounted
## The Mixing Bowl's recipes (content/rules/garden_recipes.json, briefs/design/GARDEN_MODERN.md 1.4).
## plan() says exactly what a recipe would take and give from the bag and pantry right now; mix() does
## that and nothing else. A recipe that can be planned always works: there are no failures.

static func rules() -> Dictionary:
	return Content.rules("garden_recipes")

static func all() -> Array:
	return rules()["recipes"]

## Where a thing is kept: snacks in the pantry (Save.d crops), everything else in the bag (Save.d items).
static func _pool(key: String) -> Dictionary:
	return Save.d["crops"] if Data.CROPS.has(key) else Save.d["items"]

static func held(key: String) -> int:
	return int(_pool(key).get(key, 0))

## What a recipe asks for, always shown: "3 snacks of one type: Grass, Bug or Spore".
static func need_line(recipe: Dictionary) -> String:
	var need: Dictionary = recipe["need"]
	var n := int(need["n"])
	match String(need["kind"]):
		"different": return "any %d different bites: %s" % [n, ", ".join(need["of"].map(_name))]
		"snack_type": return "%d snacks of one type: %s" % [n, _types(need["types"])]
		_: return "%d %s" % [n, _name(need["item"])]

## What it gives and does, always shown.
static func result_line(recipe: Dictionary) -> String:
	var e: Dictionary = GardenItems.item(String(recipe["gives"]))["effect"]
	match String(e["kind"]):
		"stat_all": return "+%d to all four stats (up to its level's limit)" % int(e["n"])
		"sweet":
			var to := roundi(float(e["share"]) * Evo.LEAN_FULL)
			var full := roundi(Evo.LEAN_FULL)
			var days := int(e["hold_days"])
			return "pick %s: that lean jumps to %d of %d, kept %d days" % [_types(e["types"]), to, full, days]
		_:
			return "two Boki share it: %s %+.2f each, their bond +%.1f" % [e["trait"], float(e["by"]), float(e["bond"])]

## {ok, take, text}: take maps item/snack id to how many go in right now (what mix() would use); text lists it.
static func plan(recipe: Dictionary) -> Dictionary:
	var need: Dictionary = recipe["need"]
	var n := int(need["n"])
	var take := {}
	match String(need["kind"]):
		"different":
			for id in need["of"]:
				if take.size() < n and held(id) > 0:
					take[id] = 1
			if take.size() < n:
				take = {}
		"snack_type":
			for t in need["types"]:
				if take.is_empty():
					take = _snacks(String(t), n)
		_:
			if held(String(need["item"])) >= n:
				take = {String(need["item"]): n}
	var bits: Array = take.keys().map(func(id): return "%d %s" % [take[id], _name(id)])
	return {"ok": not take.is_empty(), "take": take, "text": ", ".join(bits)}

static func _types(types: Array) -> String:
	return " / ".join(types.map(func(t): return Lean.face(t)["name"]))

static func _name(id: String) -> String:
	return GardenItems.item_name(id) if GardenItems.has(id) else Care.food_name(id)

## n snacks of lean type t out of the pantry (the most plentiful first), {} when there are fewer.
static func _snacks(t: String, n: int) -> Dictionary:
	var foods: Array = Data.CROPS.keys().filter(func(f): return Lean.key_of(f) == t and held(f) > 0)
	foods.sort_custom(func(a, b): return held(a) > held(b))
	var take := {}
	var left := n
	for f in foods:
		var k := mini(held(f), left)
		take[f] = k
		left -= k
	return take if left == 0 else {}

## Mixes a recipe: takes exactly what plan() named, gives exactly what it lists. False if it can't be planned.
static func mix(recipe: Dictionary) -> bool:
	var p := plan(recipe)
	if not p["ok"]:
		return false
	for id in p["take"]:
		_pool(id)[id] = held(id) - int(p["take"][id])
	var out := String(recipe["gives"])
	Save.add_item(out, int(recipe["n"]))
	return true
