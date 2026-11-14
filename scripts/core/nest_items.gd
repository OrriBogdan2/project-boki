class_name NestItems
extends RefCounted
## The nest items (content/rules/garden_items.json family "nest", briefs/design/GARDEN_MODERN.md 1.2 items 26-29).
## Placed in the Nesting Nook while a pair is picked (Save.d nest_set: gifts = Heirloom Threads, species and
## habit = the uid of the parent wearing the Likeness Locket / Lullaby Shell), shown by preview_lines() before
## the egg is made, and used up by lay(). The egg keeps what hatching needs (inherit, habit); hatched() does it.
## Hatchling Down drops at every hatch (drop_down) and is fed from the feed menu (GardenItems, kind "down").

const SET_KEY := "nest_set"
const DOWN_NAMES := "down_names"      # babies whose hatchling down is still in the bag, oldest first

static func placed() -> Dictionary:
	if not Save.d.has(SET_KEY):
		Save.d[SET_KEY] = {}
	return Save.d[SET_KEY]

## The item whose effect is nest `kind` ("gifts", "species" or "habit").
static func item_of(kind: String) -> Dictionary:
	for it in GardenItems.rules()["items"]:
		if it["effect"].get("nest", "") == kind:
			return it
	return {}

static func held(kind: String) -> int:
	return int(Save.d["items"].get(String(item_of(kind)["id"]), 0))

## Heirloom Threads on the pair: placed, no more than held or than the item allows.
static func threads() -> int:
	return mini(int(placed().get("gifts", 0)), mini(held("gifts"), int(item_of("gifts")["effect"]["max"])))

static func add_threads(by: int) -> void:
	var most := mini(held("gifts"), int(item_of("gifts")["effect"]["max"]))
	placed()["gifts"] = clampi(threads() + by, 0, most)

## Puts the Locket ("species") or Shell ("habit") on the parent with this uid ("" takes it off).
static func wear(kind: String, uid: String) -> void:
	placed()[kind] = uid

## The parent wearing it among a and b ({} if none, or the item isn't in the bag).
static func wearer(kind: String, a: Dictionary, b: Dictionary) -> Dictionary:
	var uid := String(placed().get(kind, ""))
	if held(kind) < 1 or uid == "":
		return {}
	for parent in [a, b]:
		if parent["uid"] == uid:
			return parent
	return {}

## What the placed items will do to an egg of a and b: inborn gifts from the parents, the species
## ("" for either), the parent whose habit and strongest trait pass exactly ({} for none).
static func plan(a: Dictionary, b: Dictionary) -> Dictionary:
	var locket := wearer("species", a, b)
	return {"inherit": Care.IV_INHERIT + threads() * int(item_of("gifts")["effect"]["n"]),
			"species": String(locket.get("species", "")), "habit_from": wearer("habit", a, b)}

## The parent's strongest trait (the first of a tie).
static func top_trait(rec: Dictionary) -> String:
	var best := ""
	for t in rec["traits"]:
		if best == "" or float(rec["traits"][t]) > float(rec["traits"][best]):
			best = t
	return best

## One line per placed item, the exact effect: the Nook shows these before the egg is made.
static func preview_lines(a: Dictionary, b: Dictionary) -> Array:
	var p := plan(a, b)
	var out: Array = []
	if threads() > 0:
		out.append("%d of %d gifts from parents (%s)" % [p["inherit"], Care.IV_KEYS.size(), item_of("gifts")["name"]])
	if p["species"] != "":
		var kind: String = Data.KIN[p["species"]]["name"]
		out.append("It will be a %s (%s on %s)" % [kind, item_of("species")["name"], wearer("species", a, b)["name"]])
	var hf: Dictionary = p["habit_from"]
	if not hf.is_empty():
		var t := top_trait(hf)
		var habit := Unique.quirk_name(hf).to_lower()
		var who := "%s's habit (%s) and %s (%.2f)" % [hf["name"], habit, t, float(hf["traits"][t])]
		out.append("%s: %s, exactly" % [item_of("habit")["name"], who])
	return out

## The egg is laid: records the placed items on it (egg["sp"] follows a Locket) and uses them up.
static func lay(egg: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var p := plan(a, b)
	egg["inherit"] = p["inherit"]
	if p["species"] != "":
		egg["sp"] = p["species"]
	var used := {"gifts": threads(), "species": int(p["species"] != ""), "habit": int(not p["habit_from"].is_empty())}
	if used["habit"] > 0:
		egg["habit"] = p["habit_from"]["uid"]
	for kind in used:
		if used[kind] > 0:
			Save.add_item(String(item_of(kind)["id"]), -int(used[kind]))
	Save.d[SET_KEY] = {}

## Inborn gifts the baby takes from its parents (an egg laid before nest items has none recorded).
static func inherit_n(egg: Dictionary) -> int:
	return int(egg.get("inherit", Care.IV_INHERIT))

## The baby is out: a Lullaby Shell parent's habit and strongest trait pass exactly (no wobble).
## The items the egg was laid with are kept on the baby (lineage["nest"], shown on its Family tab).
static func hatched(baby: Dictionary, egg: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var uid := String(egg.get("habit", ""))
	var threads_used := (inherit_n(egg) - Care.IV_INHERIT) / int(item_of("gifts")["effect"]["n"])
	if threads_used > 0 or egg.has("sp") or uid != "":
		baby["lineage"]["nest"] = {"gifts": threads_used, "species": egg.has("sp"), "habit": uid != ""}
	if uid == "":
		return
	var parent: Dictionary = a if a["uid"] == uid else b
	baby["dna"]["quirk"] = Unique.of(parent)["quirk"]
	var t := top_trait(parent)
	baby["traits"][t] = float(parent["traits"][t])

## One Hatchling Down for every hatch, remembering whose.
static func drop_down(baby: Dictionary) -> void:
	Save.add_item("hatchling_down", 1)
	if not Save.d.has(DOWN_NAMES):
		Save.d[DOWN_NAMES] = []
	Save.d[DOWN_NAMES].append(String(baby["name"]))

## What the next Down fed to a Boki will be remembered as.
static func memory_line() -> String:
	var names: Array = Save.d.get(DOWN_NAMES, [])
	return "it will remember %s's hatching" % names[0] if not names.is_empty() else "it will remember a hatching"

static func take_memory() -> String:
	var names: Array = Save.d.get(DOWN_NAMES, [])
	return ("remembers %s's hatching" % names.pop_front()) if not names.is_empty() else "remembers a hatching"
