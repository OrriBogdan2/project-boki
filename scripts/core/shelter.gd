class_name Shelter
## The Shelter (docs/decisions/0013-market.md), at the market stall from L2. Boki are never sold for
## gems: they're given a new home here. Strays (ordinary commons, restocked daily) and Boki that
## players put up wait for a keeper. The shelter never runs out of Boki to adopt: it always holds at
## least shelter.strays strays (commons that aren't the usual starters, one low flat shelter.stray_fee),
## and adopting a stray brings a new one at once.
##   - Putting a Boki up pays the giver nothing. Not your last Boki, not a pinned one (partner, first
##     Boki), not an egg's parent, not one under shelter.min_age_days old (no breed-and-dump), and each
##     Boki at most once a day. You can never adopt back one you gave away.
##   - Anyone adopts for gems that scale with level, rarity, shimmer and mutations; the gems are
##     destroyed (a sink, paid to nobody). The Boki keeps "raised by <name>" and half its trust.
##   - Offline, NPC adopters take a given Boki now and then (tick).
## A card is {id, rec, price, from ("" for a stray, else who gave it up), t}.

static func _st() -> Dictionary:
	return MarketSave.section("shelter")

static func _rules() -> Dictionary:
	return Goods.rules()["shelter"]

## What adopting this Boki costs (the gems are destroyed). A stray (no giver) is the flat stray_fee.
static func price(rec: Dictionary, stray := false) -> int:
	var r := _rules()
	if stray: return int(r["stray_fee"])
	var p := int(r["base"]) + int(r["per_level"]) * (int(rec.get("level", 1)) - 1)
	if Data.is_rare(String(rec.get("species", ""))): p += int(r["rare"])
	if bool(rec.get("shimmer", false)): p += int(r["shimmer"])
	p += int(r["per_mutation"]) * Mutations.of(rec).size()
	return p

## The cheapest Boki the shelter has now (the floor price even when it is empty).
static func cheapest() -> int:
	var cs := cards()
	if cs.is_empty():
		return int(_rules()["stray_fee"])
	var best := 1 << 30
	for c in cs:
		best = mini(best, int(c["price"]))
	return best

## Everyone waiting today. A new day brings fresh strays; Boki put up by players stay until adopted.
static func cards() -> Array:
	var st := _st()
	if MarketSave.new_day(st):
		var kept: Array = (st["stock"] as Array).filter(func(c): return String(c.get("from", "")) != "")
		st["stock"] = kept
	return _top_up(st)

## Tops the stock up to the stray floor (a new day, or a stray just adopted).
static func _top_up(st: Dictionary) -> Array:
	var stock: Array = st["stock"]
	while stock.filter(func(c): return String(c.get("from", "")) == "").size() < int(_rules()["strays"]):
		stock.append(_stray(String(st["day"])))
	return stock

## One stray: a level-1 common that isn't a usual starter (Data.LAUNCH_KIN), at the flat stray fee.
static func _stray(day: String) -> Dictionary:
	var id := MarketSave.next_id()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("shelter|" + day + "|" + id + "|" + String(Save.profile().get("id", "")))
	var pool: Array = Data.common_kin().filter(func(k): return not Data.LAUNCH_KIN.has(k))
	var rec := Save.new_kin(String(pool[rng.randi_range(0, pool.size() - 1)]), "", int(rng.randi() & 0x7fffffff))
	rec["trust"] = 25.0
	rec["shimmer"] = false
	rec.erase("mutations")
	return {"id": id, "rec": rec, "price": price(rec, true), "from": "", "t": MarketSave.now()}

## Did you give this Boki up? (Then you can never adopt it back.)
static func gave(uid: String) -> bool:
	return (_st()["gave"] as Array).has(uid)

static func find(id: String) -> Dictionary:
	for c in cards():
		if String(c["id"]) == id: return c
	return {}

