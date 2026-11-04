extends RefCounted
## --economy-floor-check: nobody is ever left with no Boki, no gems and no way to play (Lifeline),
## the stray, the Exchange order book (Exchange), and save/load for all of it (old saves too). The
## Shelter (the cheap commons behind the floor) is --market-check's.
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
	await _stray_match()
	_zero_run()
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
	ok(Shelter.cheapest() <= int(Goods.rules()["shelter"]["base"]) + int(Goods.rules()["shelter"]["per_level"]), "the cheapest shelter Boki (%d) is in the floor price band" % Shelter.cheapest())
	var ev := Lifeline.check()
	ok(ev.size() == 1 and String(ev[0]["kind"]) == "stray" and Save.d["roster"].size() == 1, "a stray Boki turns up at the farm")
	var st: Dictionary = Save.d["roster"][0]
	ok(not Data.is_rare(String(st["species"])) and not Mutations.special(st), "the stray is an ordinary common (%s)" % st["species"])
	ok(Save.active_kin() == st and st.has("serial") and String(st["origin"]["how"]) == "stray", "it's your partner, registered as a stray")
	ok(Lifeline.check().is_empty(), "with a Boki again, nothing more is given")
	ok(not Lifeline.stuck(), "and you're not stuck any more")
	# you can't get to zero on purpose: your last Boki can't be released, given up or handed on
	ok(KinBox.release(st) != "", "your last Boki can't be released (%s)" % KinBox.release(st))
	Save.d["gems"] = 999
	ok(Shelter.why_not(st) != "" and not Transfer.send(String(st["uid"]), "Moss")["ok"], "nor given up at the shelter or handed on")
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

func _stray_match() -> void:
	_started_save()
	Save.d["roster"] = []; Save.d["active"] = ""; Save.d["gems"] = 0
	Lifeline.check()
	ok(Save.d["roster"].size() == 1, "with no Boki, a stray turns up and is the one you play with")
	Save.d["items"]["tonic"] = 5; Save.d["items"]["rift_key"] = 2
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 12, "no_drop": true, "belt_items": Equal.take_belt(2)})
	m.set_process(false)
	var P := m.player
	var k: Kin = P.kin
	ok(k != null and String(k.rec["uid"]) == String(Save.d["roster"][0]["uid"]), "the stray goes with you like any other Boki")
	ok(P.tonics == 5 and P.armor_kits == 2 and P.rift_keys == 0,
			"tonics from the stash (cap 5 on the Hollow) and the issued kits (%d, %d); keys never come from home" % [P.tonics,
			P.armor_kits])
	P.lives = 1
	m.eliminate(P, null, "knocked out", true)
	m.result = {"extracted": false, "why": "knocked out"}
	var r := _result_of(m)
	ok((r.get("belt", {}) as Dictionary).is_empty(), "dying, the belt stays in your deathbox: nothing comes home")
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

## The zero-zero player: a stray, and the shelter's cheapest Boki is within reach of one extract.
func _zero_run() -> void:
	_started_save()
	Save.d["roster"] = []; Save.d["gems"] = 0; Save.d["active"] = ""
	Save.d["floor"] = {"strays": 0, "last_m": -1}
	Lifeline.check()
	Game.apply_result({"extracted": true, "tier": 0, "gems": Shelter.cheapest(), "kin_runs": [], "caught": []})
	var have: int = Save.d["roster"].size()
	var cheap: Dictionary = Shelter.cards().reduce(func(a, c): return c if a.is_empty() or int(c["price"]) < int(a["price"]) else a, {})
	var r := Shelter.adopt(String(cheap["id"]))
	ok(r["ok"] and Save.d["roster"].size() == have + 1, "from zero: a stray, then one extract adopts a Boki at the shelter (%d gems)" % int(cheap["price"]))
	# and a normal run uses the treat up
	_started_save()
	var g45 := Save.new_kin("cindle", "Pip")
	Save.d["roster"] = [g45]; Save.d["active"] = g45["uid"]; Save.d["treat"] = "treat_power"
	Game.apply_result({"extracted": false, "why": "left", "tier": 0, "gems": 0, "kin_runs": [], "caught": []})
	ok(String(Save.d["treat"]) == "", "a run uses the treat up")

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

func _save_load() -> void:
	# everything round-trips through the save file, and an old save (none of it) loads cleanly
	_started_save()
	var a := Save.new_kin("cindle", "Pip"); var b := Save.new_kin("burrlet", "Bun")
	Save.d["roster"] = [a, b]; Save.d["active"] = a["uid"]; Save.d["gems"] = 400
	Work.ensure(); Save.d["mats"]["wood"] = 20
	Exchange.post("sell", "wood", 5, Exchange.best("wood", "sell") + 2)
	Save.d["floor"] = {"strays": 1, "last_m": 2}
	var path := "user://floor_check_save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(Save.d))
	f.close()
	var before_mine := Exchange.mine().size()
	var wood := int(Save.d["mats"]["wood"])
	Save.load_from(path)
	ok(Exchange.mine().size() == before_mine and int(Save.d["mats"]["wood"]) == wood, "open Exchange offers and escrow survive a save/load")
	ok(int(Save.d["floor"]["strays"]) == 1, "the floor's record survives a save/load")
	# an old save from before any of this
	var old := Save.fresh()
	for k in ["exchange", "floor"]: old.erase(k)
	old["v"] = Save.VERSION
	old["tutorial"] = {"hatched": true}
	old["roster"] = [Save.new_kin("puddlet", "Old")]
	old["active"] = old["roster"][0]["uid"]
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.load_from(path)
	ok(not Save.d.has("exchange"), "an old save loads without the new keys")
	ok(not Exchange.book("wood")["buys"].is_empty() and Lifeline.check().is_empty(), "and the Exchange and the floor work on it")
	# the zero-zero save, saved and loaded: still gets its stray
	old["roster"] = []; old["active"] = ""; old["gems"] = 0; old["matches"] = 4
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.load_from(path)
	ok(Lifeline.stuck() and Lifeline.check().size() == 1 and Save.d["roster"].size() == 1, "a zero-Boki, zero-gem save loaded from disk gets its stray")
	DirAccess.remove_absolute(path)
