class_name Stalls
## Player stalls and market search (docs/decisions/0013-market.md). Your stall: price your own
## goods (Goods keys: gear, belt utility, Boki wear, trophies, dyes, rare materials); a listing fee
## up front and a sale tax on the sale. Search: look an item up and see the lowest prices across
## every stall. Offline (BACKEND "local") the other stalls are NPC stalls restocked daily, rarer
## goods less often, and NPC buyers now and then take a listing of yours priced at most
## npc.buy_k x its reference price (tick()). The same calls become server requests online
## (docs/EXCHANGE_SERVER.md).
##
## Your stall's level (L1 vendor, L2 + shelter, stall and search, L3 + auctions) is level().
##
## A Listing is {id, key, payload, price, t, seller ("you" or an NPC stall), qty}.

const BACKEND := "local"

static func _st() -> Dictionary:
	return MarketSave.section("stall")

static func _npc() -> Dictionary:
	return Goods.rules()["npc"]

## The market stall's level: the tier of the stall on a farm under the building pass (1 when it
## isn't standing yet). Farms without the building pass have no upgrades: everything is open (3).
static func level(d: Dictionary = Save.d) -> int:
	if not FarmUnlocks.gated(d):
		return 3
	var placed := HomeLayout.fixtures(d, "stall")
	return FarmSites.tier(placed[0]) if not placed.is_empty() else 1

## Does the stall's own vendor carry this today? Rarer goods restock less often (the same all day).
static func vendor_has(key: String) -> bool:
	var roll := absi(hash("vendor|%s|%s|%s" % [MarketSave.today(), key, String(Save.profile().get("id", ""))])) % 1000
	return float(roll) / 1000.0 < Goods.restock(Goods.rarity_of(key))

static func list_fee(price: int) -> int:
	return MarketSave.cut(price, float(Goods.rules()["fees"]["list_fee"]))

static func sale_tax(price: int) -> int:
	return MarketSave.cut(price, float(Goods.rules()["fees"]["sale_tax"]))

## The most an NPC buyer pays for this (offline): below every price the game sells it at.
static func npc_pays(key: String, payload := {}) -> int:
	return int(floor(Goods.ref_of(key, payload) * float(_npc()["buy_k"])))

# ------------------------------------------------------------------ your stall
static func mine() -> Array:
	return _st()["mine"]

## Puts one of your goods on your stall at a price. {ok, why, id, fee}.
static func list(key: String, price: int) -> Dictionary:
	if level() < 2:
		return {"ok": false, "why": "Upgrade the market stall to open your own stall"}
	if Goods.have(key) <= 0:
		return {"ok": false, "why": "You don't have that"}
	if price < 1 or price > 99999:
		return {"ok": false, "why": "Price it between 1 and 99999 gems"}
	if mine().size() >= int(Goods.rules()["stall"]["max_listed"]):
		return {"ok": false, "why": "Your stall holds %d things at once" % int(Goods.rules()["stall"]["max_listed"])}
	var fee := list_fee(price)
	if int(Save.d.get("gems", 0)) < fee:
		return {"ok": false, "why": "Listing costs %d gems" % fee}
	Save.d["gems"] = int(Save.d["gems"]) - fee
	var payload: Dictionary = Goods.take(key)
	if key.begins_with("gear:"): key = "gear:" + String(payload["gear"].get("uid", ""))
	var L := {"id": MarketSave.next_id(), "key": key, "payload": payload, "price": price, "t": MarketSave.now(),
		"seller": "you", "qty": 1}
	mine().append(L)
	Save.save_game()
	return {"ok": true, "why": "", "id": String(L["id"]), "fee": fee}

## Takes a listing down: the good comes back (the fee doesn't). {ok, why}.
static func unlist(id: String) -> Dictionary:
	for L in mine():
		if String(L["id"]) == id:
			if not Goods.can_take_in(String(L["key"])):
				return {"ok": false, "why": "You already have one of those"}
			mine().erase(L)
			Goods.give(String(L["key"]), L["payload"])
			Save.save_game()
			return {"ok": true, "why": ""}
	return {"ok": false, "why": "Not your listing"}

