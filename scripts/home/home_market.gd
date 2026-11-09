class_name HomeMarket
extends RefCounted
## The market stall's panel (docs/decisions/0013-market.md): one panel, its tabs by the stall's
## level (Stalls.level). L1: the Vendor (goods for Boki and the Hunter, seeds, farm, house, selling
## crops) and the Tradewind Exchange (materials, Exchange). L2 adds the Shelter, your own stall and
## market search; L3 the Auction House (those four tabs are HomeTrade). Opened from the stall, the
## hub bar's Market button and --open=shop[:boki|hunter|seeds|farm|home|sell] / exchange[:item] / shelter / stall / search / auctions.

## [tab, the stall level that opens it]
const TABS := [["Vendor", 1], ["Exchange", 1], ["Shelter", 2], ["My stall", 2], ["Search", 2], ["Auctions", 3]]
const VENDOR_TABS := ["Boki", "Hunter", "Seeds", "Farm", "Home", "Sell"]
const HUNTER_GROUPS := {"drink": "Healing", "mend": "Healing", "repair": "Armor"}    # belt item use -> section
const OPEN_NAMES := {"shop": "Vendor", "exchange": "Exchange", "shelter": "Shelter", "stall": "My stall",
	"search": "Search", "auctions": "Auctions"}
const PANEL := "Market stall"
const WIDTH := 900.0
const HOLD_H := 470.0         # px: every tab the same height

var h                         # the Home screen
var spawn_kin: Callable       # Home._spawn_kin: puts a newly adopted Boki on the island
var trade: HomeTrade
var tab := "Vendor"
var vendor_tab := "Seeds"
var item := "wood"            # the Exchange's item on show
var qty := 10
var price := 0
var note := ""
var note_col := UI.GOOD

func _init(home, spawn_kin_cb: Callable) -> void:
	h = home
	spawn_kin = spawn_kin_cb
	trade = HomeTrade.new(self)

## The tabs this stall's level opens.
func tabs() -> Array:
	var lv := Stalls.level()
	var no_exchange := FarmUnlocks.base_mode()
	return TABS.filter(func(t): return int(t[1]) <= lv and not (no_exchange and t[0] == "Exchange")) \
			.map(func(t): return String(t[0]))

## The vendor's tabs: base_mode has no Seeds (the snack patch has none) and no Sell.
static func vendor_tabs() -> Array:
	return VENDOR_TABS.filter(func(t): return not (FarmUnlocks.base_mode() and t in ["Seeds", "Sell"]))

## --open=<name> from the home screen. Returns true if it was one of ours.
func open_named(which: String) -> bool:
	var base := which.get_slice(":", 0)
	if not OPEN_NAMES.has(base):
		return false
	if base == "shop" and VENDOR_TABS.has(which.get_slice(":", 1).capitalize()):
		vendor_tab = which.get_slice(":", 1).capitalize()
	if base == "exchange" and ":" in which: item = which.get_slice(":", 1)
	open(String(OPEN_NAMES[base]))
	return true

## Opens the panel (on `which`, or the last tab).
func open(which := "") -> void:
	if which != "": tab = which
	if not tabs().has(tab): tab = "Vendor"
	var v: VBoxContainer = h._new_panel(PANEL, WIDTH, true)
	UI.hold(v, HOLD_H)
	UI.head_extra(v).add_child(UI.chip("gem", str(int(Save.d["gems"])), UI.GOLD, "Your gems"))
	UI.shell_tabs(v, tabs(), tab, func(t): open(t))
	match tab:
		"Vendor": _vendor(v)
		"Exchange": _exchange(v)
		"Shelter": trade.shelter(v)
		"My stall": trade.stall(v)
		"Search": trade.search(v)
		"Auctions": trade.auctions(v)
	_next_level(v)

## Something to say at the bottom of the tab after an action.
func say(t: String, good := true) -> void:
	note = t
	note_col = UI.GOOD if good else UI.BAD

func show_note(v: VBoxContainer) -> void:
	if note == "":
		return
	var nl := UI.label(note, 14, note_col)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nl)
	note = ""

