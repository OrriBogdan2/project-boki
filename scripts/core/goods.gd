class_name Goods
## What can be traded at the stalls, the auction house and the Black Market, and where each kind is
## held (docs/decisions/0013-market.md). A good is named by a key:
##   good:<id>   market goods in Save.d["goods"] (counts): rare materials, boss trophies, dyes
##   util:<id>   belt utility in the stash (Save.d["items"]); tonics stay on the Exchange only
##   wear:<id>   Boki wear (Data.ACCS) in Save.d["accs"]: you own one of each, a worn one stays put
##   gear:<uid>  one armory piece (unique: its record travels with the listing)
## take() hands back a payload (the gear record, or {}) and give() puts one back from it, so a
## listing can always return exactly what it took. Numbers: content/rules/market.json.

static func rules() -> Dictionary:
	return Content.rules("market")

static func kind_of(key: String) -> String:
	return key.get_slice(":", 0)

static func id_of(key: String) -> String:
	return key.get_slice(":", 1)

## Every key that NPC stalls, search and the Black Market know (gear is unique, so never listed here).
static func catalogue() -> Array:
	var out: Array = []
	for id in rules()["goods"]: out.append("good:" + String(id))
	for id in rules()["utility_rarity"]: out.append("util:" + String(id))
	for id in rules()["wear_rarity"]: out.append("wear:" + String(id))
	return out

static func good(id: String) -> Dictionary:
	return rules()["goods"].get(id, {})

# ------------------------------------------------------------------ what it is
static func name_of(key: String, payload := {}) -> String:
	match kind_of(key):
		"good": return String(good(id_of(key)).get("name", id_of(key)))
		"util": return UtilityBelt.name_of(id_of(key))
		"wear": return String(Data.ACCS.get(id_of(key), {}).get("name", id_of(key)))
		"gear": return Loot.name_of(_gear(key, payload))
	return key

## "common", "uncommon", "rare" or "epic" (gear maps its five tiers onto these).
static func rarity_of(key: String, payload := {}) -> String:
	match kind_of(key):
		"good": return String(good(id_of(key)).get("rarity", "common"))
		"util": return String(rules()["utility_rarity"].get(id_of(key), "common"))
		"wear": return String(rules()["wear_rarity"].get(id_of(key), "common"))
		"gear": return ["common", "uncommon", "rare", "epic", "epic"][Loot.rar_of(_gear(key, payload))]
	return "common"

static func rarity_name(key: String, payload := {}) -> String:
	return String(rules()["rarity"][rarity_of(key, payload)]["name"])

static func rarity_col(key: String, payload := {}) -> Color:
	return Color(String(rules()["rarity"][rarity_of(key, payload)]["col"]))

## The reference price in gems: what the game itself sells it for (vendor price, or the catalogue's).
static func ref_of(key: String, payload := {}) -> int:
	match kind_of(key):
		"good": return int(good(id_of(key)).get("ref", 10))
		"util": return UtilityBelt.price_of(id_of(key))
		"wear": return int(Data.ACCS.get(id_of(key), {}).get("price", 20))
		"gear": return Loot.value(_gear(key, payload))
	return 10

static func col_of(key: String, payload := {}) -> Color:
	match kind_of(key):
		"good": return Color(String(good(id_of(key)).get("col", "ffffff")))
		"util": return UtilityBelt.col_of(id_of(key))
		"wear": return Data.ACCS.get(id_of(key), {}).get("col", Color.WHITE)
		"gear": return Loot.col_of(_gear(key, payload))
	return Color.WHITE

static func icon_of(key: String, payload := {}) -> String:
	match kind_of(key):
		"good": return String(good(id_of(key)).get("icon", "gem"))
		"util": return UtilityBelt.icon_of(id_of(key))
		"wear": return "paw"
		"gear": return Loot.icon_of(_gear(key, payload))
	return "gem"

static func desc_of(key: String, payload := {}) -> String:
	match kind_of(key):
		"good": return String(good(id_of(key)).get("desc", ""))
		"util": return String(UtilityBelt.def(id_of(key)).get("desc", ""))
		"wear": return "Boki wear: put it on from a Boki's card (Dress)."
		"gear": return Loot.sub_of(_gear(key, payload))
	return ""

static func _gear(key: String, payload: Dictionary) -> Dictionary:
	return payload if not payload.is_empty() else Econ.find(id_of(key))

# ------------------------------------------------------------------ holding it
static func _store() -> Dictionary:
	if typeof(Save.d.get("goods")) != TYPE_DICTIONARY: Save.d["goods"] = {}
	return Save.d["goods"]

## How many you could list or sell right now.
static func have(key: String) -> int:
	var id := id_of(key)
	match kind_of(key):
		"good": return int(_store().get(id, 0))
		"util": return int(Save.d.get("items", {}).get(id, 0)) if rules()["utility_rarity"].has(id) else 0
		"wear": return 1 if (Save.d.get("accs", []) as Array).has(id) and _worn_by(id) == "" else 0
		"gear":
			var picked := (Save.d.get("loadout", {}) as Dictionary).values().has(id)
			return 1 if not Econ.find(id).is_empty() and not picked else 0
	return 0

