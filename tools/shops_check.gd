extends RefCounted
## --shops-check: in-match shops. Buying takes run gems and hands over the item; every shop has a
## FIXED stock from content/rules/shops.json (the same on any seed; it was seeded and random before
## ext/utilities-shops): tonic and armor kit everywhere, every other entry in exactly one shop, every
## source utility on sale somewhere except the Revive Ember; no keys, shards or match-only items are
## ever for sale; the full map's legend has a row for every vendor and every area; a bot with spare
## gems buys; the source utilities (docs/SOURCE_UTILITIES.md) each work and cost what the doc says;
## an online purchase goes buyer -> host -> every game. Prints SHOPS PASS/FAIL.

var main: Node
var fails := 0
var n := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("SHOPS %-62s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			await load("res://tools/shops_shots.gd").new().take(main, String(a).substr(12))
			main.get_tree().quit()
			return
	_stock()
	_never_sold()
	var m: Match = await _build(11)
	await _vendors(m)
	_buying(m)
	_items(m)
	_legend(m)
	await _bot(m)
	await _online()
	print("SHOPS DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _build(seed_i: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "seed": seed_i, "no_drop": true})
	m.set_process(false)
	return m

func _row(v: Dictionary, entry: String) -> int:
	for i in (v["rows"] as Array).size():
		if String(v["rows"][i]["id"]) == entry:
			return i
	return -1

func _vendor_of(m: Match, theme: String) -> Dictionary:
	for v in Shops.list(m):
		if v["theme"] == theme:
			return v
	return {}

# ------------------------------------------------------------------ stock
func _stock() -> void:
	var themes: Array = ShopStock.rules()["themes"].keys()
	var staples := ["tonic", "armor_kit"]
	var count := {}
	var every_staple := true
	var distinct := true
	var valid := true
	for t in themes:
		var ids: Array = ShopStock.stock_of(String(t)).map(func(r): return String(r["id"]))
		for s in staples:
			if not ids.has(s): every_staple = false
		var seen := {}
		for i in ids:
			seen[i] = true
			count[i] = int(count.get(i, 0)) + 1
		if seen.size() != ids.size(): distinct = false
		if ids.size() < 6: valid = false
	ok("every shop sells tonic and armor kit", every_staple)
	ok("a shop never lists the same entry twice", distinct)
	ok("every shop has a real stock (6 or more entries)", valid)
	var once := true
	for e in count:
		if not staples.has(e) and int(count[e]) != 1: once = false
	ok("every other entry is sold in exactly one shop", once)
	var missing: Array = []
	var all := ShopStock.all_entries()
	for id in UtilityBelt.stock_ids():
		if id != "revive_ember" and not all.has(id): missing.append(id)
	ok("every belt item but the Revive Ember is on sale somewhere", missing.is_empty(), str(missing))
	var same := true
	for t in themes:
		if str(ShopStock.stock_of(String(t))) != str(ShopStock.stock_of(String(t))): same = false
	ok("the stock reads the same every time", same)

func _never_sold() -> void:
	var bad: Array = []
	var allowed := ["util", "repair", "armor_up", "backpack", "boots", "perk"]
	var never: Array = ShopStock.rules()["never"]
	for e in ShopStock.all_entries():
		var kind := ShopStock.kind_of(String(e))
		var r := ShopStock.ref(String(e))
		var low := String(e).to_lower()
		if not kind in allowed or never.has(r) or low.contains("key") or low.contains("shard"):
			bad.append(e)
		if kind == "util" and (not UtilityBelt.is_item(r) or UtilityBelt.is_key(r)):
			bad.append(e)
		if kind == "boots" and not Gear.ALL.has(r):
			bad.append(e)
		if kind == "perk" and not Data.PERKS.has(r):
			bad.append(e)
	ok("no keys, shards or match-only items are for sale", bad.is_empty(), str(bad))

# ------------------------------------------------------------------ the map's vendors and buying
func _vendors(m: Match) -> void:
	var themes := {}
	for v in Shops.list(m):
		themes[v["theme"]] = true
	var four: bool = Shops.list(m).size() == 4 and themes.size() == 4
	ok("The Hollow Crown has 4 vendors, one per theme", four, str(themes.keys()))
	var on_ground := true
	for v in Shops.list(m):
		if m.world.is_void(v["pos"].x, v["pos"].z): on_ground = false
	ok("every vendor stands on ground", on_ground)
	var b: Match = await _build(12)
	var same := Shops.list(m).size() == Shops.list(b).size()
	for i in Shops.list(m).size():
		if str(Shops.list(m)[i]["rows"]) != str(Shops.list(b)[i]["rows"]): same = false
	ok("a different match seed has exactly the same stock", same)
	b.queue_free()

func _buying(m: Match) -> void:
	var h: Hunter = m.player
	var v := _vendor_of(m, "gear")
	h.gems = 500
	UtilityBelt.clear(h)
	var i := 0
	var row: Dictionary = v["rows"][i]
	var id := ShopStock.ref(String(row["id"]))
	var cost := ShopStock.price(h, row)
	var left: int = row["left"]
	ok("a poor hunter is refused", _poor_refused(m, v))
	var why := Shops.buy(m, h, v, i)
	ok("buying succeeds", why == "", why)
	ok("buy takes the price in gems", h.gems == 500 - cost, "%d" % h.gems)
	ok("buy puts the item on the belt", UtilityBelt.count(h, id) == 1)
	ok("buy uses up one of the vendor's stock", int(row["left"]) == left - 1)
	h.gems = 500
	var armor_v := _vendor_of(m, "armor")
	var up := _row(armor_v, "armor_up")
	var tier: int = h.armor_tier
	ok("an armor upgrade raises the armor tier", Shops.buy(m, h, armor_v, up) == "" and h.armor_tier == tier + 1)
	var pv := _vendor_of(m, "perks")
	var prow := 0
	for k in (pv["rows"] as Array).size():
		if ShopStock.kind_of(String(pv["rows"][k]["id"])) == "perk":
			prow = k
			break
	var perk := String(pv["rows"][prow]["id"]).get_slice(":", 1)
	ok("a perk sale grants the perk", Shops.buy(m, h, pv, prow) == "" and h.perk_n(perk) == 1)
	var mv := _vendor_of(m, "move")
	var pack: int = h.backpack
	ok("a backpack sale upgrades the pack", Shops.buy(m, h, mv, _row(mv, "backpack")) == "" and h.backpack == pack + 1)
	var boots := _row(mv, "boots:quickstep_boots")
	ok("a boots sale wears them", Shops.buy(m, h, mv, boots) == "" and String(h.gear[3]["id"]) == "quickstep_boots")

func _poor_refused(m: Match, v: Dictionary) -> bool:
	var h: Hunter = m.player
	h.gems = 0
	var id := ShopStock.ref(String(v["rows"][0]["id"]))
	var refused := Shops.buy(m, h, v, 0) == "Not enough gems" and UtilityBelt.count(h, id) == 0
	h.gems = 500
	return refused

# ------------------------------------------------------------------ the source utilities
const PRICES := {
	"deep_draught": 40, "hearth_lamp": 110, "cloud_raft": 45, "gust_fan": 40, "twin_gate": 60,
	"warp_seed": 60, "lostway_scroll": 60, "shatter_charge": 45, "thorn_wall": 40, "blight_flask": 50,
	"skyfall_charge": 60, "pilfer_pouch": 60, "lookout_lantern": 40,
	"hawk_whistle": 45, "omen_draught": 40, "bounty_banner": 60, "toss_satchel": 45,
}

func _fresh(h: Hunter, id: String) -> bool:
	h.hp = h.max_hp * 0.3
	h.armor = 0.0
	h.downed = false
	h.out = false
	UtilityBelt.clear(h)
	UtilityBelt.grant(h, id, 1)
	return UtilityBelt.use_id(h, id)

func _items(m: Match) -> void:
	var h: Hunter = m.player
	var bot: Hunter = null
	for x in m.hunters:
		if x != h and x.ctrl == "bot": bot = x
	var priced := true
	for id in PRICES:
		if UtilityBelt.price_of(id) != int(PRICES[id]): priced = false
	ok("the 17 new items cost what the doc says", priced and UtilityBelt.is_item("revive_ember"))
	var smoke: Array = []
	for id in UtilityBelt.stock_ids():
		h.pos = _vendor_of(m, "gear")["pos"]
		bot.reveal_t = 0.0
		if not _fresh(h, id) and id != "revive_ember":
			smoke.append(id)
		UtilityUse.tick(h, 30.0)
	ok("every belt item can be used without a crash", smoke.is_empty(), str(smoke))
	# drinks
	_fresh(h, "deep_draught")
	var len5: bool = is_equal_approx(h.drink_t, 5.0) and is_equal_approx(h.drink_len, 5.0)
	UtilityUse.tick(h, 6.0)
	var healed: bool = h.hp >= h.max_hp - 0.5 and UtilityBelt.count(h, "deep_draught") == 0
	ok("Deep Draught takes 5s and heals to full", len5 and healed)
	var at := h.pos
	_fresh(h, "lostway_scroll")
	UtilityUse.tick(h, 5.0)
	var warped: bool = h.flat_dist(at) > 3.0 and UtilityBelt.count(h, "lostway_scroll") == 0
	ok("Lostway Scroll carries you across the map", warped)
	# pads
	m.gpads.clear()
	h.pos = _vendor_of(m, "move")["pos"] + Vector3(3, 0, 0)
	_fresh(h, "jump_pad")
	var gp: Dictionary = m.gpads[0]
	var pad_ok: bool = is_equal_approx(float(gp["t"]), 30.0) and is_equal_approx(float(gp["arm"]), 2.0)
	pad_ok = pad_ok and UtilityBelt.max_of("jump_pad") == 2
	h.pos = gp["pos"]
	h.vel = Vector3.ZERO
	h.grounded = true
	UtilityMore.pads(m, 0.5)
	var early: bool = h.vel.y < 1.0
	UtilityMore.pads(m, 2.0)
	ok("a Spring pad arms after 2s, then launches", pad_ok and early and h.vel.y > 10.0)
	ok("and runs out 10s after its first use", float(gp["t"]) <= 10.0)
	_fresh(h, "gust_fan")
	ok("a Gust Fan lasts 60s", is_equal_approx(float((m.gpads[m.gpads.size() - 1] as Dictionary)["t"]), 60.0))
	m.gpads.clear()
	# beacons and the squad
	var nb := m.beacons.size()
	_fresh(h, "hearth_lamp")
	ok("a Hearth Lamp sets a beacon where you stand", m.beacons.size() == nb + 1 and not bool(m.beacons[nb]["used"]))
	var team := bot.team
	bot.team = h.team
	bot.out = true
	bot.gone = false
	UtilityBelt.clear(h)
	UtilityBelt.grant(h, "revive_ember", 1)
	ok("the Ember wakes a fallen squadmate", UtilityBelt.use_id(h, "revive_ember") and not bot.out)
	bot.team = team
	# fields
	var a := h.pos + Vector3(4, 0, 0)
	var b := h.pos
	h.pos = a
	var tm := bot.team
	bot.pos = b
	bot.out = false
	bot.downed = false
	UtilityMore._swap(m, a, b, 2.0)
	ok("a Twin Gate swaps what stands in each gate", bot.flat_dist(a) < 2.5 and h.flat_dist(b) < 2.5)
	var fl: int = m.fields.list.size()
	_fresh(h, "twin_gate")
	ok("and opens two gates", m.fields.list.size() == fl + 2)
	h.pos = a
	var held := {}
	for i in 6: UtilityMore._seed_tick(m, a, 1.6, 1.5, held)
	ok("a Warp Seed throws you after 1.5s inside it", h.flat_dist(a) > 1.0 or m.world.islands.size() < 2)
	h.pos = b
	h.gems = 0
	_fresh(h, "bounty_banner")
	ok("a Bounty Banner shows you to every rival", h.reveal_t >= 119.0)
	ok("only one per squad runs at a time", not UtilityUse.can_use(h, "bounty_banner"))
	m.time += 130.0
	m.fields.tick(125.0)
	ok("kept alive, it pays 150 gems and ends", h.gems == 150 and UtilityUse.can_use(h, "bounty_banner"))
	bot.pos = h.pos + Vector3(5, 0, 0)
	bot.reveal_t = 0.0
	_fresh(h, "lookout_lantern")
	m.fields.tick(0.6)
	ok("a Lookout Lantern shows rivals near it", bot.reveal_t >= 2.9)
	bot.reveal_t = 0.0
	_fresh(h, "hawk_whistle")
	ok("a Hawk Whistle shows rivals map-wide", bot.reveal_t >= 3.9)
	bot.gems = 100
	h.inp["aim"] = bot.pos
	_fresh(h, "pilfer_pouch")
	ok("a Pilfer Pouch takes half a rival's gems", bot.gems == 50, "%d" % bot.gems)
	bot.armor = 100.0
	var fx: Array = UtilityBelt.def("shatter_charge")["effects"].duplicate(true)
	Effects.run(fx, h, {"aim": bot.pos, "slot": "utility", "ability": "shatter_charge"})
	m.time += 1.0
	m._run_later()
	ok("a Shatter Charge strips most of a rival's armor", bot.armor < 50.0, "%.0f" % bot.armor)
	h.hp = h.max_hp * 0.2
	var before := h.hp
	var z := {"t": 30.0}
	var done := [false]
	UtilityMore._pack_tick(m, h.pos, z, UtilityBelt.def("toss_satchel"), done)
	ok("a Toss Satchel heals whoever grabs it, once", h.hp > before and done[0] and float(z["t"]) == 0.0)
	m.fields.clear()

# ------------------------------------------------------------------ legend
func _legend(m: Match) -> void:
	var rows := Shops.legend_rows(m)
	var shops: Array = rows.filter(func(r): return r["kind"] == "shop")
	var areas: Array = rows.filter(func(r): return r["kind"] == "area")
	var biomes := {}
	for isl in m.world.islands:
		if String(isl.get("biome", "")) != "": biomes[isl["biome"]] = true
	ok("the legend has a row for every vendor", shops.size() == Shops.list(m).size())
	ok("the legend has a row for every area", areas.size() == biomes.size(), "%d vs %d" % [areas.size(), biomes.size()])
	var texted := rows.all(func(r): return String(r["name"]) != "" and String(r["text"]) != "")
	ok("every legend row has a name and a line of text", texted)
	var stormy := areas.filter(func(r): return String(r["text"]).contains("boots"))
	ok("an area's lean comes from its loot data (the storm lands lean to boots)", stormy.size() == 1)

# ------------------------------------------------------------------ bots
func _bot(m: Match) -> void:
	var bot: Hunter = null
	for h in m.hunters:
		if h != m.player and h.ctrl == "bot":
			bot = h
	var v := _vendor_of(m, "armor")
	bot.pos = v["pos"] + Vector3(1.0, 0, 0)
	bot.gems = 10
	UtilityBelt.clear(bot)
	ok("a bot with no spare gems does not go shopping", BotShop.goal(m, bot).is_empty() and not BotShop.think(m, bot))
	bot.gems = 120
	ok("a bot with spare gems and a vendor close heads there", not BotShop.goal(m, bot).is_empty())
	var before: int = bot.gems
	ok("the bot buys", BotShop.think(m, bot) and bot.gems < before and UtilityBelt.count(bot, "tonic") == 1)
	bot.gems = 0
	await main.get_tree().process_frame

# ------------------------------------------------------------------ online
func _wire(e: Array) -> Array:
	return JSON.parse_string(JSON.stringify(e))      # (through the wire's JSON, as Net sends it)

func _online() -> void:
	var host: Match = await _build(21)
	var guest: Match = await _build(21)
	host.net_on = true
	host.is_host = true
	guest.net_on = true
	guest.is_host = false
	var hv := _vendor_of(host, "gear")
	var gv := _vendor_of(guest, "gear")
	var i := 0
	var id := ShopStock.ref(String(gv["rows"][i]["id"]))
	hv["rows"][i]["left"] = 1
	gv["rows"][i]["left"] = 1
	var p: Hunter = guest.player
	p.gems = 200
	UtilityBelt.clear(p)
	Net.out_events.clear()
	var sent := Shops.buy(guest, p, gv, i) == "" and Net.out_events.size() == 1
	ok("a guest's buy only asks the host", sent and Net.out_events[0][0] == "sbuy")
	ok("and takes nothing yet", p.gems == 200 and UtilityBelt.count(p, id) == 0)
	var ask: Array = Net.out_events.duplicate()
	Net.out_events.clear()
	for e in ask:
		host._net_ev(_wire(e), "peer")
	var sold: bool = Net.out_events.size() == 1 and Net.out_events[0][0] == "sgot"
	ok("the host answers with a sale", sold and int(hv["rows"][i]["left"]) == 0)
	for e in Net.out_events.duplicate():
		guest._net_ev(_wire(e), "host")
	ok("the guest then gets the item and pays", UtilityBelt.count(p, id) == 1 and p.gems < 200)
	ok("every game agrees the stock is gone", int(gv["rows"][i]["left"]) == 0)
	ok("a second buyer is told it is sold out", Shops.why_not(host.player, hv["rows"][i]) == "Sold out")
	ok("Net is 0.19.2 or later", Net.VERSION.naturalnocasecmp_to("0.19.2") >= 0, Net.VERSION)
	Net.out_events.clear()
	host.net_on = false
	guest.net_on = false
