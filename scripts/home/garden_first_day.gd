class_name GardenFirstDay
extends RefCounted
## The first-day list in the Goals tracker for a new save: feed your Boki, play with a toy, run your
## first race, see a nap pile, pair two Boki in the Nook. One line each, ticked when it happens, one small
## gem reward at the end, then gone (content/rules/farm_tutorial.json "first_day"). Not tutorial steps.
## State is Save.d.tutorial.gfd = {did: id -> true, paid}. Only Save.fresh makes it, so older saves never see it.

static func rules() -> Dictionary:
	return FarmTutorial.rules()["first_day"]

## Is the list on for this save (it has the state and the reward is not paid yet)?
static func active() -> bool:
	var st = Save.d["tutorial"].get("gfd")
	return typeof(st) == TYPE_DICTIONARY and not bool(st["paid"])

static func did(id: String) -> bool:
	var st = Save.d["tutorial"].get("gfd")
	return typeof(st) == TYPE_DICTIONARY and bool(st["did"].get(id, false))

## The rows for the tracker, in list order with the ticked ones last: {text, done, two}. "two" lines need a
## second Boki, so they wait in the list until the roster has two.
static func rows() -> Array:
	if not active():
		return []
	var all: Array = (rules()["rows"] as Array).map(
			func(r): return {"text": String(r["text"]), "done": did(String(r["id"])), "two": bool(r.get("two", false))})
	return all.filter(func(r): return not r["done"]) + all.filter(func(r): return r["done"])

## Something on the list happened. The last tick pays the reward and says so on `h` (a Home, if given).
static func mark(id: String, h = null) -> void:
	var list: Array = rules()["rows"]
	if did(id) or not active() or not list.any(func(r): return String(r["id"]) == id):
		return
	var st: Dictionary = Save.d["tutorial"]["gfd"]
	st["did"][id] = true
	st["paid"] = list.all(func(r): return bool(st["did"].get(String(r["id"]), false)))
	var gems := int(rules()["reward_gems"]) if st["paid"] else 0
	Save.d["gems"] = int(Save.d["gems"]) + gems
	Save.save_game()
	if gems > 0 and h:
		h._toast("First day done: %d gems" % gems)
