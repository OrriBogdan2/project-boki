class_name FavFood
extends RefCounted
## A Boki's favourite food (GARDEN.md lever 3). It lives in rec["likes"]["food"], hidden until the
## first time you feed it (Care.discover). Rules: content/rules/fav_food.json.

## The food its type leans to, or else the one its strongest personality trait does. Seeded by its id.
static func roll(rec: Dictionary) -> String:
	var r := Content.rules("fav_food")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(rec.get("uid", "x")) + "fav")
	var theme := String(Data.KIN.get(String(rec.get("species", "")), {}).get("theme", ""))
	var by_type: Dictionary = r["by_type"]
	if by_type.has(theme) and rng.randf() < float(r["type_share"]):
		return String(by_type[theme])
	var by_trait: Dictionary = r["by_trait"]
	var traits: Dictionary = rec.get("traits", {})
	var best := ""
	for t in by_trait:
		if best == "" or float(traits.get(t, 0.5)) > float(traits.get(best, 0.5)):
			best = t
	return String(by_trait.get(best, r["default"]))

## Sets its favourite; the food it won't eat gives way if they would clash.
static func set_food(rec: Dictionary, food: String) -> void:
	var likes: Dictionary = rec["likes"]
	if likes["hates"] == food:
		likes["hates"] = likes["food"]
	likes["food"] = food

## Old records get one too: rolled once from type and personality, unless you already found theirs out.
static func settle(rec: Dictionary) -> void:
	if rec.has("fav_v"):
		return
	rec["fav_v"] = 1
	if not (rec["known"] as Array).has("food"):
		set_food(rec, roll(rec))

## A baby may take one parent's favourite (its own roll otherwise).
static func inherit(baby: Dictionary, a: Dictionary, b: Dictionary, rng: RandomNumberGenerator) -> void:
	Care.ensure(a)
	Care.ensure(b)
	var from: Dictionary = a if rng.randf() < 0.5 else b
	if rng.randf() < float(Content.rules("fav_food")["inherit"]):
		set_food(baby, String(from["likes"]["food"]))

## Extra trust and joy for its favourite, up to daily_cap times a day. Returns the trust given.
static func bonus(rec: Dictionary) -> float:
	var r := Content.rules("fav_food")
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	var fed: Dictionary = rec.get("fav_fed", {})
	if int(fed.get("day", -1)) != day:
		fed = {"day": day, "n": 0}
	rec["fav_fed"] = fed
	if int(fed["n"]) >= int(r["daily_cap"]):
		return 0.0
	fed["n"] = int(fed["n"]) + 1
	Care.change(rec, "joy", float(r["joy"]))
	var was := float(rec.get("trust", 0.0))
	rec["trust"] = clampf(was + float(r["trust"]), 0.0, 100.0)
	return float(rec["trust"]) - was
