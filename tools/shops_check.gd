extends RefCounted
## --shops-check: in-match shops. Buying takes run gems and hands over the item; stock is seeded
## (3 to 5 rows, the same for one seed, different across seeds); no keys, shards or match-only
## items are ever for sale; the full map's legend has a row for every vendor and every area; a bot
## with spare gems buys; an online purchase goes buyer -> host -> every game. Prints SHOPS PASS/FAIL.

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
	var sized := true
	var same := true
	var sigs := {}
	for t in themes:
		for sd in [1, 2, 3, 4, 5, 6]:
			var a := ShopStock.roll(sd, 0, String(t))
			var b := ShopStock.roll(sd, 0, String(t))
			if a.size() < 3 or a.size() > 5: sized = false
			if str(a) != str(b): same = false
			sigs[str(a)] = true
	ok("every roll is 3 to 5 items", sized)
	ok("one seed rolls the same stock every time", same)
	ok("stock differs between seeds", sigs.size() > themes.size())
	var distinct := true
	for sd in [1, 2, 3]:
		var ids: Array = ShopStock.roll(sd, 0, "gear").map(func(r): return r["id"])
		var seen := {}
		for i in ids: seen[i] = true
		if seen.size() != ids.size(): distinct = false
	ok("a vendor never stocks the same entry twice", distinct)

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
	var differs := false
	for i in Shops.list(m).size():
		if str(Shops.list(m)[i]["rows"]) != str(Shops.list(b)[i]["rows"]): differs = true
	ok("a different match seed rolls different stock", differs)
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
	var perk := String(pv["rows"][0]["id"]).get_slice(":", 1)
	ok("a perk sale grants the perk", Shops.buy(m, h, pv, 0) == "" and h.perk_n(perk) == 1)
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
	ok("the bot buys", BotShop.think(m, bot) and bot.gems < before and UtilityBelt.count(bot, "armor_kit") == 1)
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
