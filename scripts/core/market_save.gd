class_name MarketSave
## The market's part of the save (docs/decisions/0013-market.md), its v7 -> v8 migration, and the
## once-per-expedition offline turnover of every market (NPC buyers, bidders and adopters).
##
## Save.d["market"]:
##   stall     {n, mine: [Listing], sold: [{key, price, paid, t}], npc_day, npc: [NPC listing]}   (Stalls)
##   auction   {lots: [Lot], log: [text]}                                                         (Auction)
##   shelter   {day, stock: [{id, rec, price, from, t}], gave: [uid]}                             (Shelter)
##   transfer  {out: [{id, rec, to, fee, t}], sent: [t]}                                          (Transfer)
##   black     {day, stock: [{id, key, price}]}                                                   (BlackMarket)
## Save.d["goods"] holds market goods (Goods). Every section is filled in on first use too, so a
## save that skipped the migration (a test, a hand-made save) still works.

static func fresh() -> Dictionary:
	return {
		"n": 0,
		"stall": {"mine": [], "sold": [], "npc_day": "", "npc": []},
		"auction": {"lots": [], "log": []},
		"shelter": {"day": "", "stock": [], "gave": []},
		"transfer": {"out": [], "sent": []},
		"black": {"day": "", "stock": []},
	}

## One section of the market save, filled in if it is missing or damaged.
static func section(part: String) -> Dictionary:
	if typeof(Save.d.get("market")) != TYPE_DICTIONARY:
		Save.d["market"] = fresh()
	var m: Dictionary = Save.d["market"]
	var f: Dictionary = fresh()[part]
	if typeof(m.get(part)) != TYPE_DICTIONARY:
		m[part] = f
	var st: Dictionary = m[part]
	for k in f:
		if typeof(st.get(k)) != typeof(f[k]): st[k] = f[k]
	return st

## A fresh id for a listing, lot, adoption card or transfer ("M12").
static func next_id() -> String:
	section("stall")
	var m: Dictionary = Save.d["market"]
	m["n"] = int(m.get("n", 0)) + 1
	return "M%d" % int(m["n"])

static func now() -> int:
	return int(Time.get_unix_time_from_system())

## Today as "YYYY-MM-DD" (strings compare in date order).
static func today() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%d-%02d-%02d" % [t["year"], t["month"], t["day"]]

## True (and the stored day moves on) only when today is later than the stored day: a stock bought
## out stays empty until tomorrow, and a clock set back never re-rolls it or moves the day back.
static func new_day(st: Dictionary, key := "day") -> bool:
	var day := today()
	if String(st.get(key, "")) != "" and day <= String(st[key]):
		return false
	st[key] = day
	return true

## A fee or tax on a price: rounded up, never under the minimum.
static func cut(price: int, rate: float) -> int:
	return maxi(int(Goods.rules()["fees"]["min_fee"]), int(ceil(price * rate - 0.0001)))

# ------------------------------------------------------------------ offline turnover
## One expedition's worth of time at the market (offline): NPC buyers at your stall, bids and
## endings at the auction house, NPC adopters at the shelter. After a run you made it out of, also
## the trophies and rare materials you found. Returns lines for the results screen.
static func tick(won: bool, bosses: int, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var news: Array = []
	if won:
		for key in Goods.on_result(bosses, rng):
			news.append("Found: %s (%s)." % [Goods.name_of(key), Goods.rarity_name(key)])
	for s in Stalls.tick(rng):
		var what := Goods.name_of(s["key"], s["payload"])
		news.append("Your stall sold %s for %d gems (%d after tax)." % [what, s["price"], s["paid"]])
	news.append_array(Auction.tick(rng))
	for nm in Shelter.tick(rng):
		news.append("%s found a new home from the shelter." % nm)
	return news

# ------------------------------------------------------------------ the v7 -> v8 migration
## Boki stop being sold for gems: open Drift Pens listings and web market Boki listings go back to
## their owners' rosters, the pens' save is dropped, and the market's fields get their defaults.
static func migrate(data: Dictionary) -> void:
	var back: Array = []
	var pens = data.get("pens", {})
	if typeof(pens) == TYPE_DICTIONARY:
		for L in pens.get("mine", []):
			if typeof(L) == TYPE_DICTIONARY and typeof(L.get("rec")) == TYPE_DICTIONARY: back.append(L["rec"])
	data.erase("pens")
	var listings = data.get("listings", {})
	if typeof(listings) == TYPE_DICTIONARY:
		for lid in listings.keys():
			var m = listings[lid]
			var is_boki := typeof(m) == TYPE_DICTIONARY and String(m.get("kind", "")) == "kin"
			if is_boki and typeof(m.get("rec")) == TYPE_DICTIONARY:
				back.append(m["rec"])
				listings.erase(lid)
	if typeof(data.get("roster")) != TYPE_ARRAY: data["roster"] = []
	for rec in back:
		data["roster"].append(rec)
	for rec in data["roster"]:
		if typeof(rec) == TYPE_DICTIONARY and typeof(rec.get("origin")) == TYPE_DICTIONARY:
			rec["origin"].erase("pen_line")
	if typeof(data.get("market")) != TYPE_DICTIONARY: data["market"] = fresh()
	if typeof(data.get("goods")) != TYPE_DICTIONARY: data["goods"] = {}
	if not back.is_empty():
		var names: Array = back.map(func(r): return String(r.get("name", "a Boki")))
		var who := ", ".join(names)
		data["market_notice"] = ("Boki aren't sold for gems any more: %s came back from the market to your farm. " % who
			+ "Give a Boki a new home at the Shelter, or hand it to a friend.")
