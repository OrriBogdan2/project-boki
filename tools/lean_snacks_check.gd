extends RefCounted
## --lean-snacks-check: every lean type has a snack and every snack is in exactly one zone's list (GARDEN_MODERN 8,
## GARDEN.md 10.2). The data is content/rules/lean.json (foods), snacks.json (the new snacks) and snack_patch.json
## (zone_snacks). The new snacks are real foods tinted by their type; the start garden's patch rotates through
## all of them; a zone's patch grows its own list. Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("SNACKS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_types_and_zones()
	_foods()
	_habits()
	_patch()
	print("SNACKS DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _types_and_zones() -> void:
	var types: Dictionary = Lean.rules()["types"]
	var foods: Dictionary = Lean.rules()["foods"]
	var missing := types.keys().filter(func(t): return not foods.values().has(t))
	ok(missing.is_empty(), "every type has a snack (none for: %s)" % str(missing))
	var count := {}
	for z in SnackPatch.rules()["zone_snacks"]:
		for s in SnackPatch.rules()["zone_snacks"][z]:
			count[s] = int(count.get(s, 0)) + 1
	var wrong := foods.keys().filter(func(s): return int(count.get(s, 0)) != 1)
	ok(wrong.is_empty(), "every snack is in exactly one zone list (not once: %s)" % str(wrong))
	var stray := count.keys().filter(func(s): return not foods.has(s))
	ok(stray.is_empty(), "no zone list holds an unknown food (%s)" % str(stray))
	ok(SnackPatch.rules()["zone_snacks"].size() == 5, "five zone lists")

func _foods() -> void:
	var tint_gap := 0.0
	for s in Lean.rules()["foods"]:
		var def: Dictionary = Care.FOODS.get(s, Data.CROPS.get(s, {}))
		ok(not def.is_empty() and Care.food_name(s) != s, "%s is a real food named %s" % [s, Care.food_name(s)])
		var t := String(Lean.rules()["foods"][s])
		ok(Lean.key_of(s) == ("" if t == "normal" else t), "%s leans a Boki to %s" % [s, t])
	for s in Content.rules("snacks")["foods"]:
		var tint := Color(String(Lean.rules()["types"][Content.rules("snacks")["foods"][s]["type"]]["tint"]))
		var c := Care.food_col(s)
		tint_gap = maxf(tint_gap, Vector3(c.r - tint.r, c.g - tint.g, c.b - tint.b).length())
	ok(tint_gap < 0.01, "each new snack's colour is its type's tint (gap %.3f)" % tint_gap)
	var rec := Save.new_kin("puddlet")
	Care.ensure(rec)
	FarmUnlocks.rules()["base_mode"] = true
	ok(Evo.eat(rec, "frostdrop") == "ice", "a Frost drop meal leans a Boki to ice")
	FarmUnlocks.rules()["base_mode"] = false

func _habits() -> void:
	var by: Dictionary = Content.rules("garden_trust")["food_by_element"]
	var bad_food := by.keys().filter(func(e): return not Lean.rules()["foods"].has(by[e]))
	ok(bad_food.is_empty(), "every habit food is a known food (%s)" % str(bad_food))
	var kinds := {}
	for e in by:
		kinds[by[e]] = true
	ok(kinds.size() >= 12, "habit foods spread over the snacks (%d different)" % kinds.size())

func _patch() -> void:
	Save.d = Save.fresh()
	HomeLayout.ensure(Save.d)
	var e := {"id": SnackPatch.ID, "t": 1, "x": 0, "z": 0, "r": 0}
	Save.d["layout"]["deco"].append(e)
	var seen := {}
	for i in 24:
		for s in SnackPatch.harvest(Save.d, 1.0e9 + i * 1.0e4):
			seen[s] = true
	var unseen: Array = Lean.rules()["foods"].keys().filter(func(s): return not seen.has(s))
	ok(unseen.is_empty(), "the start patch grew every snack within 24 ripenings (never: %s)" % str(unseen))
	Save.d["layout"]["theme"] = "ridge"
	e["rot"] = 0
	var ridge: Array = SnackPatch.harvest(Save.d, 3.0e9)
	var own: Array = SnackPatch.rules()["zone_snacks"]["ridge"]
	ok(ridge == own, "a ridge patch grows exactly its zone's list (%s)" % str(ridge))