## One line about what the next stall level opens (nothing more about the future).
func _next_level(v: VBoxContainer) -> void:
	var lv := Stalls.level()
	if lv >= 3:
		return
	var nxt := String(Goods.rules()["stall"]["levels"][str(lv + 1)])
	var l := UI.para("Upgrade the stall (build mode, Upgrades) and it opens: %s." % nxt, 12, UI.FAINT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(UI.spacer(4))
	v.add_child(l)

# ------------------------------------------------------------------ the Vendor
## The vendor's goods in tabs by who they are for (Boki, Hunter, the farm, the house), as cards under
## section headers. Some only go on sale once you've made it out of enough expeditions or finished a
## challenge; wear and utility restock by rarity (Stalls.vendor_has).
func _vendor(v: VBoxContainer) -> void:
	UI.subtitle(v, "Goods for your Boki, your Hunter, the farm and the house")
	var row := UI.hbox(6)
	for t in vendor_tabs():
		var tt: String = t
		row.add_child(UI.choice(tt, vendor_tab == tt, func(): vendor_tab = tt; open(), 0))
	v.add_child(row)
	if vendor_tab == "Sell":
		_vendor_sell(v)
		return
	var sections := _vendor_sections().filter(func(s): return not (s[1] as Array).is_empty())
	if sections.is_empty():
		v.add_child(UI.empty_state("shop", "Nothing for sale", "Come back after your next expedition."))
	for sec in sections:
		var goods: Array = sec[1]
		goods.sort_custom(func(a, b): return int(Progress.unlocked(a[0])) > int(Progress.unlocked(b[0])))
		if sections.size() > 1:
			v.add_child(UI.section(String(sec[0])))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		for g in goods:
			grid.add_child(_vendor_card(g))
		v.add_child(grid)

## [[section title, goods]] for the vendor's tab. A good is [key, name, description, price, colour,
## on_buy, owned_text]; every description starts with who uses it and how.
func _vendor_sections() -> Array:
	match vendor_tab:
		"Boki": return [["Food and treats", _boki_food()], ["Wear", _boki_wear()]]
		"Hunter": return _hunter_sections()
		"Seeds": return [["Seeds", _seed_goods()]]
		"Home": return [["Furniture", _home_goods()]]
		"Farm": return [["Farm", _farm_goods()]]
	return []

func _seed_goods() -> Array:
	var goods: Array = []
	for c in Data.CROPS:
		var cd: Dictionary = Data.CROPS[c]
		var ck: String = c
		var have := "have %d" % int(Save.d.get("seeds", {}).get(c, 0))
		goods.append(["seed:" + c, "%s seeds" % cd["name"], "Plant on a farm plot. " + String(cd["desc"]),
			int(cd["price"]), cd["color"], func():
				Save.add_seed(ck, 1)
				FarmTutorial.event("buy"), have])
	return goods

func _boki_food() -> Array:
	var goods: Array = []
	for f in Care.FOODS:
		var fd: Dictionary = Care.FOODS[f]
		var fk: String = f
		var desc := "Boki eat this. Feed it from a Boki's card. " + String(fd["desc"])
		goods.append(["food:" + f, fd["name"], desc, int(fd["price"]), Color("ffb36a"),
			func(): Save.add_item(fk, 1), "have %d" % int(Save.d["items"].get(f, 0))])
	return goods

func _boki_wear() -> Array:
	var goods: Array = []
	var owned: Array = Save.d.get("accs", [])
	for a in Data.ACCS:
		var ak: String = a
		if not owned.has(ak) and not Stalls.vendor_has("wear:" + ak): continue
		var ad: Dictionary = Data.ACCS[ak]
		var cost := -1 if owned.has(ak) else int(ad["price"])
		var desc := "Boki wear. Put it on from a Boki's card (Dress); worn on expeditions too."
		goods.append(["acc:" + ak, ad["name"], desc, cost, ad["col"],
			func(): Goods.give("wear:" + ak), "yours" if owned.has(ak) else ""])
	return goods

## Everything the Hunter carries into a match (the utility belt), under what it does.
func _hunter_sections() -> Array:
	var by_use := {"Healing": [], "Armor": [], "Gadgets": []}
	var belt := "belt keys %s to %s" % [Settings.key_cap(UtilityBelt.KEYS[0]), Settings.key_cap(UtilityBelt.KEYS[-1])]
	for uid in UtilityBelt.stock_ids():      # HomeBelt picks what to take
		var ui: String = uid
		if ui != "tonic" and not Stalls.vendor_has("util:" + ui): continue
		var desc := "Hunter, in a match (%s). %s" % [belt, UtilityBelt.def(ui)["desc"]]
		by_use[HUNTER_GROUPS.get(UtilityBelt.def(ui).get("use", ""), "Gadgets")].append([ui, UtilityBelt.name_of(ui), desc,
			UtilityBelt.price_of(ui), UtilityBelt.col_of(ui), func(): Save.add_item(ui, 1), "have %d" % Equal.stash_of(ui)])
	return by_use.keys().map(func(k): return [k, by_use[k]])

func _home_goods() -> Array:
	var goods: Array = []
	for f in Data.FURN:
		var fd: Dictionary = Data.FURN[f]
		var fk: String = f
		var desc := "Furniture for your house or a cottage. It waits in your inventory until placed."
		goods.append(["furn:" + f, fd["name"], desc, int(fd["price"]), Color("c8a07a"), func():
				if not Save.d.has("furniture"): Save.d["furniture"] = {}
				Save.d["furniture"][fk] = int(Save.d["furniture"].get(fk, 0)) + 1, "have %d" % int(Save.d.get("furniture", {}).get(f, 0))])
	return goods

func _farm_goods() -> Array:
	var goods: Array = [] if FarmUnlocks.base_mode() else HomeGather.shop_goods() + h.hecon.shop_goods()
	# the Incubator by the Nook: coals to warm Rare Eggs faster, and more cradles
	goods.append(["coals", "Ember Coals", "Stoke them into the Incubator's brazier: every Rare Egg warms twice as fast for %d minutes." % int(Incubator.COAL_SECS / 60.0),
		Incubator.COAL_PRICE, Color("ff9a4a"), func(): Save.add_item("coals", 1), "have %d" % int(Save.d["items"].get("coals", 0))])
	var icost := Incubator.slot_cost()
	goods.append(["incub_slot", "Incubator cradle", "One more cradle by the Nesting Nook: warm another Rare Egg at the same time (up to %d)." % Incubator.MAX_SLOTS,
		icost, Color("ffd36a"), func():
			Save.d["gems"] = int(Save.d["gems"]) + maxi(0, icost)      # Incubator.expand charges it
			Incubator.expand()
			if h.hinc: h.hinc.refresh(), "%d cradles" % Incubator.slots()])
	if int(Save.d["plot_cap"]) < 8:
		goods.append(["plots", "Two more plots", "Grow more at once.", 120 + 80 * (int(Save.d["plot_cap"]) - 4), Color("9c7a52"), func():
			Save.d["plot_cap"] = int(Save.d["plot_cap"]) + 2
			h._build_plots()
			if h.fs and h.plots.size() < int(Save.d["plot_cap"]):
				h._toast("Put down another crop patch for them (Build, Buildings)"), "%d plots" % int(Save.d["plot_cap"])])
	return goods

## One good as a compact row: its icon, name (and what you own), one line of description (all of
## it on hover), and its price to press.
func _vendor_card(g: Array) -> Control:
	var key: String = g[0]
	var is_open := Progress.unlocked(key)
	var cost: int = g[3]
	var col: Color = Color(g[4])
	var card := UI.card(UI.CARD if is_open else Color(0.1, 0.11, 0.15, 0.9), 10, 12)
	card.custom_minimum_size = Vector2(404, 0)
	card.tooltip_text = String(g[2]) + ("" if is_open else "\n" + Progress.req_text(key))
	var hr := UI.hbox(10)
	card.add_child(hr)
	var icons := {"seed": "seed", "food": "heart", "tonic": "tonic", "acc": "paw", "furn": "home", "plots": "seed",
		"coals": "dash", "incub_slot": "egg", "tool": "hammer"}
	var sw := UI.badge("lock", UI.FAINT, 32.0, UI.R_CTRL)
	if is_open: sw = UI.badge(String(icons.get(key.split(":")[0], "gem")), col, 32.0, UI.R_CTRL)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(sw)
	var nv := UI.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UI.hbox(6)
	var nm := UI.label(String(g[1]), UI.T_BODY, UI.INK if is_open else UI.MUTED, UI.semi)
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	if is_open and String(g[6]) != "":
		top.add_child(UI.label(String(g[6]), 12, UI.GOOD if String(g[6]) == "yours" else UI.MUTED))
	nv.add_child(top)
	var d := UI.label(Progress.req_text(key), 12, Color("ffb3a8"))
	if is_open: d = UI.label(String(g[2]), 12, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	d.clip_text = true
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nv.add_child(d)
	hr.add_child(nv)
	if is_open and cost >= 0:
		hr.add_child(price_tag(cost, g[5]))
	return card

## A price you press: gold on an outline, so a page of goods isn't a wall of orange. on_buy runs
## after the gems are taken.
func price_tag(cost: int, on_buy: Callable) -> Button:
	var b := UI.button(str(cost), func():
		if int(Save.d["gems"]) < cost: return
		Save.d["gems"] = int(Save.d["gems"]) - cost
		on_buy.call()
		Sfx.play("pickup")
		Save.save_game()
		h._refresh_top()
		open(), 76, "gem")
	b.add_theme_color_override("font_color", UI.GOLD)
	b.add_theme_color_override("font_hover_color", Color("ffe08a"))
	b.tooltip_text = "Buy for %d gems" % cost
	if int(Save.d["gems"]) < cost:
		b.disabled = true
		b.tooltip_text = "You need %d more gems" % (cost - int(Save.d["gems"]))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

func _vendor_sell(v: VBoxContainer) -> void:
	var sell_any := false
	for s in Data.CROPS:
		var n := int(Save.d["crops"].get(s, 0))
		if n <= 0: continue
		sell_any = true
		var sk: String = s
		var gain := maxi(1, int(round(int(Data.CROPS[s]["price"]) * 0.4)))
		var rc := UI.card(UI.CARD, 10, 12)
		var row := UI.hbox(12)
		rc.add_child(row)
		row.add_child(UI.IconDot.new("seed", Data.CROPS[s]["color"], 22.0))
		var l := UI.label("%s  ×%d" % [Data.CROPS[s]["name"], n], UI.T_BODY, UI.INK, UI.semi)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.button("Sell 1  ·  %d" % gain, func():
			if int(Save.d["crops"].get(sk, 0)) <= 0: return
			Save.d["crops"][sk] = int(Save.d["crops"][sk]) - 1
			Save.d["gems"] = int(Save.d["gems"]) + gain
			FarmTutorial.event("sell")
			Sfx.play("pickup")
			Save.save_game()
			h._refresh_top()
			open(), 140, "gem"))
		v.add_child(rc)
	if not sell_any:
		v.add_child(UI.empty_state("seed", "Nothing to sell", "Harvest your plots first, then sell spare crops here."))

# ------------------------------------------------------------------ the Exchange
func _exchange(v: VBoxContainer) -> void:
	UI.subtitle(v, "Tradewind Exchange: post a price for wood, stone, scrap, crops, food and tonics. "
		+ "Offers match the best price first; each sale pays a %d%% tax." % int(Exchange.TAX * 100))
	var tabs_row := HFlowContainer.new()
	tabs_row.add_theme_constant_override("h_separation", 6)
	tabs_row.add_theme_constant_override("v_separation", 6)
	for it in Exchange.ORDER:
		var ik: String = it
		tabs_row.add_child(UI.choice("%s  %d" % [Exchange.name_of(it), Exchange.have(it)], item == it, func():
			item = ik
			price = 0
			open(), 0))
	v.add_child(tabs_row)
	var cols := UI.hbox(16)
	v.add_child(cols)
	cols.add_child(_exchange_book())
	cols.add_child(_exchange_offer())
	if Exchange.BACKEND == "local":
		v.add_child(UI.para("Offline: Tradewind's traders fill the other side. "
			+ "With the online backend, every offer here is another player's.", 11, UI.FAINT))

## Left: the book and the price history.
func _exchange_book() -> Control:
	var left := UI.vbox(8)
	left.custom_minimum_size = Vector2(400, 0)
	left.add_child(UI.section("%s  ·  order book" % Exchange.name_of(item)))
	var bk := Exchange.book(item)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 3)
	for hd in ["Buying", "Price", "Price", "Selling"]:
		grid.add_child(UI.label(hd, 12, UI.FAINT))
	var n := maxi((bk["buys"] as Array).size(), (bk["sells"] as Array).size())
	for i in mini(n, 6):
		var b: Array = bk["buys"][i] if i < (bk["buys"] as Array).size() else []
		var s: Array = bk["sells"][i] if i < (bk["sells"] as Array).size() else []
		grid.add_child(UI.label(str(b[1]) if not b.is_empty() else "", 14, UI.INK))
		grid.add_child(UI.label(str(b[0]) if not b.is_empty() else "", 14, UI.GOOD, UI.semi))
		grid.add_child(UI.label(str(s[0]) if not s.is_empty() else "", 14, Color("ff9a8a"), UI.semi))
		grid.add_child(UI.label(str(s[1]) if not s.is_empty() else "", 14, UI.INK))
	left.add_child(grid)
	left.add_child(UI.section("Price history"))
	left.add_child(PriceGraph.new(Exchange.history(item), Exchange.ref_price(item)))
	return left

