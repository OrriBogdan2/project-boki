class_name Exchange
## The Tradewind Exchange: an order book for basic materials (owner decision, Nov 1; ROADMAP §2).
## Players post buy and sell offers at a price per unit; offers match price-time (the best price
## first, then the oldest), with partial fills, and a small tax on each fill is a gem sink. Every
## fill goes into a price history, which the screen draws as a graph. Boki are never on the book:
## each is unique, and they are never sold for gems (the Shelter and transfers, docs/decisions/0013-market.md).
##
## What trades (COMMODITIES): wood, stone, scrap, crops, Boki food, tonics. Each has a home in the
## save (Save.d mats / crops / items / scrap); take() and give() are the only places that touch it.
## Gems are escrowed when a buy offer is posted and goods when a sell offer is posted, so an open
## offer can always settle.
##
## Backends (same interface either way):
##   "local"  today. Your own offers rest on a book with Tradewind's market makers (MAKERS), whose
##            standing offers sit around a reference price and drift each day. Matching runs here.
##   "server" later (docs/EXCHANGE_SERVER.md): the private backend owns the book and the ledger; the
##            client only sends post/cancel requests and reads the book, fills and history. Nothing
##            on the client is trusted: these same functions become thin request wrappers.
## Interface: post(side, item, qty, price) -> {ok, why, id, filled}   cancel(id) -> {ok, why}
##   book(item) -> {buys: [[price, qty]], sells: [[price, qty]]}   mine() -> [Offer]
##   history(item) -> [[t, price, qty]]   tick() -> fills of resting offers since last time
## An Offer is {id, side: "buy"|"sell", item, qty, left, price, t, who: "you"|maker id}.
##
## Save.d["exchange"] (optional; an old save gets it on first use):
##   {day, n, book: {item: [Offer]}, hist: {item: [[t, price, qty]]}, fills: [...]}

const BACKEND := "local"
const TAX := 0.04              # of the gems in each fill, paid by the seller: the Exchange's sink
const MAX_OPEN := 8            # your open offers at once
const HIST_CAP := 60
const WALK := 0.15             # offline, Tradewind's quotes walk at most this far from the middle of the book per run
                               # (so an offer priced further out than this never fills)
const MAKER_DEPTH := 3         # market maker levels each side
const PRICE_BAND := [0.4, 2.5] # offers must be within this times the reference price

## item -> {name, ref (gems per unit), store: mats|crops|items|scrap, key}
const COMMODITIES := {
	"wood": {"name": "Wood", "ref": 3, "store": "mats", "key": "wood", "icon": "dash", "col": Color("b0784a")},
	"stone": {"name": "Stone", "ref": 4, "store": "mats", "key": "stone", "icon": "fortify", "col": Color("a8b0c4")},
	"scrap": {"name": "Scrap", "ref": 6, "store": "scrap", "key": "scrap", "icon": "hammer", "col": Color("c8a07a")},
	"tidebloom": {"name": "Tidebloom", "ref": 6, "store": "crops", "key": "tidebloom", "icon": "seed", "col": Color("5ab8f0")},
	"sunroot": {"name": "Sunroot", "ref": 9, "store": "crops", "key": "sunroot", "icon": "seed", "col": Color("f2c84a")},
	"puffcorn": {"name": "Puffcorn", "ref": 4, "store": "crops", "key": "puffcorn", "icon": "seed", "col": Color("f6e3a8")},
	"emberberry": {"name": "Emberberry", "ref": 10, "store": "crops", "key": "emberberry", "icon": "seed", "col": Color("ff6a4a")},
	"kibble": {"name": "Boki kibble", "ref": 5, "store": "items", "key": "kibble", "icon": "heart", "col": Color("c8a26a")},
	"tonic": {"name": "Tonic", "ref": 22, "store": "items", "key": "tonic", "icon": "tonic", "col": Color("8fe0a0")},
}
const ORDER := ["wood", "stone", "scrap", "kibble", "tonic", "tidebloom", "puffcorn", "sunroot", "emberberry"]

static func _st() -> Dictionary:
	if typeof(Save.d.get("exchange", null)) != TYPE_DICTIONARY:
		Save.d["exchange"] = {"day": "", "n": 0, "book": {}, "hist": {}, "fills": [], "seen": 0}
	var st: Dictionary = Save.d["exchange"]
	for k in ["book", "hist"]:
		if typeof(st.get(k, null)) != TYPE_DICTIONARY: st[k] = {}
	if typeof(st.get("fills", null)) != TYPE_ARRAY: st["fills"] = []
	return st

