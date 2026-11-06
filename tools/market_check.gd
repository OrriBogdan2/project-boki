extends RefCounted
## --market-check: the market (docs/decisions/0013-market.md). A stall on every save and its levels
## (the tabs and the model change, upgrades cost labour + materials + gems); the Shelter (adoption
## gems destroyed, giving pays nothing, the limits); transfers (fee, weekly, both sides); stall
## listings with fee and tax, NPC buyers; search returns the lowest price; the Auction House
## (escrow, refunds, anti-snipe, friends-only); the Black Market's Ransom tab and rare stock; the
## anti-mint rule (no NPC round trip makes gems, no Boki pays gems); gem conservation; the v7 -> v8
## migration and a save/load round trip. Prints MARKET ok/FAIL lines and "MARKET DONE, failures: N".

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("MARKET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	await _stall_on_every_save()
	_levels()
	_shelter()
	_transfer()
	_stalls()
	_search()
	_auction()
	_black_market()
	_anti_mint()
	_conservation()
	_migration()
	_finds()
	print("MARKET DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

## A played save on a farm without the building pass (stall level 3), with two older Boki and gems.
func _save(gems := 1000) -> void:
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["hatched"] = true
	Save.d["matches"] = 3
	Save.d["gems"] = gems
	for nm in ["Pip", "Bun", "Moss"]:
		var k := Save.new_kin(["cindle", "burrlet", "puddlet"][Save.d["roster"].size()], nm)
		k["born"] = MarketSave.now() - 30 * 86400
		Save.register(k)
		Save.d["roster"].append(k)
	Save.d["active"] = Save.d["roster"][0]["uid"]

func _new_fs_save() -> Dictionary:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	return d

# ------------------------------------------------------------------ the stall
func _stall_on_every_save() -> void:
	Save.d = _new_fs_save()
	var home = await main._hb_home()
	var stalls := HomeLayout.fixtures(Save.d, "stall")
	ok(stalls.size() == 1 and not FarmSites.has_site(stalls[0]) and FarmSites.tier(stalls[0]) == 1,
		"a brand new farm-start island has its market stall from the start, standing, at L1")
	if not stalls.is_empty():
		var c := HomeLayout.deco_center(stalls[0])
		var far := Vector2(c.x - HomeLayout.LANDING.x, c.z - HomeLayout.LANDING.z).length()
		ok(far < float(HomeStall.SEARCH_R) + 3.0, "near the portal (%.1f m from the landing)" % far)
		ok(home.spots["stall"].distance_to(c) < 0.1, "and the farm knows where it is (the hub and the prompt open it)")
	ok(HomeLayout.count_of("market_stall", Save.d) == 1, "only one")
	home.queue_free()
	await main.get_tree().process_frame
	# an older farm-start save with no stall gets one when it loads
	var d := _new_fs_save()
	Save.d = d
	HomeLayout.ensure(d)
	ok(HomeLayout.count_of("market_stall", d) == 0, "(an older farm-start save without a stall)")
	home = await main._hb_home()
	ok(HomeLayout.fixtures(Save.d, "stall").size() == 1, "gets its stall set down when it loads")
	# one in storage stays in storage (you put it away yourself)
	var lay := HomeLayout.of(Save.d)
	(lay["deco"] as Array).erase(HomeLayout.fixtures(Save.d, "stall")[0])
	lay["inv"]["market_stall"] = 1
	ok(not HomeStall.ensure(home) and HomeLayout.fixtures(Save.d, "stall").is_empty(),
		"a stall you put in storage isn't placed again")
	home.queue_free()
	await main.get_tree().process_frame

func _levels() -> void:
	Save.d = _new_fs_save()
	HomeLayout.ensure(Save.d)
	var lay := HomeLayout.of(Save.d)
	var e := {"u": 900, "id": "market_stall", "x": 30, "z": 30, "r": 0, "t": 1}
	(lay["deco"] as Array).append(e)
	var hm := HomeMarket.new(null, Callable())
	ok(FarmUnlocks.gated() and Stalls.level() == 1 and hm.tabs() == ["Vendor", "Exchange"],
		"L1: the vendor (and the Exchange) only: %s" % str(hm.tabs()))
	var keys := func(tab: String) -> Array:
		hm.vendor_tab = tab
		var out: Array = []
		for sec in hm._vendor_sections():
			for g in sec[1]: out.append(String(g[0]))
		return out
	var boki: Array = keys.call("Boki")
	var hunter: Array = keys.call("Hunter")
	ok(boki.has("food:kibble") and not boki.has("tonic") and not boki.has("armor_kit") and hunter.has("tonic")
		and not hunter.any(func(k): return k.begins_with("food:") or k.begins_with("acc:")),
		"Vendor: Boki food and wear under Boki, the tonic and the belt items under Hunter")
	ok(not hm.VENDOR_TABS.has("Kin food") and hm.VENDOR_TABS.has("Hunter"), "Vendor tabs name who the goods are for")
	# an upgrade is a site: Boki labour, materials and a few gems, like other buildings
	Save.d["gems"] = 500
	Work.ensure()
	for mat in ["wood", "stone", "fibre"]: Save.d["mats"][mat] = 50
	Save.d["extracts"] = 40
	var g0 := int(Save.d["gems"])
	var why := FarmSites.start_upgrade(e)
	var cost := FarmSites.upgrade_cost("market_stall", 2)
	ok(why == "" and int(cost.get("labour", 0)) > 0 and int(cost.get("gems", 0)) > 0 and int(cost.get("wood", 0)) > 0
		and int(Save.d["gems"]) == g0,
			"upgrading to L2 takes labour %d, materials and %d gems as it goes" % [int(cost.get("labour", 0)),
			int(cost.get("gems", 0))])
	ok(Stalls.level() == 1, "while the Boki build it, it still works at L1")
	while FarmSites.has_site(e): FarmSites.add_swing(e)
	ok(int(Save.d["gems"]) == g0 - int(cost["gems"]), "and the gems were spent by the time it was built")
	ok(Stalls.level() == 2 and hm.tabs() == ["Vendor", "Exchange", "Shelter", "My stall", "Search"],
		"L2 adds the Shelter, your stall and search: %s" % str(hm.tabs()))
	e["t"] = 3
	ok(Stalls.level() == 3 and hm.tabs().has("Auctions"), "L3 adds the Auction House")
	var looks: Array = [1, 2, 3].map(func(lv): return _parts(StallModels.build(lv)))
	ok(looks[0] < looks[1] and looks[1] < looks[2], "each level changes the model (parts %s)" % str(looks))
	ok(_named(StallModels.build(2), "Stall2") and FarmModels.sig(e) != FarmModels.sig({"id": "market_stall", "t": 2}),
		"and the farm redraws it when the tier changes")
	lay["fb"] = 0
	ok(Stalls.level() == 3, "a farm without the building pass (no upgrades there) has everything open")

func _parts(n: Node) -> int:
	var c := 0
	for ch in n.get_children():
		c += 1 + _parts(ch)
	n.free()
	return c

func _named(n: Node, nm: String) -> bool:
	var yes := String(n.name) == nm
	n.free()
	return yes

# ------------------------------------------------------------------ the shelter
func _shelter() -> void:
	_save()
	var cards := Shelter.cards()
	ok(cards.size() == int(Goods.rules()["shelter"]["strays"])
		and cards.all(func(c): return not Data.is_rare(String(c["rec"]["species"]))),
		"the shelter has %d ordinary strays today" % cards.size())
	var c0: Dictionary = cards[0]
	var g0 := int(Save.d["gems"])
	var t0 := float(c0["rec"]["trust"])
	var r := Shelter.adopt(String(c0["id"]))
	ok(r["ok"] and int(Save.d["gems"]) == g0 - int(c0["price"]) and Save.d["roster"].has(r["rec"]),
		"adopting costs %d gems (destroyed: nobody is paid) and it comes home" % int(c0["price"]))
	ok(String(r["rec"]["origin"]["how"]) == "shelter" and float(r["rec"]["trust"]) < t0,
		"it's an adoptee, and its trust partly resets with a new keeper")
	var rare := Save.new_kin("cindle")
	rare["level"] = 6
	rare["shimmer"] = true
	ok(Shelter.price(rare) > Shelter.price(c0["rec"]),
		"a higher level, shimmer or mutation costs more to adopt (%d vs %d)" % [Shelter.price(rare),
			Shelter.price(c0["rec"])])
	# giving one up pays nothing
	var bun := Save.kin(String(Save.d["roster"][1]["uid"]))
	g0 = int(Save.d["gems"])
	r = Shelter.give_up(String(bun["uid"]))
	ok(r["ok"] and int(Save.d["gems"]) == g0 and not Save.d["roster"].has(bun),
		"giving a Boki up pays nothing (gems %d -> %d)" % [g0, int(Save.d["gems"])])
	var card := _card_of(String(bun["uid"]))
	ok(not card.is_empty() and String(card["from"]) == String(Save.d["name"])
		and (bun["raised_by"] as Array).has(String(Save.d["name"])),
		"it waits at the shelter, remembering who raised it")
	r = Shelter.adopt(String(card["id"]))
	ok(not r["ok"] and Shelter.gave(String(bun["uid"])), "you can't adopt back one you gave away (%s)" % r["why"])
	# limits
	var young := Save.new_kin("zapple", "Kit")
	Save.register(young)
	Save.d["roster"].append(young)
	ok(Shelter.why_not(young).contains("young"),
		"a Boki under %d days old can't be put up: %s" % [int(Goods.rules()["shelter"]["min_age_days"]),
			Shelter.why_not(young)])
	young["born"] = MarketSave.now() - 30 * 86400
	young["sheltered"] = MarketSave.today()
	ok(Shelter.why_not(young).contains("today"), "each Boki once a day at most: %s" % Shelter.why_not(young))
	ok(Shelter.why_not(Save.active_kin()) != "", "your partner stays: %s" % Shelter.why_not(Save.active_kin()))
	Save.d["roster"] = [Save.active_kin()]
	ok(Shelter.why_not(Save.active_kin()).contains("only"), "and so does your last Boki")
	# the roster cap
	_save()
	for i in 400:
		if KinBox.full(): break
		var k := Save.new_kin("burrlet")
		Save.d["roster"].append(k)
		KinBox.route_new(k)
	ok(not Shelter.adopt(String(Shelter.cards()[0]["id"]))["ok"], "a full farm and Burrow can't adopt")
	# NPC adopters give a given Boki a home, offline
	_save()
	Shelter.give_up(String(Save.d["roster"][2]["uid"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var homed: Array = []
	for i in 30:
		homed += Shelter.tick(rng)
	ok(homed.size() == 1 and Shelter.cards().all(func(c): return String(c["from"]) == ""),
		"an NPC adopter gives it a home while you're out (%s)" % str(homed))
	# the stall's level gates it
	Save.d["layout"] = HomeLayout.new_fs(Save.d, 7)
	ok(not Shelter.adopt(String(Shelter.cards()[0]["id"]))["ok"] and Shelter.why_not(Save.d["roster"][1]) != "",
		"a stall at L1 has no shelter yet")

func _card_of(uid: String) -> Dictionary:
	for c in Shelter.cards():
		if String(c["rec"].get("uid", "")) == uid: return c
	return {}

# ------------------------------------------------------------------ transfers
func _transfer() -> void:
	_save()
	var bun: Dictionary = Save.d["roster"][1]
	var moss: Dictionary = Save.d["roster"][2]
	var g0 := int(Save.d["gems"])
	ok(not Transfer.send(String(bun["uid"]), "")["ok"]
		and not Transfer.send(String(bun["uid"]), String(Save.d["name"]))["ok"],
		"a transfer needs another player's name")
	var r := Transfer.send(String(bun["uid"]), "Moss")
	ok(r["ok"] and int(Save.d["gems"]) == g0 - Transfer.fee() and not Save.d["roster"].has(bun),
		"sending costs the flat fee (%d, destroyed) and the Boki waits for them" % Transfer.fee())
	var r2 := Transfer.send(String(moss["uid"]), "Tarn")
	ok(not r2["ok"] and Transfer.wait_s() > 6 * 86400, "one transfer a week (%s)" % r2["why"])
	var back := Transfer.recall(String(r["id"]))
	ok(back["ok"] and Save.d["roster"].has(bun) and int(Save.d["gems"]) == g0 and Transfer.wait_s() == 0,
		"called back before they accept: the Boki, the fee and the week come back")
	r = Transfer.send(String(bun["uid"]), "Moss")
	var packet: Dictionary = r["packet"]
	Transfer.delivered(String(r["id"]))
	ok(Transfer.outbox().is_empty() and int(Save.d["gems"]) == g0 - Transfer.fee(),
		"they accepted: it's theirs, and nobody paid gems for it")
	# the other side
	_save(0)
	var got := Transfer.accept(packet)
	var same: bool = got["ok"] and String(got["rec"]["species"]) == String(bun["species"])
	ok(same and String(got["rec"]["origin"]["how"]) == "transfer"
		and (got["rec"]["raised_by"] as Array).has(String(packet["from_name"])) and int(Save.d["gems"]) == 0,
		"the receiver accepts: the same Boki, 'raised by' its old keeper, and no gems change hands")

# ------------------------------------------------------------------ your stall
func _stalls() -> void:
	_save()
	Goods.give("good:heartwood")
	Goods.give("good:heartwood")
	var key := "good:heartwood"
	var ref := Goods.ref_of(key)
	var price := Stalls.npc_pays(key)
	var g0 := int(Save.d["gems"])
	var r := Stalls.list(key, price)
	var fee := int(ceil(price * 0.05 - 0.0001))
	ok(r["ok"] and int(r["fee"]) == fee and int(Save.d["gems"]) == g0 - fee and Goods.have(key) == 1,
		"listing costs a %d-gem fee (5%% of %d) and the good goes on the stall" % [fee, price])
	ok(Stalls.unlist(String(r["id"]))["ok"] and Goods.have(key) == 2 and int(Save.d["gems"]) == g0 - fee,
		"taking it down gives the good back (not the fee)")
	var high := Stalls.list(key, ref * 2)
	var low := Stalls.list(key, price)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var g1 := int(Save.d["gems"])
	var sold: Array = []
	for i in 40:
		sold += Stalls.tick(rng)
	var tax := int(ceil(price * 0.10 - 0.0001))
	ok(sold.size() == 1 and String(sold[0]["key"]) == key and int(Save.d["gems"]) == g1 + price - tax,
		"an NPC buyer takes the fair one: %d less a %d tax" % [price, tax])
	ok(Stalls.mine().size() == 1 and String(Stalls.mine()[0]["id"]) == String(high["id"]) and low["ok"],
		"one priced over what NPCs pay (%d > %d) never sells offline" % [ref * 2, price])
	Stalls.unlist(String(high["id"]))
	for i in int(Goods.rules()["stall"]["max_listed"]):
		Goods.give("good:dye_rose")
		Stalls.list("good:dye_rose", 10)
	Goods.give("good:dye_rose")
	ok(not Stalls.list("good:dye_rose", 10)["ok"],
		"a stall holds %d at once" % int(Goods.rules()["stall"]["max_listed"]))
	# gear and Boki wear go on a stall too; a worn accessory doesn't
	_save()
	var it := Loot.gear("blink", 2)
	Save.d["accs"] = ["bell"]
	Save.d["roster"][0]["acc"] = "bell"
	ok(Goods.have("wear:bell") == 0 and not Stalls.list("wear:bell", 20)["ok"], "a worn accessory can't be listed")
	Save.d["roster"][0]["acc"] = ""
	ok(Stalls.list("wear:bell", 20)["ok"] and not (Save.d["accs"] as Array).has("bell"), "a spare one can")
	Save.d["armory"].append(it)
	ok(Stalls.list("gear:" + String(it["uid"]), 20)["ok"] and Econ.find(String(it["uid"])).is_empty(),
		"and a piece of gear leaves the armory for the stall")

# ------------------------------------------------------------------ search
func _search() -> void:
	_save()
	var all := Stalls.search("")
	ok(not all.is_empty(), "the NPC stalls have goods today (%d kinds)" % all.size())
	var worst := 0
	for f in all:
		var rows: Array = f["rows"]
		var mn := 1 << 30
		for L in rows: mn = mini(mn, int(L["price"]))
		if int(f["lowest"]) != mn or int(rows[0]["price"]) != mn: worst += 1
	ok(worst == 0, "search returns each good's lowest price first")
	var f0: Dictionary = all[0]
	var key := String(f0["key"])
	if Goods.kind_of(key) != "wear": Goods.give(key)
	var cheap := int(f0["lowest"]) - 1
	if Goods.kind_of(key) != "wear":
		Stalls.list(key, maxi(1, cheap))
		ok(Stalls.lowest(key) == maxi(1, cheap)
			and String(Stalls.search(Goods.name_of(key).to_lower())[0]["rows"][0]["seller"]) == "you",
			"your cheaper listing becomes the lowest price for %s" % Goods.name_of(key))
	var hits := Stalls.search(Goods.name_of(key).substr(0, 4))
	ok(hits.any(func(h): return String(h["key"]) == key), "search finds it by part of its name")
	var npc_row: Dictionary = {}
	for row in all:
		var best: Dictionary = row["rows"][0]
		if String(best["seller"]) != "you" and Goods.kind_of(String(row["key"])) == "good": npc_row = best
	if not npc_row.is_empty():
		var g0 := int(Save.d["gems"])
		var have := Goods.have(String(npc_row["key"]))
		var r := Stalls.buy(String(npc_row["id"]))
		ok(r["ok"] and int(Save.d["gems"]) == g0 - int(npc_row["price"])
			and Goods.have(String(npc_row["key"])) == have + 1,
			"buying from a stall pays its price and the good is yours")

# ------------------------------------------------------------------ auctions
func _auction() -> void:
	_save()
	Goods.give("good:brood_crown")
	var g0 := int(Save.d["gems"])
	var r := Auction.create("good:brood_crown", 100, 5, 24, false)
	var lot := Auction.find(String(r.get("id", "")))
	ok(r["ok"] and int(Save.d["gems"]) == g0 - 5 and int(lot["ends"]) - MarketSave.now() >= 24 * 3600 - 5,
		"an auction: start price, step and 24 h, a 5-gem listing fee")
	ok(not Auction.create("good:brood_crown", 100, 5, 6, false)["ok"], "12, 24 or 48 hours only")
	ok(not Auction.bid(String(lot["id"]), 200)["ok"], "you can't bid on your own lot")
	# bidding on an NPC lot: escrow, refunds, no withdrawing, anti-snipe
	Auction.refill()
	var npc := {}
	for l in Auction.lots():
		if String(l["seller"]) != "you": npc = l
	ok(not npc.is_empty() and int(npc["start"]) >= Goods.ref_of(String(npc["key"])),
		"NPC lots of rare goods open at their full price or more")
	g0 = int(Save.d["gems"])
	ok(not Auction.bid(String(npc["id"]), int(npc["start"]) - 1)["ok"], "a bid under the start is refused")
	r = Auction.bid(String(npc["id"]), int(npc["start"]))
	ok(r["ok"] and int(Save.d["gems"]) == g0 - int(npc["start"]),
		"a bid is taken at once (escrow): %d" % int(npc["start"]))
	ok(not Auction.bid(String(npc["id"]), int(npc["start"]) + 50)["ok"],
		"and can't be withdrawn or bid over by yourself")
	npc["cap"] = int(npc["start"]) + 200
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for i in 10:
		if String(npc["bidder"]) != "you": break
		Auction.tick(rng)
	ok(String(npc["bidder"]) != "you" and int(Save.d["gems"]) == g0,
		"outbid: your gems come back (%d)" % int(Save.d["gems"]))
	npc["ends"] = MarketSave.now() + 30
	var amount := Auction.min_bid(npc)
	Auction.bid(String(npc["id"]), amount)
	ok(int(npc["ends"]) - MarketSave.now() >= int(Goods.rules()["auction"]["extend_s"]) - 1,
		"a bid in the last minute pushes the end out (anti-snipe)")
	npc["ends"] = MarketSave.now() - 1
	var have := Goods.have(String(npc["key"]))
	Auction.settle()
	ok(Goods.have(String(npc["key"])) == have + 1 and Auction.find(String(npc["id"])).is_empty(),
		"you win when it ends: the piece is yours")
	# your lot: NPC bids up to what they pay, the seller is paid less tax; friends-only gets no NPC bids
	lot["ends"] = MarketSave.now() + 3600
	for i in 20: Auction.tick(rng)
	var cap := int(floor(Goods.ref_of("good:brood_crown") * float(Goods.rules()["auction"]["npc_bid_k"])))
	ok(int(lot["top"]) > 0 and int(lot["top"]) <= cap, "NPC bidders bid on your lot, never over %d" % cap)
	g0 = int(Save.d["gems"])
	var top := int(lot["top"])
	lot["ends"] = MarketSave.now() - 1
	Auction.settle()
	ok(int(Save.d["gems"]) == g0 + top - int(ceil(top * 0.10 - 0.0001)), "sold: you get %d less the 10%% tax" % top)
	Goods.give("good:serpent_scale")
	var fr := Auction.create("good:serpent_scale", 10, 1, 12, true)
	var flot := Auction.find(String(fr["id"]))
	for i in 20: Auction.tick(rng)
	ok(bool(flot["friends"]) and int(flot["top"]) == 0, "a friends-only lot gets no NPC bids")
	flot["ends"] = MarketSave.now() - 1
	Auction.settle()
	ok(Goods.have("good:serpent_scale") == 1, "a lot nobody bid on comes back")

# ------------------------------------------------------------------ the Black Market
func _black_market() -> void:
	_save()
	var stock := BlackMarket.stock()
	var goods := stock.filter(func(e): return not String(e["key"]).begins_with("egg:"))
	ok(goods.size() == int(Goods.rules()["black_market"]["stock"])
		and goods.all(func(e): return Goods.rarity_of(String(e["key"])) in ["rare", "epic"]),
		"rare stock: %d rare or epic pieces today" % goods.size())
	ok(goods.all(func(e): return int(e["price"]) >= 2 * Goods.ref_of(String(e["key"]))),
		"priced as a sink: at least twice what they're worth")
	var banned := stock.any(func(e): return String(e["key"]).contains("key") or String(e["key"]).contains("shard"))
	ok(not banned, "never keys, shards or match-only items")
	var e0: Dictionary = goods[0]
	var g0 := int(Save.d["gems"])
	var r := BlackMarket.buy(String(e0["id"]))
	ok(r["ok"] and int(Save.d["gems"]) == g0 - int(e0["price"]) and Goods.have(String(e0["key"])) >= 1
		and not BlackMarket.stock().has(e0),
		"buying one: the gems are gone and it's out of stock until tomorrow")
	var eggs := Incubator.count()
	var rare_sp := String(Data.KIN.keys().filter(func(sp): return Data.is_rare(String(sp)))[0])
	BlackMarket.stock().append({"id": "egg_test", "key": "egg:" + rare_sp,
		"price": 420})
	ok(BlackMarket.buy("egg_test")["ok"] and Incubator.count() == eggs + 1,
		"a Rare Egg goes to the Incubator's shelf")
	# the Ransom tab: a Boki nobody claimed is bought back there, and a captor hears your message
	_save()
	var k: Dictionary = Save.d["roster"][1]
	Ransom.lose(k, "ransom", "", 2)
	var L := Ransom.find(String(k["uid"]))
	ok(Data.BUILDINGS["ransom"]["name"] == "Black Market" and String(L["where"]) == "ransom",
		"a Boki nobody took waits at the Black Market (its Ransom tab)")
	ok(Ransom.pay(L) and Save.d["roster"].has(k), "paying the ask brings it home")
	var k2: Dictionary = Save.d["roster"][2]
	Ransom.lose(k2, "rival", "Vexa", 2)
	Ransom.offer(Ransom.find(String(k2["uid"])), 5, "Please, it's my partner's sibling")
	var lg: Array = Save.d["ransom_log"]
	ok(String(lg[-1]["text"]).contains("Vexa") and String(lg[-1]["text"]).contains("sibling"),
		"an offer to the captor carries your message")
	var bm := HomeBlackMarket.new(null)
	ok(bm.TABS.has("ransom") and bm.TABS.has("rare") and String(HomeBlackMarket.OLD_TABS["house"]) == "ransom",
		"the Black Market has a Ransom tab and a Rare stock tab")

# ------------------------------------------------------------------ no gem mint
func _anti_mint() -> void:
	_save()
	var npc: Dictionary = Goods.rules()["npc"]
	var bad_keys: Array = []
	for key in Goods.catalogue():
		var ref := Goods.ref_of(key)
		var cheapest_buy := mini(int(ceil(ref * float(npc["sell_lo"]))), ref)       # NPC stall or the vendor
		var pays := Stalls.npc_pays(key)
		var best_sale := pays - Stalls.sale_tax(pays) - Stalls.list_fee(pays)
		var auction_sale := int(floor(ref * float(Goods.rules()["auction"]["npc_bid_k"])))
		if best_sale >= cheapest_buy or auction_sale >= cheapest_buy: bad_keys.append(key)
	ok(bad_keys.is_empty(), "no good can be bought from the game and sold back to it for more: %s" % str(bad_keys))
	ok(float(npc["buy_k"]) < float(npc["sell_lo"])
		and float(Goods.rules()["auction"]["npc_lot_start"]) >= float(npc["sell_lo"]),
		"NPC buyers pay under what NPC sellers ask")
	ok(not Goods.catalogue().has("util:tonic"), "Exchange commodities stay on the Exchange")
	# the old riskless mint: buy a Boki cheap and list it. Now there is nothing to list it on
	var g0 := int(Save.d["gems"])
	var r := Shelter.adopt(String(Shelter.cards()[0]["id"]))
	ok(Shelter.why_not(r["rec"]) != "",
		"a just-adopted Boki can't be put up again at once: %s" % Shelter.why_not(r["rec"]))
	r["rec"]["born"] = 0
	var g1 := int(Save.d["gems"])
	Shelter.give_up(String(r["rec"]["uid"]))
	ok(int(Save.d["gems"]) == g1 and g1 < g0, "and giving it up pays nothing: a Boki never turns into gems")
	ok(not Social.has_method("sell_kin") and not ResourceLoader.exists("res://scripts/core/boki_pens.gd"),
		"the old Boki selling is gone (Social.sell_kin, the Drift Pens)")

## Every gem in and out of a run of trades adds up: fees, taxes and purchases are sinks, NPC payouts
## the only source.
func _conservation() -> void:
	_save()
	Goods.give("good:heartwood")
	Goods.give("good:colossus_horn")
	var start := int(Save.d["gems"])
	var sunk := 0
	var paid := 0
	var key := "good:heartwood"
	var price := Stalls.npc_pays(key)
	sunk += int(Stalls.list(key, price)["fee"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 40:
		for s in Stalls.tick(rng): paid += int(s["paid"])
	sunk += int(Auction.create("good:colossus_horn", 20, 2, 12, false)["fee"])
	var c: Dictionary = Shelter.cards()[0]
	sunk += int(c["price"])
	Shelter.adopt(String(c["id"]))
	var bm: Dictionary = BlackMarket.stock()[0]
	sunk += int(bm["price"])
	BlackMarket.buy(String(bm["id"]))
	sunk += Transfer.fee()
	Transfer.send(String(Save.d["roster"][1]["uid"]), "Moss")
	ok(int(Save.d["gems"]) == start - sunk + paid,
		"gems add up: %d - %d sunk + %d paid = %d" % [start, sunk, paid, int(Save.d["gems"])])

# ------------------------------------------------------------------ the save
func _migration() -> void:
	_save()
	var listed := Save.new_kin("zapple", "Listed")
	var web := Save.new_kin("pebbit", "Web")
	var old: Dictionary = JSON.parse_string(JSON.stringify(Save.d))
	old["v"] = 7
	old.erase("market")
	old.erase("goods")
	var pen_listing := {"id": "L1", "kind": "player", "price": 80, "rec": listed, "seller": "you", "t": 0}
	old["pens"] = {"day": "2026-11-01", "stock": [], "mine": [pen_listing], "sold": [], "n": 1}
	old["listings"] = {"abc": {"price": 90, "kind": "kin", "key": "pebbit", "rec": web, "t": 0},
		"def": {"price": 4, "kind": "seed", "key": "tidebloom", "t": 0}}
	var n0 := (old["roster"] as Array).size()
	var up: bool = Save.migrate(old)
	ok(up and int(old["v"]) == Save.VERSION and Save.VERSION >= 8, "a v7 save upgrades to the current version")
	var names: Array = (old["roster"] as Array).map(func(r): return String(r["name"]))
	ok((old["roster"] as Array).size() == n0 + 2 and names.has("Listed") and names.has("Web"),
		"open pen and web Boki listings come back to the roster")
	ok(not old.has("pens") and old["listings"].has("def") and not old["listings"].has("abc"),
		"the pens are gone; seed listings stay")
	ok(typeof(old["market"]) == TYPE_DICTIONARY and typeof(old["goods"]) == TYPE_DICTIONARY
		and String(old.get("market_notice", "")).contains("Listed"),
		"the market gets its defaults, and a one-time notice says who came home")
	# a round trip through the file keeps everything open
	_save()
	Goods.give("good:dye_sky")
	Goods.give("good:heartwood")
	Stalls.list("good:dye_sky", 9)
	Auction.create("good:heartwood", 40, 2, 48, true)
	Shelter.give_up(String(Save.d["roster"][2]["uid"]))
	Transfer.send(String(Save.d["roster"][1]["uid"]), "Moss")
	BlackMarket.stock()
	var path := "user://market_check_save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(Save.d))
	f.close()
	var gems := int(Save.d["gems"])
	Save.load_from(path)
	ok(Stalls.mine().size() == 1 and Auction.lots().filter(func(l): return String(l["seller"]) == "you").size() == 1
		and Shelter.cards().any(func(c): return String(c["from"]) != "") and Transfer.outbox().size() == 1
		and int(Save.d["gems"]) == gems,
		"your stall, auction, shelter card and transfer survive a save/load")
	ok(Stalls.unlist(String(Stalls.mine()[0]["id"]))["ok"] and Goods.have("good:dye_sky") == 1,
		"and still work after it")
	DirAccess.remove_absolute(path)

## After a run you made it out of: a trophy per boss, now and then a rare material, on the results.
func _finds() -> void:
	_save()
	var out := Game.apply_result({"extracted": true, "tier": 1, "gems": 0, "stats": {"bosses": 2}, "kin_runs": [],
		"caught": []})
	var trophies := 0
	for id in Save.d["goods"]:
		if String(Goods.good(String(id))["kind"]) == "trophy": trophies += int(Save.d["goods"][id])
	ok(trophies == 2
		and (out["market_news"] as Array).filter(func(l): return String(l).begins_with("Found")).size() >= 2,
		"two bosses, two trophies, on the results screen")
	var rec: Dictionary = Save.d["roster"][0]
	rec["acc"] = "scarf"
	Goods.give("good:dye_night")
	ok(Goods.dye(rec, "dye_night") == ""
		and Goods.wear_col(rec) == Color(String(Goods.good("dye_night")["col"])) and Goods.have("good:dye_night") == 0,
		"a dye recolours what a Boki wears, and is used up")
