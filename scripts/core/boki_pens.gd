class_name BokiPens
## The Drift Pens: the Boki market. Every Boki is unique, so they never go on the commodity
## order book (the Exchange); they're bought and sold here as listings.
##
## Two kinds of listing:
##   "pen"    Wenna's pens: a few ordinary common Boki, restocked each day, priced within what one
##            free-kit run earns (PEN_PRICE_MIN..PEN_PRICE_MAX). This is the economy floor's market
##            (Lifeline): a player with no Boki can always afford one after a run or two.
##   "player" a Boki another player put up (with the server backend) or you put up yourself
##            (locally: your own listings wait in the pens, and Wenna's regulars buy one now and
##            then; see tick()). Asking prices must sit inside fair_range(rec).
## Filters for the list: species, size, IV total, shimmer/mutation, provenance (how it was got).
##
## Interface (the same for the local backend here and the server one, docs/EXCHANGE_SERVER.md):
##   listings(filter) -> Array[Listing]   buy(id) -> {ok, why, rec}   list_mine(uid, price) -> {ok, why, id}
##   unlist(id) -> {ok, why}   tick()   (offline day turnover)
## A Listing is {id, kind, price, rec (cleaned), seller, t}. Only BokiPens touches Save.d["pens"].
##
## Save.d["pens"] (all optional; an old save gets it on first use):
##   {day: "YYYY-MM-DD", stock: [Listing], mine: [Listing], sold: [{id, price, t}], n: id counter}

const PEN_PRICE_MIN := 30
const PEN_PRICE_MAX := 45
const PEN_STOCK := 4
const LIST_FEE := 0.05        # a listing costs 5% of its price up front (a gem sink, non-refundable)
const SALE_TAX := 0.05        # and 5% of the sale price on a sale (ROADMAP §2 market fees)
const BACKEND := "local"      # "local" today; "server" once the backend exists (docs/EXCHANGE_SERVER.md)
const MERCHANT := "Wenna"

static func _st() -> Dictionary:
	if typeof(Save.d.get("pens", null)) != TYPE_DICTIONARY:
		Save.d["pens"] = {"day": "", "stock": [], "mine": [], "sold": [], "n": 0}
	var st: Dictionary = Save.d["pens"]
	for k in ["stock", "mine", "sold"]:
		if typeof(st.get(k, null)) != TYPE_ARRAY: st[k] = []
	return st

static func _today() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%d-%02d-%02d" % [t["year"], t["month"], t["day"]]

static func _id() -> String:
	var st := _st()
	st["n"] = int(st.get("n", 0)) + 1
	return "L%d" % int(st["n"])

## What a pen Boki costs: a little more for a higher level or better IVs, always in the floor band.
static func pen_price(rec: Dictionary) -> int:
	var k := clampf((float(Care.iv_total(rec)) / float(Care.IV_MAX * Care.IV_KEYS.size())) * 0.7 + float(int(rec.get("level", 1)) - 1) * 0.15, 0.0, 1.0)
	return int(round(lerpf(PEN_PRICE_MIN, PEN_PRICE_MAX, k)))

## The cheapest Boki you can buy right now (the floor price, even when the pens are empty).
static func cheapest() -> int:
	var best := PEN_PRICE_MIN
	var st := _st()
	if not st["stock"].is_empty():
		best = 1 << 30
		for L in st["stock"]: best = mini(best, int(L["price"]))
	return best

## Fair asking prices for a player listing (anything outside is refused, by the server too).
static func fair_range(rec: Dictionary) -> Vector2i:
	var v := Ransom.value(rec)
	return Vector2i(maxi(PEN_PRICE_MIN, v / 2), v * 3)

## Fresh pen stock once a day: commons only, ordinary rolls (no shimmer, no mutations, level 1-2).
static func restock(force := false) -> void:
	var st := _st()
	var day := _today()
	if st["day"] == day and not force and not st["stock"].is_empty():
		return
	st["day"] = day
	st["stock"] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("pens|" + day + "|" + String(Save.profile().get("id", "")))
	var pool: Array = Data.common_kin()
	for i in PEN_STOCK:
		var sp := String(pool[rng.randi_range(0, pool.size() - 1)])
		var rec := Save.new_kin(sp, "", int(rng.randi() & 0x7fffffff))
		rec["level"] = rng.randi_range(1, 2)
		rec["trust"] = 25.0
		rec["shimmer"] = false
		rec.erase("mutations")
		st["stock"].append({"id": _id(), "kind": "pen", "price": pen_price(rec), "rec": rec, "seller": MERCHANT, "t": int(Time.get_unix_time_from_system())})

## Listings to show, newest pens first, then players'. filter keys (all optional): species, size
## ("XS".."XL" from Unique.size_tag), min_iv (total), special (shimmer or mutation), how (origin).
static func listings(filter := {}) -> Array:
	restock()
	var st := _st()
	var out: Array = []
	for L in st["stock"] + st["mine"]:
		if _match(L, filter): out.append(L)
	return out

static func _match(L: Dictionary, f: Dictionary) -> bool:
	var rec: Dictionary = L["rec"]
	if f.has("species") and String(f["species"]) != "" and String(rec.get("species", "")) != String(f["species"]):
		return false
	if f.has("size") and String(f["size"]) != "" and Unique.size_tag(rec) != String(f["size"]):
		return false
	if f.has("min_iv") and Care.iv_total(rec) < int(f["min_iv"]):
		return false
	if f.get("special", false) and not Mutations.special(rec):
		return false
	if f.has("how") and String(f["how"]) != "" and String((rec.get("origin", {}) as Dictionary).get("how", "")) != String(f["how"]):
		return false
	if f.has("kind") and String(f["kind"]) != "" and String(L.get("kind", "")) != String(f["kind"]):
		return false
	return true