## Right: your offer, and your open offers.
func _exchange_offer() -> Control:
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UI.section("Your offer"))
	if price <= 0: price = Exchange.ref_price(item)
	var bd := Exchange.band(item)
	var qrow := UI.hbox(6)
	qrow.add_child(UI.label("Amount", 13, UI.MUTED))
	for dq in [-10, -1, 1, 10]:
		var ddq: int = dq
		qrow.add_child(UI.button(("%+d" % dq), func(): qty = clampi(qty + ddq, 1, 999); open(), 44))
	qrow.add_child(UI.label(str(qty), 16, UI.INK, UI.semi))
	right.add_child(qrow)
	var prow := UI.hbox(6)
	prow.add_child(UI.label("Each", 13, UI.MUTED))
	for dp in [-1, 1]:
		var ddp: int = dp
		prow.add_child(UI.button(("%+d" % dp), func(): price = clampi(price + ddp, bd.x, bd.y); open(), 44))
	prow.add_child(UI.label("%d gems" % price, 16, UI.GOLD, UI.semi))
	prow.add_child(UI.label("(%d-%d)" % [bd.x, bd.y], 12, UI.FAINT))
	right.add_child(prow)
	var act := UI.hbox(8)
	act.add_child(UI.primary("Buy %d for %d" % [qty, qty * price], func(): _post("buy"), 0, "gem"))
	act.add_child(UI.button("Sell %d (have %d)" % [qty, Exchange.have(item)], func(): _post("sell"), 0, "gem"))
	right.add_child(act)
	show_note(right)
	right.add_child(UI.spacer(2))
	right.add_child(UI.section("Your open offers"))
	var mine := Exchange.mine()
	if mine.is_empty():
		right.add_child(UI.para("None. An offer that doesn't match right away waits on the book (your gems or goods held) and fills while you're out on expeditions.", 12, UI.FAINT))
	for o in mine:
		var oid := String(o["id"])
		var r := UI.hbox(8)
		var ol := UI.label("%s %d/%d %s at %d" % ["Buying" if o["side"] == "buy" else "Selling", int(o["qty"]) - int(o["left"]), int(o["qty"]),
			Exchange.name_of(String(o["item"])), int(o["price"])], 13, UI.INK)
		ol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(ol)
		r.add_child(UI.button("Cancel", func(): Exchange.cancel(oid); h._refresh_top(); open(), 80))
		right.add_child(r)
	return right

