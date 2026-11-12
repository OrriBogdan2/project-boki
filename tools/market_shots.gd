extends RefCounted
## --market-shots=<dir>: screenshots of the market (docs/decisions/0013-market.md), run with a real
## renderer (xvfb-run, --rendering-driver opengl3, --resolution 1280x720): the stall at L1, L2 and
## L3 on a farm-start island, the stall panel at L1, the Shelter, your stall, market search, the
## Auction House, and the Black Market's Ransom, Captured and Rare stock tabs. Never touches the
## real save. Writes <name>.png and prints "MSHOT <name>|<caption>".

var main: Node
var dir := ""
var home = null

func _shot(shot_name: String, caption: String, keep_panel := false) -> void:
	for i in 3: await main.get_tree().process_frame
	if main.fade: main.fade.reveal(0.05)
	await main.get_tree().create_timer(0.3).timeout
	if not keep_panel:
		home._close_panel()
	home.set_process(false)
	if home.hover_box: home.hover_box.visible = false
	home.prompt_box.visible = false
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	home.set_process(true)
	if img.get_width() > 1280:
		img.resize(1280, int(img.get_height() * 1280.0 / img.get_width()))
	img.save_png("%s/%s.png" % [dir, shot_name])
	print("MSHOT %s|%s" % [shot_name, caption])

func _look(target: Vector3, zoom: float) -> void:
	var p := target + Vector3(2.6, 0, 0.9)
	home.ppos = p
	home.player.position = p
	home.cam.zoom_to = zoom
	home.cam.zoom = zoom
	home.cam.snap(p)

func _ready_home() -> void:
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null: break
		await main.get_tree().process_frame
	home._close_panel()
	await main.get_tree().create_timer(1.0).timeout

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--market-shots="): dir = String(a).substr(15)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	_fill_save()
	home = await main._hb_home()
	await _ready_home()
	var stalls := HomeLayout.fixtures(Save.d, "stall")
	if stalls.is_empty():
		print("MSHOT FAIL no stall on the island")
		main.get_tree().quit(1)
		return
	var stall: Dictionary = stalls[0]
	var at := HomeLayout.deco_center(stall)
	_look(at, 0.42)
	await main.get_tree().create_timer(4.0).timeout      # (the stall's toast settles first)
	await _shot("01_stall_l1",
		"Every farm-start island has its market stall from the start, set down near the portal: L1, a single vendor")
	home.hmk.open()
	await _shot("02_panel_l1",
		"The stall panel at L1: the Vendor and the Exchange, and one line on what an upgrade opens", true)
	for lv in [2, 3]:
		stall["t"] = lv
		home.hb.apply(false)
		_look(at, 0.42)
		var what := "L3: the auction bell, bunting and a gold-edged sign (Auction House)"
		if lv == 2: what = "L2: the shelter's hut and a trade sign (Shelter, your stall, search)"
		await _shot("0%d_stall_l%d" % [lv + 1, lv], "The stall upgraded to " + what)
	await _panels()
	print("MSHOT DONE")
	main.get_tree().quit()

## A played farm-start save: four grown Boki, gems, goods to trade, one Boki given up.
func _fill_save() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	Save.d["gems"] = 860
	Save.d["name"] = "Orri"
	for pair in [["cindle", "Ash"], ["burrlet", "Bun"], ["puddlet", "Drip"], ["pebbit", "Rocky"]]:
		var r := Save.new_kin(String(pair[0]), String(pair[1]))
		r["level"] = 5
		r["born"] = MarketSave.now() - 40 * 86400
		Care.ensure(r)
		Save.register(r)
		Save.d["roster"].append(r)
	for g in ["colossus_horn", "heartwood", "heartwood", "dye_gold", "silk_fibre", "serpent_scale"]:
		Goods.give("good:" + g)
	Save.d["accs"] = ["scarf", "collar"]

func _panels() -> void:
	Save.d["layout"]["fb"] = 0      # (a farm without the building pass: every tab open)
	Shelter.give_up(String(Save.d["roster"][3]["uid"]))
	Stalls.list("good:heartwood", Stalls.npc_pays("good:heartwood"))
	Stalls.list("wear:collar", 40)
	Auction.create("good:colossus_horn", 70, 4, 24, false)
	Auction.refill()
	var npc_lot: Dictionary = Auction.lots().filter(func(l): return String(l["seller"]) != "you")[0]
	Auction.bid(String(npc_lot["id"]), Auction.min_bid(npc_lot))
	home.hmk.open("Shelter")
	await _shot("05_shelter",
		"Shelter: strays and a Boki given up (raised by Orri); adopting burns the gems, giving pays nothing", true)
	home.hmk.open("My stall")
	await _shot("06_my_stall",
		"Your stall: what's listed and what you could put up, with the lowest price on the market and the fee", true)
	home.hmk.trade.query = ""
	home.hmk.open("Search")
	await _shot("07_search",
		"Market search: every good's lowest price across the stalls today, cheapest first, buy the best one", true)
	home.hmk.trade.query = "dye"
	home.hmk.open("Search")
	await _shot("08_search_dye", "Search for 'dye': the lowest prices for each dye", true)
	home.hmk.open("Auctions")
	await _shot("09_auctions",
		"Auction House: NPC lots, your lot, your winning bid, and putting a piece up (12/24/48 h, friends only)", true)
	var ash: Dictionary = Save.d["roster"][1]
	var bun: Dictionary = Save.d["roster"][2]
	Ransom.lose(ash, "ransom", "", 2)
	Ransom.lose(bun, "rival", "Vexa", 2)
	home.hbm.open("ransom")
	await _shot("10_black_market_ransom",
		"Black Market, Ransom tab: a Boki nobody came for, its asking price, haggling and paying", true)
	home.hbm.open("captured")
	await _shot("11_black_market_captured",
		"Black Market, Captured: an offer and a message to the rival who has yours", true)
	home.hbm.open("rare")
	await _shot("12_black_market_rare",
		"Black Market, Rare stock: a few rare and epic pieces a day, priced as a gem sink", true)
