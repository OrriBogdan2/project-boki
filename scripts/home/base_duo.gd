class_name BaseDuo
extends RefCounted
## The duo bonus (GARDEN_MODERN.md section 5 rank 4): Boki whose bond is friend_at or more (rules in
## content/rules/base_duo.json) hand off cleanly in the Dash and wake happier from a nap they shared. Nothing
## is saved but a journal line, once per Boki; the bonds are rec["bonds"] as BaseLife keeps them.

static func rules() -> Dictionary:
	return Content.rules("base_duo")

## Both Boki's bond with each other is at least friend_at.
static func friends(a: Dictionary, b: Dictionary) -> bool:
	var at := float(rules()["friend_at"])
	return BaseLife.bond(a, b) >= at and BaseLife.bond(b, a) >= at

## The roster Boki `rec` is closest to, if that bond is a duo; {} when it has none.
static func best_friend(rec: Dictionary) -> Dictionary:
	var best := {}
	var top := float(rules()["friend_at"])
	for o in Save.d["roster"]:
		if o != rec and friends(rec, o) and BaseLife.bond(rec, o) >= top:
			top = BaseLife.bond(rec, o)
			best = o
	return best

## Adds `k`'s seconds asleep beside friend `o` (BaseLife's nap tick).
static func nap_beside(k: Dictionary, o: Dictionary, dt: float) -> void:
	if friends(k["rec"], o["rec"]):
		k["duo_s"] = float(k.get("duo_s", 0.0)) + dt
		k["duo_with"] = o["rec"]

## On waking: a nap shared long enough with a friend restores nap_joy more, and the first one goes in the journal.
static func woke(k: Dictionary) -> void:
	var friend: Dictionary = k.get("duo_with", {})
	if float(k.get("duo_s", 0.0)) >= float(rules()["nap_min_s"]) and not friend.is_empty():
		Care.change(k["rec"], "joy", float(rules()["nap_joy"]))
		note_first(k["rec"], friend, "napped with")
	k.erase("duo_s")
	k.erase("duo_with")

## The first duo moment of a Boki goes in its journal, once (`what`: what it did with the friend).
static func note_first(rec: Dictionary, friend: Dictionary, what: String) -> void:
	for m in rec["memory"]:
		if m["kind"] == "duo":
			return
	Save.remember(rec, "duo", "%s %s, a friend: better together" % [what, friend["name"]], 0.5)