func _post(side: String) -> void:
	var r := Exchange.post(side, item, qty, price)
	if r["ok"]:
		Sfx.play("pickup")
		var f := int(r["filled"])
		if f >= qty: say("%s %d %s." % ["Bought" if side == "buy" else "Sold", f, Exchange.name_of(item)])
		elif f > 0: say("%s %d now; the other %d wait on the book." % ["Bought" if side == "buy" else "Sold", f, qty - f])
		else: say("Your offer is on the book. It fills when someone meets your price.")
	else:
		Sfx.play("click")
		say(String(r["why"]), false)
	h._refresh_top()
	open()

## A small line graph of recent trade prices.
class PriceGraph extends Control:
	var pts: Array
	var ref := 0
	func _init(hist: Array, ref_p: int) -> void:
		pts = hist
		ref = ref_p
		custom_minimum_size = Vector2(380, 120)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.22))
		if pts.size() < 2:
			draw_string(UI.body, Vector2(12, size.y * 0.5), "Trades show up here (today's price %d)" % ref, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.FAINT)
			return
		var lo := 1e9
		var hi := -1e9
		for p in pts:
			lo = minf(lo, float(p[1]))
			hi = maxf(hi, float(p[1]))
		if hi - lo < 2.0:
			lo -= 1.0
			hi += 1.0
		var line := PackedVector2Array()
		for i in pts.size():
			var x := 8.0 + (size.x - 16.0) * float(i) / float(pts.size() - 1)
			var y := size.y - 12.0 - (size.y - 24.0) * (float(pts[i][1]) - lo) / (hi - lo)
			line.append(Vector2(x, y))
		draw_polyline(line, UI.GOLD, 2.0, true)
		for q in line: draw_circle(q, 2.5, UI.GOLD)
		var f: Font = UI.body
		draw_string(f, Vector2(6, 14), str(int(hi)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.FAINT)
		draw_string(f, Vector2(6, size.y - 2), str(int(lo)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.FAINT)