static func _id() -> String:
	var st := _st()
	st["n"] = int(st.get("n", 0)) + 1
	return "X%d" % int(st["n"])

static func _now() -> int:
	return int(Time.get_unix_time_from_system())

static func name_of(item: String) -> String:
	return String(COMMODITIES.get(item, {}).get("name", item))

# ------------------------------------------------------------------ what you hold
## How many of a commodity you have (not counting what's escrowed in your sell offers).
static func have(item: String) -> int:
	var c: Dictionary = COMMODITIES.get(item, {})
	if c.is_empty(): return 0
	match String(c["store"]):
		"mats": return int((Save.d.get("mats", {}) as Dictionary).get(c["key"], 0))
		"crops": return int((Save.d.get("crops", {}) as Dictionary).get(c["key"], 0))
		"items": return int((Save.d.get("items", {}) as Dictionary).get(c["key"], 0))
		"scrap": return int(Save.d.get("scrap", 0))
	return 0

static func _add(item: String, n: int) -> void:
	var c: Dictionary = COMMODITIES[item]
	match String(c["store"]):
		"mats":
			if typeof(Save.d.get("mats", null)) != TYPE_DICTIONARY: Save.d["mats"] = {}
			Save.d["mats"][c["key"]] = maxi(0, int(Save.d["mats"].get(c["key"], 0)) + n)
		"crops":
			if typeof(Save.d.get("crops", null)) != TYPE_DICTIONARY: Save.d["crops"] = {}
			Save.d["crops"][c["key"]] = maxi(0, int(Save.d["crops"].get(c["key"], 0)) + n)
		"items":
			Save.d["items"][c["key"]] = maxi(0, int(Save.d["items"].get(c["key"], 0)) + n)
		"scrap":
			Save.d["scrap"] = maxi(0, int(Save.d.get("scrap", 0)) + n)

# ------------------------------------------------------------------ the book
static func _book(item: String) -> Array:
	var st := _st()
	if typeof(st["book"].get(item, null)) != TYPE_ARRAY: st["book"][item] = []
	return st["book"][item]

## The reference price today: the last trade, or the base price.
static func ref_price(item: String) -> int:
	var h: Array = history(item)
	if not h.is_empty(): return int(h[h.size() - 1][1])
	return int(COMMODITIES[item]["ref"])

static func band(item: String) -> Vector2i:
	var r := int(COMMODITIES[item]["ref"])
	return Vector2i(maxi(1, int(floor(r * PRICE_BAND[0]))), int(ceil(r * PRICE_BAND[1])))

## Tradewind's market makers: a few standing offers each side round today's price. Rebuilt once a
## day (and whenever a side has run dry), so the book never empties and prices drift a little.
static func _makers(item: String, force := false) -> void:
	var book := _book(item)
	var buys := book.filter(func(o): return o["side"] == "buy" and String(o["who"]) != "you")
	var sells := book.filter(func(o): return o["side"] == "sell" and String(o["who"]) != "you")
	if not force and not buys.is_empty() and not sells.is_empty():
		return
	for o in buys + sells: book.erase(o)
	var st := _st()
	var rng := RandomNumberGenerator.new()
	# today's middle comes from the item's base price and the day alone: not from the last trade or
	# from a counter, so buying a side out and refilling it never ratchets the price (and a refill
	# is the same quotes as before, at the same spread)
	rng.seed = hash("xch|%s|%s" % [item, String(st.get("day", ""))])
	var b := band(item)
	var mid := clampi(int(round(float(COMMODITIES[item]["ref"]) * rng.randf_range(0.92, 1.08))), b.x + 1, b.y - 1)
	for i in MAKER_DEPTH:
		var gap := 1 + i
		book.append({"id": _id(), "side": "buy", "item": item, "qty": 20 + 10 * i, "left": 20 + 10 * i, "price": maxi(b.x, mid - gap), "t": _now() - 100 + i, "who": "tw"})
		book.append({"id": _id(), "side": "sell", "item": item, "qty": 20 + 10 * i, "left": 20 + 10 * i, "price": mini(b.y, mid + gap), "t": _now() - 100 + i, "who": "tw"})

static func _day_turn() -> void:
	var st := _st()
	var t := Time.get_datetime_dict_from_system()
	var day := "%d-%02d-%02d" % [t["year"], t["month"], t["day"]]
	if String(st["day"]) == day:
		return
	st["day"] = day
	for item in COMMODITIES: _makers(item, true)