# ------------------------------------------------------------------ adopting
## Adopts a Boki: the gems are destroyed and it comes home. {ok, why, rec}.
static func adopt(id: String) -> Dictionary:
	if Stalls.level() < 2:
		return {"ok": false, "why": "Upgrade the market stall to open the shelter"}
	var c := find(id)
	if c.is_empty():
		return {"ok": false, "why": "Someone else gave that one a home"}
	var rec: Dictionary = c["rec"]
	if gave(String(rec.get("uid", ""))):
		return {"ok": false, "why": "You gave %s up: let someone else give it a home" % rec.get("name", "it")}
	var cost := int(c["price"])
	if int(Save.d.get("gems", 0)) < cost:
		return {"ok": false, "why": "You need %d more gems" % (cost - int(Save.d.get("gems", 0)))}
	if KinBox.full():
		return {"ok": false, "why": "The farm and the Boki Burrow are full"}
	Save.d["gems"] = int(Save.d["gems"]) - cost
	cards().erase(c)
	_top_up(_st())
	var giver := String(c.get("from", ""))
	rec["trust"] = float(rec.get("trust", 25.0)) * float(_rules()["trust_keep"])
	rec["origin"] = {"how": "shelter", "where": {"place": "shelter"}, "from": giver, "t": MarketSave.now()}
	if giver == "":
		rec.erase("serial")
		rec.erase("ot")
		Save.remember(rec, "adopted", "was a stray at the shelter until you gave it a home", 2.0)
	else:
		Save.remember(rec, "adopted", "was raised by %s, then found a new home with you" % giver, 1.0)
	Care.ensure(rec)
	BaseShy.start(rec)
	Save.d["roster"].append(rec)
	if Save.kin(str(Save.d.get("active", ""))).is_empty():
		Save.d["active"] = rec["uid"]
	Save.register(rec)
	KinBox.route_new(rec)
	Care.dex_got(rec)
	Save.save_game()
	return {"ok": true, "why": "", "rec": rec}

## What the player reads when `rec` has just come home: on the farm, or asleep in the Burrow and why.
static func arrival_line(rec: Dictionary) -> String:
	var nm := String(rec.get("name", "It"))
	if not KinBox.is_boxed(rec):
		return "%s is coming home with you" % nm
	var z := GardenZones.zone_of(rec)
	var why := "you have one like it out already"
	if GardenZones.room(z) <= 0:
		why = "%s is full (%d out)" % [GardenZones.info(z).get("name", z), KinBox.farm_cap()]
	return "%s is asleep in the Burrow (%s): %s" % [nm, KinBox.page_name(KinBox.page_of(rec)), why]

# ------------------------------------------------------------------ giving one up
## Why this Boki can't be put up ("" if it can).
static func why_not(rec: Dictionary) -> String:
	var uid := String(rec.get("uid", ""))
	if Stalls.level() < 2:
		return "Upgrade the market stall to open the shelter"
	if (Save.d["roster"] as Array).size() <= 1:
		return "It's your only Boki"
	var pinned := KinBox.pinned(rec)
	if pinned != "":
		return pinned
	var egg: Dictionary = Save.d.get("egg", {})
	if not egg.is_empty() and (String(egg.get("a", "")) == uid or String(egg.get("b", "")) == uid):
		return "Its egg is still in the Nesting Nook: wait for it to hatch"
	var age_days := float(MarketSave.now() - int(rec.get("born", 0))) / 86400.0
	if age_days < float(_rules()["min_age_days"]):
		return "It's too young: a Boki can be put up from %d days old" % int(_rules()["min_age_days"])
	if String(rec.get("sheltered", "")) == MarketSave.today():
		return "It was put up today already"
	return ""

## Puts one of your Boki up for adoption. It pays nothing. {ok, why}.
static func give_up(uid: String) -> Dictionary:
	var rec := Save.kin(uid)
	if rec.is_empty():
		return {"ok": false, "why": "No such Boki"}
	var why := why_not(rec)
	if why != "":
		return {"ok": false, "why": why}
	Save.d["roster"].erase(rec)
	for k in ["active", "active2"]:
		if String(Save.d.get(k, "")) == uid: Save.d[k] = ""
	if Save.kin(str(Save.d.get("active", ""))).is_empty() and not (Save.d["roster"] as Array).is_empty():
		Save.d["active"] = Save.d["roster"][0]["uid"]
	var keeper := String(Save.d.get("name", "Hunter"))
	rec["sheltered"] = MarketSave.today()
	var raised: Array = rec.get("raised_by", [])
	raised.append(keeper)
	rec["raised_by"] = raised
	var given: Array = _st()["gave"]
	given.append(uid)
	while given.size() > int(_rules()["gave_cap"]): given.pop_front()
	cards().append({"id": MarketSave.next_id(), "rec": rec, "price": price(rec), "from": keeper, "t": MarketSave.now()})
	Save.log_event("sheltered", rec, {})
	Save.save_game()
	return {"ok": true, "why": ""}

## One expedition's worth of NPC adopters (offline): a given Boki may find a home. Returns names.
static func tick(rng: RandomNumberGenerator) -> Array:
	var homed: Array = []
	for c in cards().duplicate():
		if String(c.get("from", "")) != "" and rng.randf() < float(_rules()["npc_adopt"]):
			cards().erase(c)
			homed.append(String(c["rec"].get("name", "A Boki")))
	return homed
