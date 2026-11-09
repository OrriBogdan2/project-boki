class_name Auction
## The Auction House, for rare pieces (docs/decisions/0013-market.md); opens at market stall L3.
## A seller sets a start price, a minimum increment and a duration (12/24/48 h), and may make the
## lot friends-only. Bids are taken from your gems at once (escrow) and handed back when someone
## outbids you; a bid can't be withdrawn. A bid that lands in the last minute pushes the end out
## (anti-snipe). A listing fee up front and a sale tax on the winning bid are gem sinks.
## Offline: NPC lots (rare goods) stand in for other sellers, and NPC bidders bid on your lots up
## to auction.npc_bid_k x reference (never on friends-only ones); rivals on NPC lots bid up to
## auction.npc_lot_cap x reference.
##
## A Lot is {id, key, payload, seller ("you" or an NPC), start, step, ends (unix s), friends,
## top (0 = no bid yet), bidder ("" / "you" / an NPC name), cap (an NPC lot's rivals' limit)}.

const NPC_BID_CHANCE := 0.6      # per lot per expedition (offline): an NPC bids when it still can

static func _st() -> Dictionary:
	return MarketSave.section("auction")

static func _rules() -> Dictionary:
	return Goods.rules()["auction"]

static func lots() -> Array:
	return _st()["lots"]

static func find(id: String) -> Dictionary:
	for lot in lots():
		if String(lot["id"]) == id: return lot
	return {}

## The least the next bid can be.
static func min_bid(lot: Dictionary) -> int:
	return int(lot["start"]) if int(lot["top"]) <= 0 else int(lot["top"]) + int(lot["step"])

static func _note(text: String) -> void:
	var lg: Array = _st()["log"]
	lg.append(text)
	while lg.size() > 30: lg.pop_front()

# ------------------------------------------------------------------ selling
## Puts one of your goods up. {ok, why, id, fee}.
static func create(key: String, start: int, step: int, hours: int, friends: bool) -> Dictionary:
	if Stalls.level() < 3:
		return {"ok": false, "why": "Upgrade the market stall to open the Auction House"}
	if Goods.have(key) <= 0:
		return {"ok": false, "why": "You don't have that"}
	if not (_rules()["hours"] as Array).any(func(hh): return int(hh) == hours):
		return {"ok": false, "why": "Run it for 12, 24 or 48 hours"}
	if start < 1 or step < 1:
		return {"ok": false, "why": "The start price and the step are at least 1 gem"}
	if lots().filter(func(l): return String(l["seller"]) == "you").size() >= int(_rules()["max_open"]):
		return {"ok": false, "why": "You can run %d auctions at once" % int(_rules()["max_open"])}
	var fee := Stalls.list_fee(start)
	if int(Save.d.get("gems", 0)) < fee:
		return {"ok": false, "why": "Listing costs %d gems" % fee}
	Save.d["gems"] = int(Save.d["gems"]) - fee
	var payload: Dictionary = Goods.take(key)
	if key.begins_with("gear:"): key = "gear:" + String(payload["gear"].get("uid", ""))
	var lot := {"id": MarketSave.next_id(), "key": key, "payload": payload, "seller": "you", "start": start,
		"step": step, "ends": MarketSave.now() + hours * 3600, "friends": friends, "top": 0, "bidder": "", "cap": 0}
	lots().append(lot)
	Save.save_game()
	return {"ok": true, "why": "", "id": String(lot["id"]), "fee": fee}

# ------------------------------------------------------------------ bidding
## Bids on a lot. The gems are held at once; outbid, they come back. {ok, why}.
static func bid(id: String, amount: int) -> Dictionary:
	var lot := find(id)
	if lot.is_empty() or MarketSave.now() >= int(lot["ends"]):
		return {"ok": false, "why": "That auction is over"}
	if String(lot["seller"]) == "you":
		return {"ok": false, "why": "You can't bid on your own lot"}
	if String(lot["bidder"]) == "you":
		return {"ok": false, "why": "You're the top bidder already"}
	if amount < min_bid(lot):
		return {"ok": false, "why": "Bid at least %d" % min_bid(lot)}
	if int(Save.d.get("gems", 0)) < amount:
		return {"ok": false, "why": "You have %d gems" % int(Save.d.get("gems", 0))}
	if not Goods.can_take_in(String(lot["key"])):
		return {"ok": false, "why": "You already have one of those"}
	Save.d["gems"] = int(Save.d["gems"]) - amount
	_place(lot, "you", amount)
	Save.save_game()
	return {"ok": true, "why": ""}