## The book for one item, aggregated by price: best first on each side.
static func book(item: String) -> Dictionary:
	_day_turn()
	_makers(item)
	var buys := {}; var sells := {}
	for o in _book(item):
		var dst: Dictionary = buys if o["side"] == "buy" else sells
		dst[int(o["price"])] = int(dst.get(int(o["price"]), 0)) + int(o["left"])
	var bk: Array = buys.keys(); bk.sort(); bk.reverse()
	var sk: Array = sells.keys(); sk.sort()
	return {"buys": bk.map(func(p): return [p, buys[p]]), "sells": sk.map(func(p): return [p, sells[p]])}

## The middle of the book (between the best bid and the best ask): what a fair offer looks like now.
static func mid(item: String) -> float:
	book(item)        # (today's makers in place)
	var b := -1; var a := 1 << 30
	for o in _book(item):
		if String(o["who"]) == "you": continue      # your own offers don't move what's fair
		if o["side"] == "buy": b = maxi(b, int(o["price"]))
		else: a = mini(a, int(o["price"]))
	if b < 0 or a == 1 << 30: return float(ref_price(item))
	return (b + a) * 0.5

static func best(item: String, side: String) -> int:
	var b := book(item)
	var rows: Array = b["buys" if side == "buy" else "sells"]
	return int(rows[0][0]) if not rows.is_empty() else -1

static func mine() -> Array:
	var out: Array = []
	for item in _st()["book"]:
		for o in _book(item):
			if String(o["who"]) == "you": out.append(o)
	return out

static func history(item: String) -> Array:
	var h = _st()["hist"].get(item, null)
	return h if typeof(h) == TYPE_ARRAY else []

static func _record(item: String, price: int, qty: int) -> void:
	var st := _st()
	if typeof(st["hist"].get(item, null)) != TYPE_ARRAY: st["hist"][item] = []
	var h: Array = st["hist"][item]
	h.append([_now(), price, qty])
	while h.size() > HIST_CAP: h.pop_front()

# ------------------------------------------------------------------ posting and matching
## Posts an offer. Buying escrows qty * price gems; selling escrows the goods. It matches right away
## against the other side at the resting offers' prices (price-time), and anything left rests on the
## book. Returns {ok, why, id, filled, spent|got}.
static func post(side: String, item: String, qty: int, price: int) -> Dictionary:
	if not COMMODITIES.has(item):
		return {"ok": false, "why": "That isn't traded here"}
	if side != "buy" and side != "sell":
		return {"ok": false, "why": "Buy or sell?"}
	if qty <= 0 or qty > 999:
		return {"ok": false, "why": "Between 1 and 999"}
	var b := band(item)
	if price < b.x or price > b.y:
		return {"ok": false, "why": "Price it between %d and %d gems each" % [b.x, b.y]}
	if mine().size() >= MAX_OPEN:
		return {"ok": false, "why": "You have %d offers open already" % MAX_OPEN}
	if side == "buy":
		if int(Save.d.get("gems", 0)) < qty * price:
			return {"ok": false, "why": "You need %d gems for that" % (qty * price)}
		Save.d["gems"] = int(Save.d["gems"]) - qty * price
	else:
		if have(item) < qty:
			return {"ok": false, "why": "You have %d %s" % [have(item), name_of(item)]}
		_add(item, -qty)
	_day_turn()
	_makers(item)
	var o := {"id": _id(), "side": side, "item": item, "qty": qty, "left": qty, "price": price, "t": _now(), "who": "you", "got": 0, "spent": 0}
	var filled := _match(o)
	if int(o["left"]) > 0:
		_book(item).append(o)
	Save.save_game()
	return {"ok": true, "why": "", "id": String(o["id"]), "filled": filled, "left": int(o["left"])}

## Matches an incoming offer against resting ones. Returns how many units filled.
static func _match(o: Dictionary) -> int:
	var item := String(o["item"])
	var book := _book(item)
	var buy: bool = o["side"] == "buy"
	var others: Array = book.filter(func(x): return x["side"] != o["side"] and String(x["who"]) != String(o["who"]))
	# best price first, then the oldest
	others.sort_custom(func(a, b):
		if int(a["price"]) != int(b["price"]):
			return int(a["price"]) < int(b["price"]) if buy else int(a["price"]) > int(b["price"])
		return int(a["t"]) < int(b["t"]))
	var filled := 0
	for r in others:
		if int(o["left"]) <= 0: break
		if buy and int(r["price"]) > int(o["price"]): break
		if not buy and int(r["price"]) < int(o["price"]): break
		var q := mini(int(o["left"]), int(r["left"]))
		var px := int(r["price"])        # the resting offer's price
		_fill(o if buy else r, r if buy else o, item, q, px)
		filled += q
		if int(r["left"]) <= 0: book.erase(r)
	return filled