## Would one more fit? (You own one of each kind of Boki wear.)
static func can_take_in(key: String) -> bool:
	return kind_of(key) != "wear" or not (Save.d.get("accs", []) as Array).has(id_of(key))

static func _worn_by(acc: String) -> String:
	for r in Save.d.get("roster", []):
		if String(r.get("acc", "")) == acc: return String(r.get("name", "a Boki"))
	return ""

## Takes one out of where it's held. Returns its payload ({"gear": record} for gear, else {}), or
## null when you don't have it.
static func take(key: String) -> Variant:
	if have(key) <= 0:
		return null
	var id := id_of(key)
	match kind_of(key):
		"good": _add(id, -1)
		"util": Save.add_item(id, -1)
		"wear": (Save.d["accs"] as Array).erase(id)
		"gear":
			var it := Econ.find(id)
			Econ.remove(id)
			return {"gear": it}
	return {}

## Puts one in (bought, won, or a listing coming back).
static func give(key: String, payload := {}) -> void:
	var id := id_of(key)
	match kind_of(key):
		"good": _add(id, 1)
		"util": Save.add_item(id, 1)
		"wear":
			if not Save.d.has("accs"): Save.d["accs"] = []
			if not (Save.d["accs"] as Array).has(id): Save.d["accs"].append(id)
		"gear": Save.d["armory"].append(payload.get("gear", {}))

static func _add(id: String, n: int) -> void:
	var st := _store()
	st[id] = maxi(0, int(st.get(id, 0)) + n)
	if int(st[id]) == 0: st.erase(id)

## Everything you hold that could go on a stall or up for auction: [key].
static func mine() -> Array:
	var out: Array = []
	for key in catalogue():
		if have(key) > 0: out.append(key)
	for it in Econ.armory():
		var gk := "gear:" + String(it.get("uid", ""))
		if String(it.get("t", "")) != "val" and have(gk) > 0: out.append(gk)
	return out

# ------------------------------------------------------------------ finding them
## After an expedition you made it out of: a trophy per boss you helped kill, an Ink for each boss
## you killed (its own type, "ink_<type>" in your match stats, or any Ink for "ink_any"), and sometimes a rare
## material or an Ink (rarer ones less often). Returns the keys found.
static func on_result(bosses: int, rng: RandomNumberGenerator, stats := {}) -> Array:
	var found: Array = []
	var fr: Dictionary = rules()["finds"]
	var trophies := _of_kind("trophy")
	for i in bosses * int(fr["trophy_per_boss"]):
		found.append("good:" + String(_weighted(trophies, rng)))
	for k in stats:
		if String(k).begins_with("ink_") and rules()["goods"].has(String(k)):
			for i in int(stats[k]): found.append("good:" + String(k))
	for i in int(stats.get("ink_any", 0)):
		found.append("good:" + String(_weighted(_of_kind("ink"), rng)))
	if rng.randf() < float(fr["material"]):
		found.append("good:" + String(_weighted(_of_kind("material"), rng)))
	if rng.randf() < float(fr["ink"]):
		found.append("good:" + String(_weighted(_of_kind("ink"), rng)))
	for key in found: give(key)
	return found

static func _of_kind(kind: String) -> Array:
	var out: Array = []
	for id in rules()["goods"]:
		if String(rules()["goods"][id]["kind"]) == kind: out.append(id)
	return out

## One id, weighted by how often its rarity restocks.
static func _weighted(ids: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for id in ids: total += restock(rarity_of("good:" + String(id)))
	var x := rng.randf() * total
	for id in ids:
		x -= restock(rarity_of("good:" + String(id)))
		if x <= 0.0: return String(id)
	return String(ids[-1])

## How often vendors carry a rarity (0..1).
static func restock(rarity: String) -> float:
	return float(rules()["rarity"].get(rarity, {}).get("restock", 0.5))

# ------------------------------------------------------------------ dyes
static func is_dye(key: String) -> bool:
	return kind_of(key) == "good" and String(good(id_of(key)).get("kind", "")) == "dye"

## The colour a Boki's worn accessory shows: its dye, else the accessory's own.
static func wear_col(rec: Dictionary) -> Color:
	var dye := String(rec.get("dye", ""))
	if dye != "" and not good(dye).is_empty():
		return Color(String(good(dye)["col"]))
	return Data.ACCS.get(String(rec.get("acc", "")), {}).get("col", Color.WHITE)

## Uses one dye on what a Boki wears. "" if it worked, else why not.
static func dye(rec: Dictionary, dye_id: String) -> String:
	if String(rec.get("acc", "")) == "":
		return "It isn't wearing anything to dye"
	if have("good:" + dye_id) <= 0 or not is_dye("good:" + dye_id):
		return "You have no %s" % String(good(dye_id).get("name", "dye")).to_lower()
	_add(dye_id, -1)
	rec["dye"] = dye_id
	Save.save_game()
	return ""
