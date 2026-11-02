extends RefCounted
## --economy-floor-check: nobody is ever left with no Boki, no gems and no way to play (Lifeline),
## the Drift Pens (BokiPens), the free-kit run with a loaner Boki (Loaner), the Exchange order book
## (Exchange), and save/load for all of it (old saves too).
## Prints FLOOR ok/FAIL lines and "FLOOR DONE, failures: N".

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FLOOR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(host: Node) -> void:
	main = host
	Save.no_write = true
	_zero_zero()
	_pens()
	_pen_listing()
	_pens_restock()
	_pens_no_mint()
	_pens_gems()
	await _loaner_match()
	_loaner_result()
	_exchange()
	_exchange_book()
	_exchange_walk()
	_save_load()
	print("FLOOR DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

func _started_save() -> void:
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["hatched"] = true
	Save.d["matches"] = 3

## The edge case: zero Boki and zero gems.
func _zero_zero() -> void:
	# a brand-new save is in the starter flow: no stray, the egg is its floor
	Save.d = Save.fresh()
	ok(Lifeline.check().is_empty() and Save.d["roster"].is_empty(), "a new save gets its starter egg, not a stray")
	_started_save()
	Save.d["roster"] = []
	Save.d["gems"] = 0
	Save.d["active"] = ""
	ok(Lifeline.stuck(), "zero Boki and zero gems is the stuck state")
	ok(Lifeline.can_play() and Loaner.available(), "even then you can play: the free-kit run is open")
	ok(BokiPens.cheapest() <= Loaner.MIN_PAY, "the cheapest pen Boki (%d) costs no more than one free-kit extract pays (%d)" % [BokiPens.cheapest(), Loaner.MIN_PAY])
	var ev := Lifeline.check()
	ok(ev.size() == 1 and String(ev[0]["kind"]) == "stray" and Save.d["roster"].size() == 1, "a stray Boki turns up at the farm")
	var st: Dictionary = Save.d["roster"][0]
	ok(not Data.is_rare(String(st["species"])) and not Mutations.special(st), "the stray is an ordinary common (%s)" % st["species"])
	ok(Save.active_kin() == st and st.has("serial") and String(st["origin"]["how"]) == "stray", "it's your partner, registered as a stray")
	ok(Lifeline.check().is_empty(), "with a Boki again, nothing more is given")
	ok(not Lifeline.stuck(), "and you're not stuck any more")
	# you can't get to zero on purpose: your last Boki can't be released or listed
	ok(KinBox.release(st) != "", "your last Boki can't be released (%s)" % KinBox.release(st))
	Save.d["gems"] = 999
	ok(not BokiPens.list_mine(String(st["uid"]), 60)["ok"], "nor listed at the pens")
	# losing your only Boki after a run: the Ransom House lets it go on credit (existing rule) and
	# the floor is there behind it
	_started_save()
	var only := Save.new_kin("cindle", "Pip")
	Save.d["roster"] = [only]; Save.d["active"] = only["uid"]; Save.d["gems"] = 0
	var out := Game.apply_result({"extracted": false, "why": "knocked out", "tier": 2, "kin_runs": [{"uid": only["uid"], "events": [], "trust": 40.0, "stats": {}}],
		"lost_kin": [{"uid": only["uid"], "fate": "rival", "holder": "Vexa"}]})
	ok(Save.d["roster"].size() >= 1, "after losing your only Boki to a rival you still have one (%d, stranded %s, floor %s)" % [Save.d["roster"].size(), str(out.get("kin_stranded", false)), str((out.get("floor", []) as Array).map(func(e): return e["kind"]))])
	# a Boki that starved with nobody left: the floor brings a stray
	_started_save()
	var lone := Save.new_kin("puddlet", "Lone")
	Save.d["roster"] = [lone]; Save.d["active"] = lone["uid"]; Save.d["gems"] = 0
	Econ.kin_dies(lone, "starved")
	ok(Save.d["roster"].is_empty(), "(the last Boki starved)")
	ok(Lifeline.check().size() == 1 and Save.d["roster"].size() == 1, "a stray turns up after the last Boki starves")

func _pens() -> void:
	_started_save()
	Save.d["roster"] = [Save.new_kin("cindle", "Pip")]
	Save.d["active"] = Save.d["roster"][0]["uid"]
	var ls := BokiPens.listings()
	ok(ls.size() == BokiPens.PEN_STOCK, "the pens have %d Boki today" % ls.size())
	ok(ls.all(func(L): return int(L["price"]) >= BokiPens.PEN_PRICE_MIN and int(L["price"]) <= BokiPens.PEN_PRICE_MAX), "all priced %d-%d: %s" % [BokiPens.PEN_PRICE_MIN, BokiPens.PEN_PRICE_MAX, str(ls.map(func(L): return L["price"]))])
	ok(ls.all(func(L): return not Data.is_rare(String(L["rec"]["species"])) and not Mutations.special(L["rec"])), "commons only, ordinary rolls")
	var again := BokiPens.listings()
	ok(again.map(func(L): return L["id"]) == ls.map(func(L): return L["id"]), "the same stock all day")
	var sp0 := String(ls[0]["rec"]["species"])
	ok(BokiPens.listings({"species": sp0}).all(func(L): return String(L["rec"]["species"]) == sp0), "filter by species")
	ok(BokiPens.listings({"min_iv": 200}).is_empty() or BokiPens.listings({"min_iv": 200}).all(func(L): return Care.iv_total(L["rec"]) >= 200), "filter by IVs")
	Save.d["gems"] = 10
	var r := BokiPens.buy(String(ls[0]["id"]))
	ok(not r["ok"] and Save.d["roster"].size() == 1, "can't buy without the gems (%s)" % r["why"])
	Save.d["gems"] = 100
	var price := int(ls[0]["price"])
	r = BokiPens.buy(String(ls[0]["id"]))
	ok(r["ok"] and Save.d["roster"].size() == 2 and int(Save.d["gems"]) == 100 - price, "bought one for %d gems" % price)
	var nk: Dictionary = r.get("rec", {})
	ok(String(nk.get("origin", {}).get("how", "")) == "market" and nk.has("serial") and String(nk["uid"]) != String(ls[0]["rec"]["uid"]), "a new id, registered, from the market")
	ok(BokiPens.listings().size() == BokiPens.PEN_STOCK - 1, "it's gone from the pens")
	ok(Save.d["roster"].has(nk) and String(Save.d.get("active", "")) != String(nk["uid"]), "it goes to the farm roster; your active Boki stays your pick, nothing joins a match")
	ok(not BokiPens.buy(String(ls[0]["id"]))["ok"], "can't buy it twice")

func _pen_listing() -> void:
	_started_save()
	var a := Save.new_kin("cindle", "Pip"); a["level"] = 4
	var b := Save.new_kin("burrlet", "Bun")
	Save.d["roster"] = [a, b]; Save.d["active"] = b["uid"]; Save.d["gems"] = 100
	var fr := BokiPens.fair_range(a)
	ok(not BokiPens.list_mine(String(a["uid"]), fr.y + 50)["ok"], "a listing outside the fair range is refused (%d-%d)" % [fr.x, fr.y])
	var price := Ransom.value(a)
	var r := BokiPens.list_mine(String(a["uid"]), price)
	var fee := int(r.get("fee", 0))
	ok(fee == maxi(1, int(round(price * 0.05))) and BokiPens.LIST_FEE == 0.05, "the listing fee is 5%% of the price (%d of %d)" % [fee, price])
	ok(r["ok"] and Save.d["roster"].size() == 1 and int(Save.d["gems"]) == 100 - fee, "listed for %d (fee %d); it leaves the farm" % [price, fee])
	ok(BokiPens.listings({"kind": "player"}).size() == 1, "it shows in the pens")
	ok(not BokiPens.buy(String(r["id"]))["ok"], "you can't buy your own listing")
	var u := BokiPens.unlist(String(r["id"]))
	ok(u["ok"] and Save.d["roster"].size() == 2 and Save.kin(String(a["uid"])) == a, "taking it down brings exactly it back")
	# offline turnover: a fair listing sells over a few expeditions, paying out less tax
	r = BokiPens.list_mine(String(a["uid"]), price)
	var g0 := int(Save.d["gems"])
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var sold: Array = []
	for i in 10:
		sold = BokiPens.tick(rng)
		if not sold.is_empty(): break
	var paid := int(sold[0]["paid"]) if not sold.is_empty() else 0
	ok(not sold.is_empty() and int(Save.d["gems"]) == g0 + paid and paid == price - int(round(price * BokiPens.SALE_TAX)), "it sells, paying %d (5%% tax)" % paid)
	ok(Save.kin(String(a["uid"])).is_empty(), "and it's gone for good")
	ok(not BokiPens.list_mine(String(b["uid"]), 60)["ok"], "your only Boki can't be listed")

func _loaner_match() -> void:
	_started_save()
	var mine := Save.new_kin("cindle", "Pip")
	Save.d["roster"] = [mine]; Save.d["active"] = mine["uid"]
	Save.d["items"]["tonic"] = 5; Save.d["items"]["rift_key"] = 2; Save.d["treat"] = "treat_power"
	var arm_w := {"uid": "arm_w", "t": "weapon", "rar": 2, "id": "test_blade"}
	Save.d["armory"] = [arm_w]; Save.d["loadout"] = {"weapon": "arm_w"}
	var m := Match.new()
	main.add_child(m)
	var o := Loaner.opts({"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 12, "no_drop": true}, 4)
	m.start(o)
	m.set_process(false)
	var P := m.player
	var k: Kin = P.kin
	ok(k != null and Loaner.is_loaner(k.rec) and String(k.rec["uid"]) != String(mine["uid"]), "a free-kit run brings a loaner Boki, not yours (%s)" % (k.species if k else "none"))
	ok(P.kin2 == null and k != null and k.owner_h == P and k.cmd == "follow", "the loaner is the one active Boki and follows like any other (%s)" % (k.cmd if k else "none"))
	ok(k != null and k.species in Loaner.STARTERS and int(k.rec["level"]) == 1, "a starter egg's species, level 1")
	ok(P.rift_keys == 0 and P.tonics == 2, "the basic kit: two free tonics, no keys (%d, %d)" % [P.tonics, P.rift_keys])
	ok(Loot.of_hand(P).is_empty() or int(Loot.of_hand(P).get("rar", 0)) == 0, "the plain class weapon")
	ok(Save.d["armory"] == [arm_w] and Save.d["loadout"] == {"weapon": "arm_w"} and Save.d["raid_out"].is_empty(), "your armory and loadout stay home (nothing left the armory)")
	# die in the Hollow: the loaner never drops into the box or is left behind
	P.lives = 1
	m.eliminate(P, null, "knocked out", true)
	var bx := Life.box_of(m, P)
	var in_box: bool = not bx.is_empty() and (bx.get("kin", []) as Array).any(func(r): return Loaner.is_loaner(r))
	ok(not in_box and m.player_lost.is_empty(), "dying in the Hollow, the loaner isn't in your box or left behind")
	ok(not m.kins.any(func(w): return w.is_wild() and not w.dead and Loaner.is_loaner(w.rec)), "and nobody can capture it")
	m.result = {"extracted": false, "why": "knocked out"}
	P.tonics += 3      # three tonics found on the run
	var r := _result_of(m)
	ok(r.get("loaner", false) and (r.get("kin_runs", []) as Array).is_empty() and not r.has("lost_kin"), "the result carries no loaner Boki")
	ok(int(r.get("tonics", -1)) == 5 + 3, "the tonics found on a free-kit run come home with the stash (%d, want 8)" % int(r.get("tonics", -1)))
	ok(not r.has("rift_keys"), "no Rift Keys in a free-kit result")
	# a freed Boki node (a loaner that was removed from the match) doesn't break leaving or finishing
	if k != null and is_instance_valid(k):
		k.free()      # P.kin now points at a freed node
		m._leave_kin(P)
		var r2 := _result_of(m)
		ok((r2.get("kin_runs", []) as Array).is_empty(), "a freed Boki node is skipped when leaving and finishing (no crash)")
	m.free()      # (not queue_free: the HUD would draw a frame with the freed node)
	await main.get_tree().process_frame

## The result dict Match._finish would hand to Game, without switching screens.
func _result_of(m: Match) -> Dictionary:
	var captured := {}
	var g = Game.main
	Game.main = null
	var old := Game.last_result
	m._finish()
	captured = Game.last_result
	Game.last_result = old
	Game.main = g
	return captured

func _loaner_result() -> void:
	_started_save()
	var mine := Save.new_kin("cindle", "Pip")
	mine["trust"] = 50.0
	Save.d["roster"] = [mine]; Save.d["active"] = mine["uid"]
	Save.d["items"]["tonic"] = 5; Save.d["items"]["rift_key"] = 2; Save.d["gems"] = 0; Save.d["treat"] = "treat_power"
	var arm_w := {"uid": "arm_w", "t": "weapon", "rar": 2, "id": "test_blade"}
	Save.d["armory"] = [arm_w]; Save.d["loadout"] = {"weapon": "arm_w"}
	var trust0 := float(mine["trust"]); var xp0 := int(mine.get("xp", 0)); var m0 := int(mine.get("matches", 0))
	# extracted with a little: the stipend tops it up to MIN_PAY
	var out := Game.apply_result({"extracted": true, "loaner": true, "tier": 0, "gems": 12, "tonics": 5, "kin_runs": [], "caught": []})
	ok(int(Save.d["gems"]) == Loaner.MIN_PAY and int(out["stipend"]) == Loaner.MIN_PAY - 12, "an extract pays at least %d gems (stipend %d)" % [Loaner.MIN_PAY, int(out["stipend"])])
	ok(float(mine["trust"]) == trust0 and int(mine.get("xp", 0)) == xp0 and int(mine.get("matches", 0)) == m0, "your own Boki is untouched (it stayed home)")
	ok(Save.d["roster"].size() == 1 and not Save.d["roster"].any(func(r): return Loaner.is_loaner(r)), "the loaner is never kept")
	ok(int(Save.d["items"]["tonic"]) == 5 and int(Save.d["items"]["rift_key"]) == 2, "your tonics and keys are untouched")
	ok(String(Save.d["treat"]) == "treat_power", "your treat is kept on a free-kit run (it was never used)")
	ok(Save.d["armory"] == [arm_w] and Save.d["loadout"] == {"weapon": "arm_w"}, "your armory and loadout are untouched")
	# died: nothing of yours lost, no ransom
	out = Game.apply_result({"extracted": false, "why": "knocked out", "loaner": true, "tier": 2, "gems": 30, "lost_gems": 30, "tonics": 5, "kin_runs": [],
		"lost_kin": [{"uid": "x", "fate": "rival", "holder": "Vexa", "rec": Loaner.roll(3)}]})
	ok(Save.d["roster"].size() == 1 and (Save.d["lost_kin"] as Array).is_empty() and int(out["stipend"]) == 0, "dying on a free-kit run loses nothing of yours")
	ok(String(Save.d["treat"]) == "treat_power" and Save.d["armory"] == [arm_w] and Save.d["loadout"] == {"weapon": "arm_w"}, "...nor your treat, armory or loadout")
	# the stipend is a floor, not a bonus: nothing is topped up at MIN_PAY or more
	for g in [Loaner.MIN_PAY, Loaner.MIN_PAY + 1, 200]:
		var rr := {"extracted": true, "loaner": true, "gems": g}
		ok(Loaner.settle(rr) == 0 and int(rr["gems"]) == g, "an extract of %d gems isn't topped up" % g)
	var rl := {"extracted": true, "loaner": true, "gems": Loaner.MIN_PAY - 1}
	ok(Loaner.settle(rl) == 1 and int(rl["gems"]) == Loaner.MIN_PAY, "one gem short is topped up by one")
	_started_save()
	var g45 := Save.new_kin("cindle", "Pip")
	Save.d["roster"] = [g45]; Save.d["active"] = g45["uid"]; Save.d["gems"] = 10; Save.d["treat"] = "treat_power"
	out = Game.apply_result({"extracted": true, "loaner": true, "tier": 0, "gems": Loaner.MIN_PAY + 5, "kin_runs": [], "caught": []})
	ok(int(out["stipend"]) == 0 and int(Save.d["gems"]) == 10 + Loaner.MIN_PAY + 5, "through apply_result too: %d gems in, no top-up" % (Loaner.MIN_PAY + 5))
	# (and a normal run does use up the treat)
	Game.apply_result({"extracted": false, "why": "left", "tier": 0, "gems": 0, "kin_runs": [], "caught": []})
	ok(String(Save.d["treat"]) == "", "a normal run uses the treat up")
	# the zero-zero player: one free-kit run buys a pen Boki
	_started_save()
	Save.d["roster"] = []; Save.d["gems"] = 0; Save.d["active"] = ""
	Save.d["floor"] = {"strays": 0, "last_m": -1}
	Game.apply_result({"extracted": true, "loaner": true, "tier": 0, "gems": 0, "kin_runs": [], "caught": []})
	var have: int = Save.d["roster"].size()
	var cheap: Dictionary = BokiPens.listings().reduce(func(a, L): return L if a.is_empty() or int(L["price"]) < int(a["price"]) else a, {})
	var r := BokiPens.buy(String(cheap["id"]))
	ok(r["ok"] and Save.d["roster"].size() == have + 1, "from zero: one free-kit extract buys a Boki at the pens (%d gems)" % int(cheap["price"]))

func _exchange() -> void:
	_started_save()
	Save.d["gems"] = 500
	Work.ensure()
	Save.d["mats"]["wood"] = 40
	var bk := Exchange.book("wood")
	ok(not bk["buys"].is_empty() and not bk["sells"].is_empty(), "the book has both sides (market makers)")
	var bid := Exchange.best("wood", "buy"); var ask := Exchange.best("wood", "sell")
	ok(bid < ask, "best bid %d < best ask %d" % [bid, ask])
	# a sell at the bid fills straight away at the bid, less tax
	var g0 := int(Save.d["gems"])
	var r := Exchange.post("sell", "wood", 10, bid)
	var tax := Exchange.tax_of(10 * bid)
	ok(r["ok"] and int(r["filled"]) == 10 and int(Save.d["mats"]["wood"]) == 30 and int(Save.d["gems"]) == g0 + 10 * bid - tax, "selling 10 wood at %d fills now: +%d gems after %d tax" % [bid, 10 * bid - tax, tax])
	ok(Exchange.history("wood").size() >= 1 and int(Exchange.history("wood").back()[1]) == bid, "the trade is in the price history")
	# a buy below the ask rests (gems in escrow) and can be cancelled
	g0 = int(Save.d["gems"])
	r = Exchange.post("buy", "wood", 5, Exchange.best("wood", "buy"))
	var price := Exchange.best("wood", "buy")
	ok(r["ok"] and int(r["filled"]) == 0 and Exchange.mine().size() == 1 and int(Save.d["gems"]) == g0 - 5 * price, "a low bid rests with %d gems in escrow" % (5 * price))
	var c := Exchange.cancel(String(r["id"]))
	ok(c["ok"] and Exchange.mine().is_empty() and int(Save.d["gems"]) == g0, "cancelling returns the escrow")
	# a big buy crosses several levels: partial fills at each resting price, the rest rests
	g0 = int(Save.d["gems"])
	var sells: Array = Exchange.book("stone")["sells"]
	var top := int(sells[0][0]); var q0 := int(sells[0][1])
	r = Exchange.post("buy", "stone", q0 + 5, top)
	ok(r["ok"] and int(r["filled"]) == q0 and int(r["left"]) == 5, "a buy takes the %d at the best ask and rests 5 (partial fill)" % q0)
	ok(int(Save.d["mats"]["stone"]) == q0 and int(Save.d["gems"]) == g0 - (q0 + 5) * top, "stone in, gems out (the rest held in escrow)")
	Exchange.cancel(String(r["id"]))
	# refusals
	ok(not Exchange.post("sell", "wood", 999, bid)["ok"], "can't sell what you don't have")
	ok(not Exchange.post("buy", "wood", 1, 9999)["ok"], "a price far off the band is refused")
	ok(not Exchange.post("buy", "kin", 1, 5)["ok"], "Boki aren't on the order book")
	# offline turnover fills a fair resting offer over a few expeditions (tonics: a price with room to walk)
	Save.d["items"]["tonic"] = 20
	var tm := int(round(Exchange.mid("tonic")))
	r = Exchange.post("sell", "tonic", 10, tm)
	ok(r["ok"] and int(r["left"]) > 0, "an offer at the middle of the book rests (%d left)" % int(r.get("left", 0)))
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var fills := 0
	var worse := 0
	for i in 60:
		for f in Exchange.tick(rng):
			fills += 1
			if int(f["price"]) < tm: worse += 1
		if Exchange.mine().is_empty(): break
	ok(fills >= 1, "a resting offer fills over a few expeditions (%d fills)" % fills)
	ok(worse == 0, "and always at the trader's quote, never below the %d it asked" % tm)
	ok(Exchange.taxed() > 0, "the tax is a gem sink (%d taken)" % Exchange.taxed())

## The Exchange's book mechanics: tax rounding, a sell-side partial fill and cancelling after it,
## and a refilled side that doesn't ratchet the price.
func _exchange_book() -> void:
	_started_save()
	Save.d["gems"] = 3000
	Work.ensure()
	ok(Exchange.tax_of(1) == 1 and Exchange.tax_of(12) == 1 and Exchange.tax_of(25) == 1 and Exchange.tax_of(26) == 2 and Exchange.tax_of(0) == 0, "the fill tax rounds up: a 12-gem fill pays 1, not 0")
	# a sell bigger than the best bid: partial fill, the rest rests with the goods in escrow
	Save.d["mats"]["wood"] = 40
	var bid := Exchange.best("wood", "buy")
	var depth := int(Exchange.book("wood")["buys"][0][1])
	var g0 := int(Save.d["gems"])
	var r := Exchange.post("sell", "wood", depth + 5, bid)
	var tax := Exchange.tax_of(depth * bid)
	ok(r["ok"] and int(r["filled"]) == depth and int(r["left"]) == 5, "a sell of %d at the best bid fills the %d there and rests 5 (partial fill)" % [depth + 5, depth])
	ok(int(Save.d["gems"]) == g0 + depth * bid - tax, "...paying %d less %d tax" % [depth * bid, tax])
	ok(int(Save.d["mats"]["wood"]) == 40 - (depth + 5), "...with the 5 left held in escrow, not in your pack (%d wood in the pack)" % int(Save.d["mats"]["wood"]))
	var w_before_cancel := int(Save.d["mats"]["wood"])
	var g1 := int(Save.d["gems"])
	var oid := String(r["id"])
	var c := Exchange.cancel(oid)
	ok(c["ok"] and int(Save.d["mats"]["wood"]) == w_before_cancel + 5 and int(Save.d["gems"]) == g1 and Exchange.mine().is_empty(), "cancelling after the partial fill returns the 5 unsold wood and leaves the gems alone")
	ok(not Exchange.cancel(oid)["ok"], "a cancelled offer can't be cancelled twice")
	# a buy that fills partly, then cancelled: the unspent escrow comes back, the spent part is gone
	g0 = int(Save.d["gems"])
	var asks: Array = Exchange.book("stone")["sells"]
	var ask := int(asks[0][0]); var ad := int(asks[0][1])
	r = Exchange.post("buy", "stone", ad + 3, ask)
	var spent := ad * ask
	ok(int(r["filled"]) == ad and int(Save.d["gems"]) == g0 - spent - 3 * ask, "a buy of %d at the best ask fills %d for %d and escrows %d" % [ad + 3, ad, spent, 3 * ask])
	c = Exchange.cancel(String(r["id"]))
	ok(c["ok"] and int(Save.d["gems"]) == g0 - spent and int(Save.d["mats"].get("stone", 0)) == ad, "cancelling after the partial fill returns the escrow: exactly the %d spent is gone" % spent)
	# buying a whole side out and refilling it is the same quotes, not a higher price
	var ask0 := Exchange.best("scrap", "sell")
	var gs := int(Save.d["gems"])
	var total := 0
	for lv in Exchange.book("scrap")["sells"]: total += int(lv[1])
	var top := int((Exchange.book("scrap")["sells"] as Array).back()[0])
	Exchange.post("buy", "scrap", total, top)
	ok(Exchange.mine().is_empty(), "bought the whole ask side of scrap (%d)" % total)
	ok(Exchange.best("scrap", "sell") == ask0 and Exchange.best("scrap", "buy") < ask0, "the side refills at the same quotes (%d), not a ratcheted price" % ask0)
	var sold_back := Exchange.post("sell", "scrap", total, Exchange.band("scrap").x)
	ok(int(sold_back["filled"]) == total and int(Save.d["gems"]) < gs, "buying out the side and selling it straight back loses gems (%d -> %d)" % [gs, int(Save.d["gems"])])

## The walk: offline fills reach only offers near the middle, at the traders' quote, and buying from the
## book and selling back by tick never profits, for any item.
func _exchange_walk() -> void:
	_started_save()
	Save.d["gems"] = 5000
	Work.ensure()
	for it in Exchange.ORDER: Exchange._add(it, 100)
	# out of band: far from the middle, nothing fills however many runs pass
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var m := Exchange.mid("tonic")
	var hi := int(ceil(m * (1.0 + Exchange.WALK))) + 2
	var lo := int(floor(m * (1.0 - Exchange.WALK))) - 2
	ok(hi <= Exchange.band("tonic").y and lo >= Exchange.band("tonic").x, "(tonic offers at %d and %d are inside the allowed band, outside the walk)" % [lo, hi])
	var rs := Exchange.post("sell", "tonic", 10, hi)
	var rb := Exchange.post("buy", "tonic", 10, lo)
	ok(rs["ok"] and rb["ok"] and int(rs["filled"]) == 0 and int(rb["filled"]) == 0, "both rest on the book")
	var fills := 0
	for i in 400: fills += Exchange.tick(rng).size()
	var tonics_left := 0
	for o in Exchange.mine(): tonics_left += int(o["left"])
	ok(fills == 0 and tonics_left == 20, "out-of-band offers never fill (%d fills in 400 runs, %d units still resting)" % [fills, tonics_left])
	Exchange.cancel(String(rs["id"])); Exchange.cancel(String(rb["id"]))
	# in band: fills come at the trader's quote, never worse than the offer asked
	var worse := 0; var got := 0
	rs = Exchange.post("sell", "tonic", 40, int(round(m)))
	rb = Exchange.post("buy", "tonic", 40, int(round(m)))
	for i in 120:
		for f in Exchange.tick(rng):
			got += 1
			if (String(f["side"]) == "sell" and int(f["price"]) < int(round(m))) or (String(f["side"]) == "buy" and int(f["price"]) > int(round(m))): worse += 1
	ok(got > 0 and worse == 0, "an offer at the middle fills (%d fills) and never worse than it asked (%d worse)" % [got, worse])
	for o in Exchange.mine(): Exchange.cancel(String(o["id"]))
	# no item can be bought off the book and sold back by tick (or the reverse) for a gain
	var losers := 0
	for it in Exchange.ORDER:
		var item: String = it
		var ask := Exchange.best(item, "sell"); var bid := Exchange.best(item, "buy")
		var mm := Exchange.mid(item)
		var best_net := -999; var cheapest_buy := 999999
		var sp := maxi(bid + 1, int(ceil(mm * (1.0 - Exchange.WALK))))
		var bp := mini(ask - 1, int(floor(mm * (1.0 + Exchange.WALK))))
		for i in 300:
			var open_sides: Array = Exchange.mine().map(func(o): return o["side"])
			if not open_sides.has("sell"): Exchange.post("sell", item, 1, sp)
			if not open_sides.has("buy"): Exchange.post("buy", item, 1, bp)
			for f in Exchange.tick(rng):
				if String(f["side"]) == "sell": best_net = maxi(best_net, int(f["price"]) - int(f["tax"]))
				else: cheapest_buy = mini(cheapest_buy, int(f["price"]))
		for o in Exchange.mine(): Exchange.cancel(String(o["id"]))
		var sell_ok := best_net < ask                              # buy at the ask, sell by tick: a loss
		var buy_ok := cheapest_buy >= bid - Exchange.tax_of(bid)   # buy by tick, sell at the bid: a loss
		if not (sell_ok and buy_ok): losers += 1
		if int(Exchange.COMMODITIES[item]["ref"]) >= 6:      # (a 3-gem item's walk is smaller than its spread: it never fills)
			ok(best_net > -999 or cheapest_buy < 999999, "%s: the experiment saw tick fills" % item)
		ok(sell_ok and buy_ok, "%s: no round trip profits (ask %d vs best tick sale %d net; bid %d vs cheapest tick buy %d)" % [item, ask, best_net, bid, cheapest_buy])
	ok(losers == 0, "no commodity is a free-gem loop")

## Pen stock: the day is stored, it rolls only forward, and an empty stock stays empty until tomorrow.
func _pens_restock() -> void:
	_started_save()
	Save.d["roster"] = [Save.new_kin("cindle", "Pip")]
	Save.d["active"] = Save.d["roster"][0]["uid"]
	Save.d["gems"] = 5000
	Save.d["farm_lvl"] = 3
	var ls := BokiPens.listings()
	var today := String(BokiPens._st()["day"])
	ok(ls.size() == BokiPens.PEN_STOCK and today == BokiPens._today(), "the stock's day is stored (%s)" % today)
	for L in ls: BokiPens.buy(String(L["id"]))
	ok(BokiPens.listings().is_empty() and BokiPens.listings().is_empty(), "buying the pens out leaves them empty (and stays empty)")
	BokiPens.restock()
	ok((BokiPens._st()["stock"] as Array).is_empty() and String(BokiPens._st()["day"]) == today, "...even if something asks for a restock the same day")
	# the next day: fresh stock
	BokiPens._st()["day"] = "2000-01-01"
	var fresh := BokiPens.listings()
	ok(fresh.size() == BokiPens.PEN_STOCK and String(BokiPens._st()["day"]) == BokiPens._today(), "tomorrow brings %d fresh Boki" % fresh.size())
	# the clock goes back: nothing is re-rolled, the stored day doesn't move back
	BokiPens._st()["day"] = "2999-12-31"
	var before: Array = fresh.map(func(L): return L["id"])
	ok(BokiPens.listings().map(func(L): return L["id"]) == before, "a clock set back doesn't re-roll the stock")
	for L in BokiPens.listings(): BokiPens.buy(String(L["id"]))
	ok(BokiPens.listings().is_empty() and String(BokiPens._st()["day"]) == "2999-12-31", "or restock an empty pen, and the stored day never goes backwards")
	# a bad saved day (not a date) behaves like a first visit once
	BokiPens._st()["day"] = ""
	ok(BokiPens.listings().size() == BokiPens.PEN_STOCK, "a save with no stored day gets its first stock")

## Buy-then-list can't mint gems: pen Boki (and strays) can't be listed, and open listings are capped.
func _pens_no_mint() -> void:
	_started_save()
	var base := Save.new_kin("burrlet", "Bun")
	Save.d["roster"] = [base]; Save.d["active"] = base["uid"]; Save.d["gems"] = 500
	var g0 := int(Save.d["gems"])
	var L: Dictionary = BokiPens.listings()[0]
	var price := int(L["price"])
	var r := BokiPens.buy(String(L["id"]))
	var bought: Dictionary = r["rec"]
	ok(r["ok"] and String(bought["origin"]["how"]) == "market" and not BokiPens.can_list(bought), "a pen Boki is marked as market-bought and can't be listed")
	var lr := BokiPens.list_mine(String(bought["uid"]), BokiPens.fair_range(bought).y)
	ok(not lr["ok"] and Save.kin(String(bought["uid"])) == bought and int(Save.d["gems"]) == g0 - price, "listing it is refused and costs nothing (%s)" % lr["why"])
	ok(int(Save.d["gems"]) < g0, "so buy-then-list can only lose gems (%d -> %d)" % [g0, int(Save.d["gems"])])
	var stray := Lifeline.stray()
	ok(not BokiPens.list_mine(String(stray["uid"]), BokiPens.fair_range(stray).y)["ok"], "a stray can't be listed either")
	# the Nesting Nook's egg parents can't be listed
	var pa := Save.new_kin("cindle", "Mum"); var pb := Save.new_kin("puddlet", "Dad")
	Save.d["roster"].append(pa); Save.d["roster"].append(pb)
	Save.d["egg"] = {"a": pa["uid"], "b": pb["uid"], "t": 0}
	var er := BokiPens.list_mine(String(pa["uid"]), Ransom.value(pa))
	ok(not er["ok"] and String(er["why"]).find("egg") >= 0 and Save.kin(String(pa["uid"])) == pa, "a Boki whose egg is in the Nesting Nook can't be listed (%s)" % er["why"])
	Save.d.erase("egg")
	# at most MAX_LISTED open at once
	var mine: Array = []
	for i in BokiPens.MAX_LISTED + 1:
		var k := Save.new_kin("cindle", "K%d" % i)
		Save.d["roster"].append(k); mine.append(k)
	var listed := 0
	var last: Dictionary = {}
	for k in mine:
		last = BokiPens.list_mine(String(k["uid"]), Ransom.value(k))
		if last["ok"]: listed += 1
	ok(listed == BokiPens.MAX_LISTED and not last["ok"], "no more than %d listings at once (%d listed: %s)" % [BokiPens.MAX_LISTED, listed, str(last.get("why", ""))])
	var first_id := String((BokiPens._st()["mine"] as Array)[0]["id"])
	BokiPens.unlist(first_id)
	ok(BokiPens.list_mine(String(mine[mine.size() - 1]["uid"]), Ransom.value(mine[mine.size() - 1]))["ok"], "taking one down makes room for another")

## Gem conservation across buy, list, sell and take-down: every step moves exactly the gems it should.
func _pens_gems() -> void:
	_started_save()
	var a := Save.new_kin("cindle", "Pip"); a["level"] = 4
	var b := Save.new_kin("burrlet", "Bun")
	Save.d["roster"] = [a, b]; Save.d["active"] = b["uid"]; Save.d["gems"] = 400
	var g := int(Save.d["gems"])
	var pen: Dictionary = BokiPens.listings()[0]
	var pp := int(pen["price"])
	BokiPens.buy(String(pen["id"]))
	g -= pp
	ok(int(Save.d["gems"]) == g, "buy: exactly the price leaves (%d)" % pp)
	var price := 120
	var fr := BokiPens.fair_range(a)
	ok(price >= fr.x and price <= fr.y, "(120 is a fair price for the level 4 Boki: %d-%d)" % [fr.x, fr.y])
	var lr := BokiPens.list_mine(String(a["uid"]), price)
	g -= 6
	ok(lr["ok"] and int(lr["fee"]) == 6 and int(Save.d["gems"]) == g, "list: the fee is exactly 5%% of 120 = 6, and nothing else moves (%d)" % int(Save.d["gems"]))
	var un := BokiPens.unlist(String(lr["id"]))
	ok(un["ok"] and int(Save.d["gems"]) == g, "take down: the Boki is back, the fee isn't refunded, nothing is minted")
	lr = BokiPens.list_mine(String(a["uid"]), price)
	g -= 6
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var sold: Array = []
	for i in 40:
		sold = BokiPens.tick(rng)
		if not sold.is_empty(): break
	g += price - 6
	ok(not sold.is_empty() and int(Save.d["gems"]) == g, "sell: the price less 5%% tax (6) is paid, once: %d gems, want %d" % [int(Save.d["gems"]), g])
	ok(BokiPens.tick(rng).is_empty() and int(Save.d["gems"]) == g, "a sold listing pays only once")


func _save_load() -> void:
	# everything round-trips through the save file, and an old save (none of it) loads cleanly
	_started_save()
	var a := Save.new_kin("cindle", "Pip"); var b := Save.new_kin("burrlet", "Bun")
	Save.d["roster"] = [a, b]; Save.d["active"] = a["uid"]; Save.d["gems"] = 400
	BokiPens.listings()
	BokiPens.list_mine(String(b["uid"]), Ransom.value(b))
	Work.ensure(); Save.d["mats"]["wood"] = 20
	Exchange.post("sell", "wood", 5, Exchange.best("wood", "sell") + 2)
	Save.d["floor"] = {"strays": 1, "last_m": 2}
	var path := "user://floor_check_save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(Save.d))
	f.close()
	var before_pens := (Save.d["pens"]["stock"] as Array).size()
	var before_mine := Exchange.mine().size()
	var wood := int(Save.d["mats"]["wood"])
	Save.load_from(path)
	ok((Save.d["pens"]["stock"] as Array).size() == before_pens and (Save.d["pens"]["mine"] as Array).size() == 1, "the pens and your listing survive a save/load")
	ok(Exchange.mine().size() == before_mine and int(Save.d["mats"]["wood"]) == wood, "open Exchange offers and escrow survive a save/load")
	ok(int(Save.d["floor"]["strays"]) == 1, "the floor's record survives a save/load")
	var u := BokiPens.unlist(String(Save.d["pens"]["mine"][0]["id"]))
	ok(u["ok"] and Save.d["roster"].size() == 2, "a listing taken down after loading comes back")
	# an old save from before any of this
	var old := Save.fresh()
	for k in ["pens", "exchange", "floor"]: old.erase(k)
	old["v"] = Save.VERSION
	old["tutorial"] = {"hatched": true}
	old["roster"] = [Save.new_kin("puddlet", "Old")]
	old["active"] = old["roster"][0]["uid"]
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.load_from(path)
	ok(not Save.d.has("pens") and not Save.d.has("exchange"), "an old save loads without the new keys")
	ok(BokiPens.listings().size() == BokiPens.PEN_STOCK and not Exchange.book("wood")["buys"].is_empty() and Lifeline.check().is_empty(), "and the pens, the Exchange and the floor all work on it")
	# the zero-zero save, saved and loaded: still gets its stray
	old["roster"] = []; old["active"] = ""; old["gems"] = 0; old["matches"] = 4
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.load_from(path)
	ok(Lifeline.stuck() and Lifeline.check().size() == 1 and Save.d["roster"].size() == 1, "a zero-Boki, zero-gem save loaded from disk gets its stray")
	DirAccess.remove_absolute(path)
