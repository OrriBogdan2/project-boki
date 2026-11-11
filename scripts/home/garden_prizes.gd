class_name GardenPrizes
extends RefCounted
## Prizes and cups for the garden games (content/rules/garden_prizes.json, GARDEN_MODERN.md 4.4).
## A win by the Boki you backed rolls the game's prize table, adds the day's first-win item, and moves that
## Boki along the weekly cup: Sprout, Bloom, Crown, three wins in a row against rivals the data calls stronger.
## The Crown gives the game's Cup Ribbon (rec.ribbons) and the cup prize, once a game a week for each Boki.
## State is lazy and needs no migration: Save.d cups (runs), Save.d prize_day (first win), rec.ribbons.

static func rules() -> Dictionary:
	return Content.rules("garden_prizes")

static func ids() -> Array:
	return rules()["games"].keys()

static func game(id: String) -> Dictionary:
	return rules()["games"][id]

## The weights of a game's prize table added up.
static func table_total(id: String) -> int:
	var total := 0
	for e in game(id)["table"]:
		total += int(e["w"])
	return total

## What the cup compares: a Boki's trained stats added up.
static func strength(rec: Dictionary) -> int:
	var total := 0
	for s in Care.STATS:
		total += int(rec["stats"].get(s, 0))
	return total

## The strongest of `recs` other than `mine`: the rival a race is judged against.
static func strongest(recs: Array, mine: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for r in recs:
		if r != mine and (best.is_empty() or strength(r) > strength(best)):
			best = r
	return best

## One weighted pick from a game's table.
static func roll(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var at := rng.randi_range(1, table_total(id))
	for e in game(id)["table"]:
		at -= int(e["w"])
		if at <= 0:
			return e
	return game(id)["table"][0]

static func entry_name(e: Dictionary) -> String:
	if String(e["kind"]) == "snack":
		return Care.food_name(String(e["id"]))
	return GardenItems.item_name(String(e["id"]))

static func week_of(now: float) -> int:
	return int(now / float(rules()["week_s"]))

static func ribbon_count(rec: Dictionary, id: String) -> int:
	return int(rec.get("ribbons", {}).get(id, {}).get("n", 0))

## True once this Boki has taken the game's Crown this week.
static func crowned_this_week(rec: Dictionary, id: String, now: float) -> bool:
	return ribbon_count(rec, id) > 0 and int(rec["ribbons"][id]["week"]) == week_of(now)

## The round this Boki fights next in a game's cup: an index into cup.rounds.
static func stage(rec: Dictionary, id: String) -> int:
	return int(_runs(id).get(String(rec["uid"]), 0))

static func _runs(id: String) -> Dictionary:
	return Save.d.get_or_add("cups", {}).get_or_add(id, {})

## Banks one prize entry: an item to the garden bag, a snack to the pantry.
static func bank(e: Dictionary) -> void:
	if String(e["kind"]) == "snack":
		var crops: Dictionary = Save.d["crops"]
		crops[e["id"]] = int(crops.get(e["id"], 0)) + 1
	else:
		Save.add_item(String(e["id"]), 1)

## Pays one finished match to the Boki you backed (`mine`) against `foe`. Returns what the card shows:
## {game, won, items (entries), first, round (name of the round won), crown, ribbon, reset}.
static func settle(id: String, mine: Dictionary, foe: Dictionary, won: bool, now := -1.0,
		rng: RandomNumberGenerator = null) -> Dictionary:
	var out := {"game": id, "won": won, "items": [], "first": false, "round": "", "crown": false,
			"ribbon": false, "reset": false}
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	if not won:
		GardenXp.play(id, mine, false, false)
		out["reset"] = _runs(id).erase(String(mine["uid"]))
		return out
	var dice := rng
	if dice == null:
		dice = RandomNumberGenerator.new()
		dice.randomize()
	var got: Array = [roll(id, dice)]
	var days: Dictionary = Save.d.get_or_add("prize_day", {})
	var today := int(now / float(rules()["day_s"]))
	if int(days.get(id, -1)) != today:
		days[id] = today
		out["first"] = true
		got.append({"kind": "item", "id": game(id)["first"]})
	for e in got:
		bank(e)
	out["items"] = got
	GardenXp.play(id, mine, true, out["first"])
	_cup(out, mine, foe, now)
	return out

static func _cup(out: Dictionary, mine: Dictionary, foe: Dictionary, now: float) -> void:
	var id: String = out["game"]
	var rounds: Array = rules()["cup"]["rounds"]
	var runs := _runs(id)
	var uid := String(mine["uid"])
	var at := int(runs.get(uid, 0))
	if crowned_this_week(mine, id, now):
		return
	if float(strength(foe)) < float(rounds[at]["min_ratio"]) * float(strength(mine)):
		return
	out["round"] = rounds[at]["name"]
	if at < rounds.size() - 1:
		runs[uid] = at + 1
		return
	runs.erase(uid)
	_crown(out, mine, now)

## The Crown: the game's Cup Ribbon on the winner and the cup prize in the bag.
static func _crown(out: Dictionary, mine: Dictionary, now: float) -> void:
	var id: String = out["game"]
	var g := game(id)
	var ribbons: Dictionary = mine.get_or_add("ribbons", {})
	var have: Dictionary = ribbons.get_or_add(id, {"n": 0, "week": -1})
	have["n"] = int(have["n"]) + 1
	have["week"] = week_of(now)
	out["crown"] = true
	out["ribbon"] = true
	var prize := {"kind": "item", "id": g["cup_prize"]}
	bank(prize)
	(out["items"] as Array).append(prize)
	Save.remember(mine, "cup", "won the %s Crown cup and wears the %s" % [g["name"], g["ribbon"]], 2.0)

## The lines a result card adds under the gems: the prizes won and the cup step. font 0 leaves it out.
static func rows(res: Dictionary, font := 0) -> Array:
	var out: Array = []
	var names: Array = []
	for e in res["items"]:
		names.append(entry_name(e))
	if not names.is_empty():
		out.append(["Prize: " + ", ".join(names) + (" (first win today)" if res["first"] else ""), UI.GOLD])
	if res["ribbon"]:
		out.append(["Crown! The %s is yours" % game(res["game"])["ribbon"], UI.ACCENT_HI])
	elif res["round"] != "":
		out.append(["Cup: beat the %s round" % res["round"], UI.TEAL])
	elif res["reset"]:
		out.append(["The cup run starts over", UI.MUTED])
	if font > 0:
		for r in out:
			r.insert(1, font)
	return out
