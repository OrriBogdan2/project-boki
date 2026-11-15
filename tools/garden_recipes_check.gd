extends RefCounted
## --garden-recipes-check (GARDEN_MODERN.md 1.2 items 5, 12-16, 22-25 and 1.4): the Mixing Bowl. Every recipe in
## content/rules/garden_recipes.json is listed, consumes exactly what it asks for and yields exactly what it
## lists (and does nothing when short); the personality items never move a trait past the base_drift week cap,
## alone or with the friends' pull; a sweet's lean is kept 7 garden days against other meals; the Fourfold Bun
## and the Twinbun do what they say. Never touches the real save.

const EPS := 0.000001
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("GARDENRECIPES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_listed()
	for r in GardenRecipes.all():
		_recipe(r)
	_week_cap()
	_sweets()
	_bun_and_twin()
	_screens()
	print("GARDENRECIPES DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

func _boki(who: String) -> Dictionary:
	var rec := Save.new_kin("cindle", who)
	rec["level"] = 10
	rec["traits"] = {"bravery": 0.5, "temper": 0.5, "loyalty": 0.5, "curiosity": 0.5}
	return rec

func _near(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) < eps

func _pools() -> String:
	return JSON.stringify([Save.d["items"], Save.d["crops"]])

func _listed() -> void:
	var rs: Array = GardenRecipes.all()
	var gives := {}
	var fine := true
	var none := true
	for r in rs:
		gives[r["gives"]] = true
		fine = fine and GardenItems.has(String(r["gives"]))
		fine = fine and GardenRecipes.need_line(r) != "" and GardenRecipes.result_line(r) != ""
		none = none and not GardenRecipes.plan(r)["ok"]
	ok(rs.size() == 7 and gives.size() == 7 and fine, "7 recipes (bun, 5 sweets, Twinbun), each giving its own item")
	ok(none, "with an empty bag every recipe is still listed but none can be mixed")

## Does a plan have the shape the recipe lists: n things, of the allowed ids / one type / one id.
func _shape(r: Dictionary, take: Dictionary) -> bool:
	var need: Dictionary = r["need"]
	var total := 0
	for id in take:
		total += int(take[id])
	if total != int(need["n"]):
		return false
	var ids: Array = take.keys()
	match String(need["kind"]):
		"different":
			return ids.all(func(id): return need["of"].has(id) and int(take[id]) == 1)
		"snack_type":
			var t := Lean.key_of(ids[0])
			return ids.all(func(id): return Data.CROPS.has(id) and Lean.key_of(id) == t and need["types"].has(t))
		_:
			return ids == [need["item"]]

## A bag holding exactly what the recipe needs (one short when `short`), plus spares otherwise.
func _stock(r: Dictionary, short: bool) -> void:
	Save.d = Save.fresh()
	Save.d["items"] = {}
	Save.d["crops"] = {}
	var need: Dictionary = r["need"]
	var n := int(need["n"]) - (1 if short else 0)
	match String(need["kind"]):
		"different":
			for i in n:
				Save.d["items"][need["of"][i]] = 2
		"snack_type":
			var types: Array = need["types"].duplicate()      # the last type with a snack: the plan has to search
			types.reverse()
			for t in types:
				var foods: Array = Data.CROPS.keys().filter(func(f): return Lean.key_of(f) == t)
				if Save.d["crops"].is_empty() and not foods.is_empty():
					Save.d["crops"][foods[0]] = n + (0 if short else 2)
		_:
			Save.d["items"][need["item"]] = n + (0 if short else 1)

func _recipe(r: Dictionary) -> void:
	var id := String(r["id"])
	_stock(r, true)
	var snap := _pools()
	ok(not GardenRecipes.plan(r)["ok"] and not GardenRecipes.mix(r) and _pools() == snap,
			"%s: one short, nothing is planned or taken" % id)
	_stock(r, false)
	var was := {"items": Save.d["items"].duplicate(), "crops": Save.d["crops"].duplicate()}
	var p := GardenRecipes.plan(r)
	ok(p["ok"] and _shape(r, p["take"]), "%s: the plan takes %s, the shape the recipe lists" % [id, p["text"]])
	ok(_pools() == JSON.stringify([was["items"], was["crops"]]), "%s: planning takes nothing" % id)
	ok(GardenRecipes.mix(r), "%s: it mixes" % id)
	var exact := true
	for pool in was:
		for key in set_union(was[pool], Save.d[pool]):
			var came := int(r["n"]) if (pool == "items" and key == r["gives"]) else 0
			var want := int(was[pool].get(key, 0)) - int(p["take"].get(key, 0)) + came
			exact = exact and int(Save.d[pool].get(key, 0)) == want
	ok(exact, "%s: exactly the plan left the bag and exactly %d %s came in" % [id, int(r["n"]), r["gives"]])

func set_union(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = a.keys()
	for k in b:
		if not out.has(k):
			out.append(k)
	return out

func _week_cap() -> void:
	var cap := float(Content.rules("base_drift")["week_cap"])
	var picks := {"dare_pepper": "bravery", "lullwort_tea": "temper", "peekbox": "curiosity"}
	for id in picks:
		var tr: String = picks[id]
		var a := _boki("A-" + id)
		var b := _boki("B-" + id)
		a["bonds"] = {String(b["uid"]): 0.9}
		b["bonds"] = {String(a["uid"]): 0.9}
		b["traits"][tr] = 0.05 if id == "lullwort_tea" else 0.95          # a friend pulling the other way
		var uses := 0
		for day in 6:                                                     # six days of one drift week
			for i in 3:
				uses += 1 if GardenItems.apply(a, id)["ok"] else 0
			BaseDrift.day([a, b])
		var moved := absf(float(a["traits"][tr]) - 0.5)
		var booked := float(a["drift"]["moved"][tr])
		ok(uses == 3 and moved <= cap + EPS and booked <= cap + EPS,
				"%s: %d of 18 tries work, moved %.2f of the %.2f cap, a friend pulling" % [id, uses, moved, cap])
	var a2 := _boki("Twin-A")
	var b2 := _boki("Twin-B")
	Save.d["items"]["twinbun"] = 10
	var shared := 0
	for i in 10:
		shared += 1 if GardenItems.share(a2, b2, "twinbun")["ok"] else 0
	var drift_a := absf(float(a2["traits"]["loyalty"]) - 0.5)
	var drift_b := absf(float(b2["traits"]["loyalty"]) - 0.5)
	var booked := float(a2["drift"]["moved"]["loyalty"])
	ok(shared == 10 and drift_a <= cap + EPS and drift_b <= cap + EPS and booked <= cap + EPS,
			"twinbun: loyalty stops at the %.2f cap while the bond keeps growing (%d shared)" % [cap, shared])

func _sweets() -> void:
	FarmUnlocks.rules()["base_mode"] = true
	var e: Dictionary = GardenItems.item("cinderbrittle")["effect"]
	var rec := _boki("Sweet")
	var pv := GardenItems.apply(rec, "cinderbrittle", "rock")
	var half := float(e["share"]) * Evo.LEAN_FULL
	ok(pv["ok"] and _near(float(rec["lean"]["rock"]), half) and half == 12.0 and Evo.LEAN_FULL == 24.0,
			"a sweet takes its type's lean to 12 of 24")
	var wrong := GardenItems.preview(_boki("Other"), "cinderbrittle", "grass")
	ok(wrong["ok"] and String(wrong["text"]).begins_with("Fire"), "a pick outside the group falls to its first type")
	var meals := ["tidebloom", "sunroot", "emberberry", "puffcorn", "glowcap", "starfruit"]
	var days := int(e["hold_days"])
	for d in days - 1:
		Evo.eat(rec, meals[d % meals.size()])
		GardenItems.day(rec)
	Evo.eat(rec, "tidebloom")
	ok(_near(float(rec["lean"]["rock"]), half), "%d other meals in %d days: the lean has not faded" % [days, days - 1])
	GardenItems.day(rec)
	ok(rec["hold"].is_empty(), "the hold is let go on day %d" % days)
	Evo.eat(rec, "tidebloom")
	ok(_near(float(rec["lean"]["rock"]), half - Evo.LEAN_FADE), "then the next other meal fades it as it always did")
	FarmUnlocks.rules()["base_mode"] = false

func _bun_and_twin() -> void:
	var rec := _boki("Bun")
	var before: Dictionary = rec["stats"].duplicate()
	var pv := GardenItems.apply(rec, "fourfold_bun")
	var all := true
	for s in Care.STATS:
		all = all and int(rec["stats"][s]) == int(before[s]) + 1
	ok(pv["ok"] and all, "Fourfold Bun: +1 to all four stats")
	var a := _boki("Pip")
	var b := _boki("Bo")
	a["traits"]["loyalty"] = 0.40
	Save.d["items"]["twinbun"] = 1
	var bond0 := BaseLife.bond(a, b)
	var res := GardenItems.share(a, b, "twinbun")
	var loyal := _near(float(a["traits"]["loyalty"]), 0.44) and _near(float(b["traits"]["loyalty"]), 0.54)
	var bonded := _near(BaseLife.bond(a, b) - bond0, 0.1) and BaseLife.bond(a, b) == BaseLife.bond(b, a)
	var used: bool = int(Save.d["items"]["twinbun"]) == 0
	ok(res["ok"] and loyal and bonded and used, "Twinbun: loyalty +0.04 each, bond +0.1 both ways, one used")
	ok(not GardenItems.share(a, b, "twinbun")["ok"], "Twinbun: with none left nothing happens")

## The Bowl screen lists every recipe and the feed rows offer a sweet per type and the Twinbun for the closest friend.
func _screens() -> void:
	Save.d = Save.fresh()
	Save.d["items"] = {"cinderbrittle": 1, "twinbun": 1, "thumpnut": 1, "zipseed": 1}
	var v := VBoxContainer.new()
	MixingBowl.fill(v, func(): pass)
	var cards := v.get_children().filter(func(c): return c is PanelContainer)
	var mixable := v.find_children("*", "Button", true, false).size()
	ok(cards.size() == GardenRecipes.all().size() and mixable == 1, "the Bowl lists %d recipes, one Mix" % cards.size())
	var rec := _boki("Pip")
	var near := _boki("Near")
	var far := _boki("Far")
	rec["bonds"] = {String(near["uid"]): 0.5}
	var f := VBoxContainer.new()
	GardenItemRows.add_bag(f, rec, [far, near], func(_id): pass, func(_res): pass)
	var text := ""
	for l in f.find_children("*", "Label", true, false):
		text += (l as Label).text + "|"
	var rows: bool = text.contains("Fire") and text.contains("Dragon") and text.contains("with Near")
	ok(rows and not text.contains("with Far"), "feed rows: a row per sweet type; Twinbun to the closest friend")