static func find(id: String) -> Dictionary:
	var st := _st()
	for L in st["stock"] + st["mine"]:
		if String(L["id"]) == id: return L
	return {}

## Buys a listing. {ok, why, rec}.
static func buy(id: String) -> Dictionary:
	var L := find(id)
	if L.is_empty():
		return {"ok": false, "why": "That one's gone"}
	if String(L.get("kind", "")) == "player" and String(L.get("seller", "")) == "you":
		return {"ok": false, "why": "That's your own listing: take it down instead"}
	var price := int(L["price"])
	if int(Save.d.get("gems", 0)) < price:
		return {"ok": false, "why": "You need %d more gems" % (price - int(Save.d.get("gems", 0)))}
	if KinBox.full():
		return {"ok": false, "why": "The farm and the Boki Burrow are full"}
	Save.d["gems"] = int(Save.d["gems"]) - price
	_st()["stock"].erase(L)
	var rec: Dictionary = (L["rec"] as Dictionary).duplicate(true)
	rec["uid"] = Save.new_id()
	rec.erase("serial"); rec.erase("ot")
	rec["origin"] = {"how": "market", "where": {"place": "pens"}, "from": String(L.get("seller", MERCHANT)), "t": int(Time.get_unix_time_from_system())}
	Care.ensure(rec)
	Save.remember(rec, "market", "came home with you from %s's Drift Pens" % MERCHANT, 0.0)
	Save.d["roster"].append(rec)
	if Save.kin(str(Save.d.get("active", ""))).is_empty():
		Save.d["active"] = rec["uid"]
	Save.register(rec)
	KinBox.route_new(rec)
	Care.dex_got(rec)
	Save.save_game()
	return {"ok": true, "why": "", "rec": rec}

## Puts one of your Boki up at the pens. It leaves your farm while it's listed. {ok, why, id}.
static func list_mine(uid: String, price: int) -> Dictionary:
	var rec := Save.kin(uid)
	if rec.is_empty():
		return {"ok": false, "why": "No such Boki"}
	if (Save.d["roster"] as Array).size() <= 1:
		return {"ok": false, "why": "It's your only Boki"}
	var why := KinBox.pinned(rec)
	if why != "":
		return {"ok": false, "why": why}
	if rec.get("loaner", false):
		return {"ok": false, "why": "A loaner isn't yours to sell"}
	var fr := fair_range(rec)
	if price < fr.x or price > fr.y:
		return {"ok": false, "why": "Price it between %d and %d" % [fr.x, fr.y]}
	var fee := maxi(1, int(round(price * LIST_FEE)))
	if int(Save.d.get("gems", 0)) < fee:
		return {"ok": false, "why": "Listing costs %d gems" % fee}
	Save.d["gems"] = int(Save.d["gems"]) - fee
	Save.d["roster"].erase(rec)
	for k in ["active", "active2"]:
		if String(Save.d.get(k, "")) == uid: Save.d[k] = ""
	var L := {"id": _id(), "kind": "player", "price": price, "rec": rec, "seller": "you", "t": int(Time.get_unix_time_from_system())}
	_st()["mine"].append(L)
	Save.log_event("listed", rec, {"price": price})
	Save.save_game()
	return {"ok": true, "why": "", "id": String(L["id"]), "fee": fee}

## Takes your listing down: the Boki comes back exactly as it was. {ok, why}.
static func unlist(id: String) -> Dictionary:
	var st := _st()
	for L in st["mine"]:
		if String(L["id"]) == id:
			st["mine"].erase(L)
			var rec: Dictionary = L["rec"]
			Save.d["roster"].append(rec)
			if Save.kin(str(Save.d.get("active", ""))).is_empty(): Save.d["active"] = rec["uid"]
			KinBox.route_back(rec)
			Save.save_game()
			return {"ok": true, "why": ""}
	return {"ok": false, "why": "Not your listing"}

## One expedition's worth of time at the pens (offline only): now and then one of your listings
## sells to Wenna's regulars (more likely the closer to fair value it's priced), paying out less tax.
## Returns what sold: [{rec, price, paid}].
static func tick(rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new(); rng.randomize()
	var st := _st()
	var sold: Array = []
	for L in st["mine"].duplicate():
		var v := float(Ransom.value(L["rec"]))
		var chance := clampf(0.55 - (float(L["price"]) - v) / maxf(1.0, v) * 0.5, 0.05, 0.8)
		if rng.randf() < chance:
			st["mine"].erase(L)
			var paid := int(L["price"]) - int(round(int(L["price"]) * SALE_TAX))
			Save.d["gems"] = int(Save.d.get("gems", 0)) + paid
			st["sold"].append({"id": L["id"], "price": int(L["price"]), "t": int(Time.get_unix_time_from_system())})
			while (st["sold"] as Array).size() > 30: (st["sold"] as Array).pop_front()
			Save.log_event("sold", L["rec"], {"price": int(L["price"]), "to": "market"})
			sold.append({"rec": L["rec"], "price": int(L["price"]), "paid": paid})
	return sold
