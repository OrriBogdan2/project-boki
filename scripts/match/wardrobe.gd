class_name Wardrobe
extends RefCounted
## The Empty's clothes (content/rules/wardrobe.json): pieces by slot, each earned by playing and then kept. A new
## Empty starts bare (lore: the Empty lost its self, and wins its clothes back); the first-day list gives the first
## two. Owned ids are Save.d["wardrobe"]["owned"]; what you wear is look["wear"] {slot: id}. Cosmetic only.
## Drawing: back and accessory pieces set the look's "shroud" and "accessory" (Shrouds), head is a hood
## (Shrouds.dress), top, bottom and feet put cloth on the void body's own parts (EmptyVoid).

const SLOTS := ["head", "top", "bottom", "feet", "back", "accessory"]
const NEWS := "New clothes: %s. Open the menu (%s), Wardrobe, to change what you wear."


static func rules() -> Dictionary:
	return Content.rules("wardrobe")


static func pieces(slot: String) -> Array:
	return (rules()["pieces"] as Array).filter(func(p: Dictionary) -> bool: return p["slot"] == slot)


static func piece(id: String) -> Dictionary:
	for p in rules()["pieces"]:
		if p["id"] == id:
			return p
	return {}


## The piece worn in a slot of a clean look ({} for none).
static func worn(u: Dictionary, slot: String) -> Dictionary:
	return piece(String((u.get("wear", {}) as Dictionary).get(slot, "")))


static func fresh() -> Dictionary:
	return {"owned": []}


static func owned(id: String) -> bool:
	return (Save.d.get("wardrobe", fresh())["owned"] as Array).has(id)


## Whether this save has done what a piece asks.
static func earned(p: Dictionary) -> bool:
	var e: Dictionary = p["earn"]
	if e.has("first_day"):
		return GardenFirstDay.did(String(e["first_day"]))
	if e.has("stat"):
		return ClassUnlock.account_stat(String(e["stat"])) >= int(e["n"])
	if e.has("clan"):
		return (Save.d.get("guild_perks", []) as Array).has(e["clan"])
	if e.has("zones"):
		var zones: Dictionary = Save.d.get("zones", {})
		return (
			zones.values().filter(func(z: Variant) -> bool: return z is Dictionary and z.get("open", false)).size()
			>= int(e["zones"])
		)
	if e.has("mastery"):
		return ClassUnlock.mastery_level(String(e["mastery"])) >= int(e["level"])
	return false


## A look's wear with only known pieces, each in its own slot.
static func clean_wear(wear: Variant) -> Dictionary:
	var out := {}
	if not wear is Dictionary:
		return out
	for slot in SLOTS:
		var p := piece(String(wear.get(slot, "")))
		if not p.is_empty() and p["slot"] == slot:
			out[slot] = p["id"]
	return out


## Unmasked.clean: a look that wears pieces takes its cloak and accessory from them (a look from before the
## wardrobe, or a bot's, keeps its own).
static func fit(out: Dictionary) -> void:
	if not out.has("wear"):
		return
	out["wear"] = clean_wear(out["wear"])
	out["shroud"] = int(worn(out, "back").get("cut", Shrouds.NONE))
	out["accessory"] = int(worn(out, "accessory").get("kind", 0))


## The pieces an old look was wearing: its cloak and accessory.
static func from_look(u: Dictionary) -> Dictionary:
	var out := {}
	for p in rules()["pieces"]:
		if p["slot"] == "back" and int(p["cut"]) == int(u.get("shroud", Shrouds.NONE)):
			out["back"] = p["id"]
		elif p["slot"] == "accessory" and int(p["kind"]) == int(u.get("accessory", 0)):
			out["accessory"] = p["id"]
	return out


## Unmasked.migrate: an older save keeps the outfit it had as its starter set (owned and worn), then every piece
## already earned is added. Safe to run twice.
static func migrate(data: Dictionary) -> void:
	var lk: Variant = data.get("look")
	if not data.get("wardrobe") is Dictionary:
		var had := from_look(lk) if lk is Dictionary else {}
		data["wardrobe"] = {"owned": had.values()}
		if lk is Dictionary:
			lk["wear"] = had
		refresh(data, false)
		return
	refresh(data)


## Adds every piece this save has earned and does not own yet, to be announced (Save.d["wardrobe"]["news"]); with
## `put_on`, each goes on in a slot that is empty.
static func refresh(data: Dictionary = Save.d, put_on := true) -> void:
	var box: Dictionary = data["wardrobe"]
	var lk: Variant = data.get("look")
	if lk is Dictionary and not lk.has("wear"):
		lk["wear"] = {}
	for p in rules()["pieces"]:
		if (box["owned"] as Array).has(p["id"]) or not earned(p):
			continue
		box["owned"].append(p["id"])
		if not put_on:
			continue
		box["news"] = box.get("news", []) + [p["name"]]
		if lk is Dictionary and not lk["wear"].has(p["slot"]):
			lk["wear"][p["slot"]] = p["id"]
	if lk is Dictionary:
		fit(lk)


## On a Home: says what was earned since the last time (its toast) and redresses you in it. Once per piece.
static func announce(home: Node) -> void:
	var box: Dictionary = Save.d.get("wardrobe", {})
	var names: Array = box.get("news", [])
	if names.is_empty() or home == null:
		return
	box.erase("news")
	Save.save_game()
	home._toast(NEWS % [", ".join(names), Settings.key_cap("menu")])
	home._refresh_player_model()


## A look wearing `id` in `slot` ("" takes it off).
static func wearing(lk: Dictionary, slot: String, id: String) -> Dictionary:
	var out := lk.duplicate(true)
	var wear: Dictionary = out.get("wear", {})
	if id == "":
		wear.erase(slot)
	else:
		wear[slot] = id
	out["wear"] = wear
	fit(out)
	return out
