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
	await _loaner_match()
	_loaner_result()
	_exchange()
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
	var m := Match.new()
	main.add_child(m)
	var o := Loaner.opts({"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 12, "no_drop": true}, 4)
	m.start(o)
	m.set_process(false)
	var P := m.player
	var k: Kin = P.kin
	ok(k != null and Loaner.is_loaner(k.rec) and String(k.rec["uid"]) != String(mine["uid"]), "a free-kit run brings a loaner Boki, not yours (%s)" % (k.species if k else "none"))
	ok(k != null and k.species in Loaner.STARTERS and int(k.rec["level"]) == 1, "a starter egg's species, level 1")
	ok(P.rift_keys == 0 and P.tonics == 2, "the basic kit: two free tonics, no keys (%d, %d)" % [P.tonics, P.rift_keys])
	ok(Loot.of_hand(P).is_empty() or int(Loot.of_hand(P).get("rar", 0)) == 0, "the plain class weapon")
	# taming during a free-kit run still works (loot rules are the usual ones)
	# die in the Hollow: the loaner never drops into the box or is left behind
	P.lives = 1
	m.eliminate(P, null, "knocked out", true)
	var bx := Life.box_of(m, P)
	var in_box: bool = not bx.is_empty() and (bx.get("kin", []) as Array).any(func(r): return Loaner.is_loaner(r))
	ok(not in_box and m.player_lost.is_empty(), "dying in the Hollow, the loaner isn't in your box or left behind")
	ok(not m.kins.any(func(w): return w.is_wild() and not w.dead and Loaner.is_loaner(w.rec)), "and nobody can capture it")
	m.result = {"extracted": false, "why": "knocked out"}
	var r := _result_of(m)
	ok(r.get("loaner", false) and (r.get("kin_runs", []) as Array).is_empty() and not r.has("lost_kin"), "the result carries no loaner Boki")
	m.queue_free()
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
	var trust0 := float(mine["trust"]); var xp0 := int(mine.get("xp", 0)); var m0 := int(mine.get("matches", 0))
	# extracted with a little: the stipend tops it up to MIN_PAY
	var out := Game.apply_result({"extracted": true, "loaner": true, "tier": 0, "gems": 12, "tonics": 5, "kin_runs": [], "caught": []})
	ok(int(Save.d["gems"]) == Loaner.MIN_PAY and int(out["stipend"]) == Loaner.MIN_PAY - 12, "an extract pays at least %d gems (stipend %d)" % [Loaner.MIN_PAY, int(out["stipend"])])
	ok(float(mine["trust"]) == trust0 and int(mine.get("xp", 0)) == xp0 and int(mine.get("matches", 0)) == m0, "your own Boki is untouched (it stayed home)")
	ok(Save.d["roster"].size() == 1 and not Save.d["roster"].any(func(r): return Loaner.is_loaner(r)), "the loaner is never kept")
	ok(int(Save.d["items"]["tonic"]) == 5 and int(Save.d["items"]["rift_key"]) == 2, "your tonics and keys are untouched")
	# died: nothing of yours lost, no ransom
	out = Game.apply_result({"extracted": false, "why": "knocked out", "loaner": true, "tier": 2, "gems": 30, "lost_gems": 30, "tonics": 5, "kin_runs": [],
		"lost_kin": [{"uid": "x", "fate": "rival", "holder": "Vexa", "rec": Loaner.roll(3)}]})
	ok(Save.d["roster"].size() == 1 and (Save.d["lost_kin"] as Array).is_empty() and int(out["stipend"]) == 0, "dying on a free-kit run loses nothing of yours")
	# the zero-zero player: one free-kit run buys a pen Boki
	_started_save()
	Save.d["roster"] = []; Save.d["gems"] = 0; Save.d["active"] = ""
	Save.d["floor"] = {"strays": 0, "last_m": -1}
	Game.apply_result({"extracted": true, "loaner": true, "tier": 0, "gems": 0, "kin_runs": [], "caught": []})
	var have := Save.d["roster"].size()
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
	var tax := int(round(10 * bid * Exchange.TAX))
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
	# offline turnover fills a fair resting offer over a few expeditions
	r = Exchange.post("sell", "wood", 10, Exchange.ref_price("wood") + 1)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var fills := 0
	for i in 8:
		fills += Exchange.tick(rng).size()
		if Exchange.mine().is_empty(): break
	ok(fills >= 1, "a resting offer fills over a few expeditions (%d fills)" % fills)
	ok(Exchange.taxed() > 0, "the tax is a gem sink (%d taken)" % Exchange.taxed())

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
