class_name BaseFeed
extends RefCounted
## A hungry base Boki feeds itself (briefs/design/GARDEN.md section 2: bowls and snacks, never a penalty). A
## feeder with food comes first (HomeEcon.feed_goal, k["eat"]); with none to eat from it picks the ripe snack
## patch and eats one snack (the rest go to your pantry), or fetches a snack from the pantry at the house door.
## BaseLife runs the walk in its Eat state through tick() (k["life_eat"] = {from, food, at}); the meal goes
## through Care.feed, so the journal, the lean and the care day see it like any other.

const AT := 1.2            # m: close enough to the patch or the door to eat
const WALK := 35.0         # s it walks for a snack before it gives up (Eat's cap in base_life.json is 40)

## Sets off for food if there is any: true when it did (k["eat"] or k["life_eat"] is set).
static func pick(h, k: Dictionary) -> bool:
	var rec: Dictionary = k["rec"]
	if k.has("eat") or k.has("life_eat"):
		return true
	if Care.need(rec, "food") >= Econ.HUNGRY_AT:
		return false
	if h.hecon and h.hecon.feed_goal(k):
		return true
	var e := SnackPatch.entry(Save.d)
	if SnackPatch.ripe(e, Time.get_unix_time_from_system()):
		k["life_eat"] = {"from": "patch", "food": "", "at": HomeLayout.deco_center(e)}
	else:
		var f := pantry(rec)
		if f == "":
			return false
		k["life_eat"] = {"from": "pantry", "food": f, "at": door(h)}
	k["goal"] = k["life_eat"]["at"]
	k.erase("stare")
	return true

## A snack in the pantry it will eat: its favourite if there is one, else the first it does not
## hate; "" for none.
static func pantry(rec: Dictionary) -> String:
	var crops: Dictionary = Save.d.get("crops", {})
	var likes: Dictionary = rec.get("likes", {})
	var fav := String(likes.get("food", ""))
	var grown := SnackPatch.snacks(Save.d)
	if int(crops.get(fav, 0)) > 0 or (grown.has(fav) and Econ.pantry(fav) > 0):
		return fav
	for f in grown:
		if Econ.pantry(String(f)) > 0 and String(f) != String(likes.get("hates", "")):
			return String(f)
	return ""

## Where the pantry is on the farm: the house door, or the landing when there is no house.
static func door(h) -> Vector3:
	return h._house_door() if KinIndoors.has_house(h.spots) else HomeLayout.LANDING

## One tick of BaseLife's Eat state for a snack: walks, eats on arrival. True while it is still at it.
static func tick(h, k: Dictionary, since: float) -> bool:
	if not k.has("life_eat"):
		return false
	var e: Dictionary = k["life_eat"]
	var at: Vector3 = e["at"]
	k["goal"] = at
	if Vector2(at.x - k["pos"].x, at.z - k["pos"].z).length() > AT:
		if since > WALK:
			k.erase("life_eat")
			h._emote(k, "?")
			return false
		return true
	var rec: Dictionary = k["rec"]
	var food := String(e["food"])
	if String(e["from"]) == "patch":
		var got := SnackPatch.harvest(Save.d, Time.get_unix_time_from_system())
		food = _choose(rec, got)
	k.erase("life_eat")
	k["t"] = randf_range(1.0, 2.0)
	if food == "" or not Econ._take_pantry(food):
		h._emote(k, "?")
		return false
	var res := Care.feed(rec, food)
	if not res.get("ok", false):
		SnackPatch.shelve(Save.d, food)      # it would not eat it: back on the shelf
		h._emote(k, "?")
		return false
	h._emote(k, "♥" if res.get("love", false) else "♪")
	GardenFirstDay.mark("feed", h)
	if String(e["from"]) == "patch":
		h._toast("%s picked the patch and ate a %s; the rest went to the pantry"
				% [rec["name"], Care.food_name(food).to_lower()])
	return false

## Which of the snacks it just picked it eats: its favourite, else the first it does not hate.
static func _choose(rec: Dictionary, got: Array) -> String:
	var likes: Dictionary = rec.get("likes", {})
	if got.has(String(likes.get("food", ""))):
		return String(likes["food"])
	for f in got:
		if String(f) != String(likes.get("hates", "")):
			return String(f)
	return ""
