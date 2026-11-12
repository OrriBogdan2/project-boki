class_name BlackMarket
## Old Pell's Black Market (the "ransom" building; docs/decisions/0013-market.md): the Ransom tab
## (Ransom: buying back Boki nobody claimed, offers to whoever captured yours) and the premium shop
## here: a small daily rotation of rare and epic goods, and now and then a Rare Egg, priced well
## over what they're worth (a gem sink). Never keys, shards or anything found only in matches.
## Once every wayseed_days he also holds one Wayseed ("seed:<zone>") for a zone still locked, so a
## player who never goes on a run still reaches every zone (GARDEN.md 10.3).
## A stock entry is {id, key ("good:..", "wear:..", "egg:<species>" or "seed:<zone>"), price}.

static func _st() -> Dictionary:
	return MarketSave.section("black")

static func _rules() -> Dictionary:
	return Goods.rules()["black_market"]

## Today's stock (rolled once a day; what you buy is gone until tomorrow).
static func stock() -> Array:
	var st := _st()
	if MarketSave.new_day(st):
		st["stock"] = _roll(String(st["day"]))
	_hold_seed(st)
	return st["stock"]

## Keeps the stock's one Wayseed right: none for a zone that has opened since, one for the next
## locked zone whose Wayseed you do not hold (the same one all week, Glasswater first) unless this week's is
## already bought.
static func _hold_seed(st: Dictionary) -> void:
	var stock: Array = st["stock"]
	stock.assign(stock.filter(func(e): return not _stale_seed(String(e["key"]))))
	var locked: Array = GardenZones.ids().filter(
			func(z): return not GardenZones.is_open(z) and not GardenZones.keys_for(z)["seed"])
	if locked.is_empty() or not FarmUnlocks.base_mode() or int(st.get("seed_week", -1)) == _week() \
			or stock.any(func(e): return is_seed(String(e["key"]))):
		return
	stock.append({"id": MarketSave.next_id(), "key": "seed:" + String(locked[0]),
		"price": int(_rules()["wayseed_price"])})

static func _stale_seed(key: String) -> bool:
	return is_seed(key) and GardenZones.is_open(id_of(key))

## The week number (wayseed_days long) since the epoch.
static func _week() -> int:
	return int(MarketSave.now() / 86400.0 / float(_rules()["wayseed_days"]))

static func is_seed(key: String) -> bool:
	return key.begins_with("seed:")

static func _roll(day: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("black|" + day + "|" + String(Save.profile().get("id", "")))
	var pool: Array = Goods.catalogue().filter(func(k): return Goods.rarity_of(k) in ["rare", "epic"])
	var out: Array = []
	while out.size() < int(_rules()["stock"]) and not pool.is_empty():
		var key := String(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		var k := rng.randf_range(float(_rules()["price_lo"]), float(_rules()["price_hi"]))
		out.append({"id": MarketSave.next_id(), "key": key, "price": int(ceil(Goods.ref_of(key) * k))})
	var rares: Array = Data.KIN.keys().filter(func(sp): return Data.is_rare(String(sp)))
	if not rares.is_empty() and rng.randf() < float(_rules()["egg_chance"]):
		var species := String(rares[rng.randi_range(0, rares.size() - 1)])
		out.append({"id": MarketSave.next_id(), "key": "egg:" + species, "price": int(_rules()["egg_price"])})
	return out

static func name_of(key: String) -> String:
	if key.begins_with("egg:"):
		return "Rare " + Data.egg_name(id_of(key))
	if is_seed(key):
		return String(GardenZones.info(id_of(key)).get("name", "")) + " Wayseed"
	return Goods.name_of(key)

static func id_of(key: String) -> String:
	return key.get_slice(":", 1)

## Buys one: the gems are gone for good. {ok, why, key}.
static func buy(id: String) -> Dictionary:
	for e in stock():
		if String(e["id"]) != id: continue
		var key := String(e["key"])
		var price := int(e["price"])
		if int(Save.d.get("gems", 0)) < price:
			return {"ok": false, "why": "You need %d more gems" % (price - int(Save.d.get("gems", 0)))}
		if not key.begins_with("egg:") and not is_seed(key) and not Goods.can_take_in(key):
			return {"ok": false, "why": "You already have one of those"}
		Save.d["gems"] = int(Save.d["gems"]) - price
		if key.begins_with("egg:"):
			Incubator.add(id_of(key), String(Data.KIN[id_of(key)].get("boss", "")))
		elif is_seed(key):
			Save.add_item(GardenZones.wayseed(id_of(key)), 1)
			_st()["seed_week"] = _week()
		else:
			Goods.give(key)
		stock().erase(e)
		Save.save_game()
		return {"ok": true, "why": "", "key": key}
	return {"ok": false, "why": "That's gone"}