## The tax on one fill, rounded up so a small fill still pays something (4% of 12 gems is 1, not 0).
static func tax_of(gems: int) -> int:
	return int(ceil(gems * TAX - 0.0001))

## One fill between a buyer and a seller offer at px per unit.
static func _fill(b: Dictionary, s: Dictionary, item: String, q: int, px: int) -> Dictionary:
	b["left"] = int(b["left"]) - q
	s["left"] = int(s["left"]) - q
	var gems := q * px
	var tax := tax_of(gems)
	if String(b["who"]) == "you":
		# the gems were escrowed at the buyer's own price: the difference comes back
		_add(item, q)
		Save.d["gems"] = int(Save.d.get("gems", 0)) + q * (int(b["price"]) - px)
		b["got"] = int(b.get("got", 0)) + q
		b["spent"] = int(b.get("spent", 0)) + gems
	if String(s["who"]) == "you":
		Save.d["gems"] = int(Save.d.get("gems", 0)) + gems - tax
		s["got"] = int(s.get("got", 0)) + gems - tax
	_record(item, px, q)
	var st := _st()
	var rec := {}
	if String(b["who"]) == "you" or String(s["who"]) == "you":
		rec = {"t": _now(), "item": item, "qty": q, "price": px, "side": "buy" if String(b["who"]) == "you" else "sell", "tax": tax if String(s["who"]) == "you" else 0}
		st["fills"].append(rec)
		while (st["fills"] as Array).size() > 40: (st["fills"] as Array).pop_front()
	st["taxed"] = int(st.get("taxed", 0)) + tax
	return rec

## Takes an open offer down; what's left in escrow comes back. {ok, why}.
static func cancel(id: String) -> Dictionary:
	for item in _st()["book"]:
		var book := _book(item)
		for o in book:
			if String(o["id"]) == id and String(o["who"]) == "you":
				book.erase(o)
				if o["side"] == "buy": Save.d["gems"] = int(Save.d.get("gems", 0)) + int(o["left"]) * int(o["price"])
				else: _add(item, int(o["left"]))
				Save.save_game()
				return {"ok": true, "why": ""}
	return {"ok": false, "why": "Not your offer"}

## Time passes (once per expedition, offline). Tradewind's traders walk their quotes a random way
## up or down (at most WALK of the middle of the book) and your resting offers fill at THE TRADER'S
## quote, only when that quote reaches your price (so you never get worse than you asked, and never
## better than the walk). An offer priced more than WALK from the middle has no chance at all. The
## offline traders' spread is wider than the book makers' (at least 8% of the middle each way), so
## buying off the book and selling back by tick never turns a profit. Returns new fills of your offers.
static func tick(rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new(); rng.randomize()
	var new_fills: Array = []      # (not a slice of the fills log: that is capped, and the cap would hide new ones)
	for o in mine():
		var item := String(o["item"])
		var m := mid(item)
		var price := int(o["price"])
		if absf(float(price) - m) > m * WALK:
			continue
		var buying: bool = o["side"] == "buy"
		var gap := maxi(1, int(ceil(m * 0.08)))
		var walked := int(round(m * (1.0 + rng.randf_range(-WALK, WALK))))
		var px := walked + gap if buying else walked - gap
		if (buying and px > price) or (not buying and px < price):
			continue
		var q := mini(int(o["left"]), maxi(1, int(ceil(int(o["left"]) * rng.randf_range(0.4, 1.0)))))
		var other := {"id": _id(), "side": "sell" if buying else "buy", "item": item, "qty": q, "left": q, "price": px, "t": _now(), "who": "tw"}
		var f := _fill(o if buying else other, other if buying else o, item, q, px)
		if not f.is_empty(): new_fills.append(f)
		if int(o["left"]) <= 0: _book(item).erase(o)
	return new_fills

## Gems taken by the Exchange's tax, in all (for the economy check and telemetry later).
static func taxed() -> int:
	return int(_st().get("taxed", 0))