## One expedition's worth of NPC buyers: each listing priced at or under what they pay may sell.
## Returns [{key, payload, price, paid}].
static func tick(rng: RandomNumberGenerator) -> Array:
	var sold: Array = []
	for L in mine().duplicate():
		if int(L["price"]) > npc_pays(String(L["key"]), L["payload"]) or rng.randf() >= float(_npc()["buy_chance"]):
			continue
		mine().erase(L)
		var paid := int(L["price"]) - sale_tax(int(L["price"]))
		Save.d["gems"] = int(Save.d.get("gems", 0)) + paid
		var row := {"key": String(L["key"]), "payload": L["payload"], "price": int(L["price"]), "paid": paid,
			"t": MarketSave.now()}
		_st()["sold"].append(row)
		while (_st()["sold"] as Array).size() > 30: (_st()["sold"] as Array).pop_front()
		sold.append(row)
	return sold

# ------------------------------------------------------------------ the other stalls
## The NPC stalls' stock today: each stall carries a few goods, a good showing up with its rarity's
## restock odds, priced npc.sell_lo..sell_hi x reference.
static func npc_stock() -> Array:
	var st := _st()
	if MarketSave.new_day(st, "npc_day"):
		st["npc"] = _roll_npc(String(st["npc_day"]))
	return st["npc"]

static func _roll_npc(day: String) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("stalls|" + day + "|" + String(Save.profile().get("id", "")))
	var keys := Goods.catalogue()
	for stall_name in _npc()["stalls"]:
		var order := keys.duplicate()
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = order[i]
			order[i] = order[j]
			order[j] = tmp
		var carried := 0
		for key in order:
			if carried >= int(_npc()["per_stall"]): break
			if rng.randf() >= Goods.restock(Goods.rarity_of(key)): continue
			var markup := rng.randf_range(float(_npc()["sell_lo"]), float(_npc()["sell_hi"]))
			var price := int(ceil(Goods.ref_of(key) * markup))
			out.append({"id": MarketSave.next_id(), "key": key, "payload": {}, "price": price, "t": MarketSave.now(),
				 "seller": String(stall_name), "qty": rng.randi_range(1, 3)})
			carried += 1
	return out

## Buys one from an NPC stall. The gems leave the game (an NPC has no wallet). {ok, why, key}.
static func buy(id: String) -> Dictionary:
	for L in npc_stock():
		if String(L["id"]) != id: continue
		var price := int(L["price"])
		if int(Save.d.get("gems", 0)) < price:
			return {"ok": false, "why": "You need %d more gems" % (price - int(Save.d.get("gems", 0)))}
		if not Goods.can_take_in(String(L["key"])):
			return {"ok": false, "why": "You already have one of those"}
		Save.d["gems"] = int(Save.d["gems"]) - price
		Goods.give(String(L["key"]))
		L["qty"] = int(L["qty"]) - 1
		if int(L["qty"]) <= 0: npc_stock().erase(L)
		Save.save_game()
		return {"ok": true, "why": "", "key": String(L["key"])}
	for L in mine():
		if String(L["id"]) == id:
			return {"ok": false, "why": "That's your own listing: take it down instead"}
	return {"ok": false, "why": "That one's gone"}

# ------------------------------------------------------------------ search
## Every good whose name holds the text (all of them for ""), each with its listings across the
## stalls, cheapest first: [{key, rows: [Listing], lowest: price or -1}], cheapest goods first.
static func search(text: String) -> Array:
	var q := text.strip_edges().to_lower()
	var by_key := {}
	for L in npc_stock() + mine():
		var key := String(L["key"])
		if q != "" and not Goods.name_of(key, L["payload"]).to_lower().contains(q): continue
		if not by_key.has(key): by_key[key] = []
		by_key[key].append(L)
	var out: Array = []
	for key in by_key:
		var rows: Array = by_key[key]
		rows.sort_custom(func(a, b): return int(a["price"]) < int(b["price"]))
		out.append({"key": key, "rows": rows, "lowest": int(rows[0]["price"])})
	out.sort_custom(func(a, b): return int(a["lowest"]) < int(b["lowest"]))
	return out

## The lowest price anyone asks for a good right now (-1 when nobody has one).
static func lowest(key: String) -> int:
	for row in search(""):
		if String(row["key"]) == key: return int(row["lowest"])
	return -1