## A new top bid: the one it beats gets its gems back, and a bid in the last minute extends the end.
static func _place(lot: Dictionary, who: String, amount: int) -> void:
	if String(lot["bidder"]) == "you":
		Save.d["gems"] = int(Save.d.get("gems", 0)) + int(lot["top"])
		var what := Goods.name_of(String(lot["key"]), lot["payload"])
		_note("You were outbid on %s (your %d gems came back)." % [what, int(lot["top"])])
	lot["top"] = amount
	lot["bidder"] = who
	var now := MarketSave.now()
	if int(lot["ends"]) - now < int(_rules()["snipe_s"]):
		lot["ends"] = now + int(_rules()["extend_s"])

# ------------------------------------------------------------------ time passing
## Lots that ended are settled: the item goes to the winner, the seller is paid less tax, and a lot
## nobody bid on goes back to its seller. Returns lines for you.
static func settle() -> Array:
	var news: Array = []
	var now := MarketSave.now()
	for lot in lots().duplicate():
		if now < int(lot["ends"]): continue
		lots().erase(lot)
		var what := Goods.name_of(String(lot["key"]), lot["payload"])
		if String(lot["seller"]) == "you":
			if int(lot["top"]) > 0:
				var paid := int(lot["top"]) - Stalls.sale_tax(int(lot["top"]))
				Save.d["gems"] = int(Save.d.get("gems", 0)) + paid
				news.append("%s won your %s for %d gems (%d after tax)." % [lot["bidder"], what, int(lot["top"]), paid])
			else:
				Goods.give(String(lot["key"]), lot["payload"])
				news.append("Nobody bid on your %s: it came back." % what)
		elif String(lot["bidder"]) == "you":
			Goods.give(String(lot["key"]), lot["payload"])
			news.append("You won %s for %d gems." % [what, int(lot["top"])])
	for line in news: _note(line)
	return news

## NPC lots on offer: kept topped up to auction.npc_lots with rare and epic goods.
static func refill() -> void:
	var npc_open := lots().filter(func(l): return String(l["seller"]) != "you")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool: Array = Goods.catalogue().filter(func(k): return Goods.rarity_of(k) in ["rare", "epic"])
	var hours: Array = _rules()["hours"]
	for i in maxi(0, int(_rules()["npc_lots"]) - npc_open.size()):
		var key := String(pool[rng.randi_range(0, pool.size() - 1)])
		var ref := Goods.ref_of(key)
		var stall_names: Array = Goods.rules()["npc"]["stalls"]
		var seller := String(stall_names[rng.randi_range(0, stall_names.size() - 1)])
		lots().append({"id": MarketSave.next_id(), "key": key, "payload": {}, "seller": seller,
			"start": int(ceil(ref * float(_rules()["npc_lot_start"]))), "step": maxi(1, int(ceil(ref * 0.05))),
			"ends": MarketSave.now() + int(hours[rng.randi_range(0, hours.size() - 1)]) * 3600, "friends": false,
			"top": 0, "bidder": "", "cap": int(round(ref * float(_rules()["npc_lot_cap"]) * rng.randf_range(0.8, 1.0))),
		})

## One expedition's worth of NPC bidding (offline), then the endings. Returns lines for you.
static func tick(rng: RandomNumberGenerator) -> Array:
	for lot in lots():
		var involves_you := String(lot["bidder"]) == "you" or String(lot["seller"]) == "you"
		if not involves_you or MarketSave.now() >= int(lot["ends"]) or rng.randf() >= NPC_BID_CHANCE: continue
		var cap := _npc_cap(lot)
		if min_bid(lot) > cap: continue
		var amount := mini(cap, min_bid(lot) + int(lot["step"]) * rng.randi_range(0, 2))
		_place(lot, String(Data.BOT_NAMES[rng.randi_range(0, Data.BOT_NAMES.size() - 1)]), amount)
	var news := settle()
	refill()
	return news

## How high NPCs bid on a lot: your lots up to npc_bid_k x reference (none on friends-only lots), an
## NPC lot's rivals up to its cap.
static func _npc_cap(lot: Dictionary) -> int:
	if String(lot["seller"]) != "you":
		return int(lot["cap"])
	if bool(lot["friends"]):
		return 0
	return int(floor(Goods.ref_of(String(lot["key"]), lot["payload"]) * float(_rules()["npc_bid_k"])))
