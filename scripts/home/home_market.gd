class_name HomeMarket
extends RefCounted
## The farm's markets, as panels on the home screen: Wenna's Drift Pens (the Boki market, BokiPens)
## and the Tradewind Exchange (the materials order book, Exchange). Both open from the market stall
## (its "Boki" and "Exchange" tabs) and from --open=pens / --open=exchange. home.gd owns the panel.

var h                         # the Home screen
var spawn_kin: Callable       # Home._spawn_kin: puts a newly bought Boki on the island
var filter := {}              # the pens' filters: species, size, min_iv, special, kind
var item := "wood"            # the Exchange's item on show
var qty := 10
var price := 0
var note := ""
var note_col := UI.GOOD

func _init(home, spawn_kin_cb: Callable) -> void:
	h = home
	spawn_kin = spawn_kin_cb

## --open=pens / --open=exchange[:item] from the home screen. Returns true if it was one of ours.
func open_named(which: String) -> bool:
	if which == "pens":
		if "--market-demo" in OS.get_cmdline_user_args(): HomeMarket.demo()
		open_pens()
		return true
	if which.begins_with("exchange"):
		if "--market-demo" in OS.get_cmdline_user_args(): HomeMarket.demo()
		if ":" in which: item = which.split(":")[1]
		open_exchange()
		return true
	return false

## Screenshots (--market-demo): some gems, wood and stone, a week of wood trades, one of your offers
## resting on the book and one of your Boki listed at the pens. Never written to the save.
static func demo() -> void:
	Save.no_write = true
	Save.d["gems"] = maxi(int(Save.d.get("gems", 0)), 320)
	Work.ensure()
	Save.d["mats"]["wood"] = 46; Save.d["mats"]["stone"] = 18
	Save.d["scrap"] = 7
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var st := Exchange._st()
	var h: Array = []
	var px := 3.0
	for i in 28:
		px = clampf(px + rng.randf_range(-0.6, 0.7), 2.0, 6.0)
		h.append([int(Time.get_unix_time_from_system()) - (28 - i) * 3600, int(round(px)), rng.randi_range(4, 30)])
	st["hist"]["wood"] = h
	Exchange.book("wood")
	Exchange.post("sell", "wood", 12, int(ceil(Exchange.mid("wood"))) + 1)
	if (Save.d["roster"] as Array).size() < 2:
		var extra := Save.new_kin("burrlet", "Bun"); extra["level"] = 3
		Save.d["roster"].append(extra)
	var other: Dictionary = {}
	for r in Save.d["roster"]:
		if KinBox.pinned(r) == "": other = r
	if not other.is_empty() and BokiPens.listings({"kind": "player"}).is_empty():
		BokiPens.list_mine(String(other["uid"]), Ransom.value(other))

func _say(t: String, good := true) -> void:
	note = t
	note_col = UI.GOOD if good else UI.BAD

# ------------------------------------------------------------------ the Drift Pens
func open_pens() -> void:
	var v: VBoxContainer = h._new_panel("Drift Pens", 860, true)
	UI.subtitle(v, "%s's pens: ordinary Boki looking for a hunter, restocked every morning. Boki you list wait here too." % BokiPens.MERCHANT)
	UI.head_extra(v).add_child(UI.chip("gem", str(int(Save.d["gems"])), UI.GOLD, "Your gems"))
	if Lifeline.boki_count() == 0:
		v.add_child(_banner("No Boki of your own? Take a free-kit run from the expedition board (a loaner Boki, nothing at risk): one extract pays at least %d gems, enough for any Boki here." % Loaner.MIN_PAY, UI.GOLD))
	# filters
	var fr := UI.hbox(8)
	fr.add_child(UI.label("Show", 13, UI.MUTED))
	var kinds := [["", "All"], ["pen", "Wenna's"], ["player", "Listed"]]
	for kd in kinds:
		var kk: String = kd[0]
		fr.add_child(UI.choice(String(kd[1]), String(filter.get("kind", "")) == kk, func(): filter["kind"] = kk; open_pens(), 84))
	var sp_ids: Array = [""] + Data.common_kin()
	var cur_sp := String(filter.get("species", ""))
	fr.add_child(UI.button(("Species: " + String(Data.KIN[cur_sp]["name"])) if cur_sp != "" else "Species: any", func():
		filter["species"] = sp_ids[(sp_ids.find(cur_sp) + 1) % sp_ids.size()]
		open_pens(), 170))
	var ivs := [0, 80, 100, 120]
	var cur_iv := int(filter.get("min_iv", 0))
	fr.add_child(UI.button(("IVs %d+" % cur_iv) if cur_iv > 0 else "IVs: any", func():
		filter["min_iv"] = ivs[(ivs.find(cur_iv) + 1) % ivs.size()]
		open_pens(), 110))
	v.add_child(fr)
	var ls := BokiPens.listings(filter)
	if ls.is_empty():
		v.add_child(UI.empty_state("paw", "Nothing here", "Nothing matches those filters today. Come back tomorrow for fresh stock."))
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10)
	for L in ls:
		grid.add_child(_pen_card(L))
	v.add_child(grid)
	# your listings, and listing one of yours
	v.add_child(UI.spacer(4))
	v.add_child(UI.section("Sell one of yours"))
	var sell_row := UI.hbox(8)
	var choices: Array = (Save.d["roster"] as Array).filter(func(r): return KinBox.pinned(r) == "" and BokiPens.can_list(r))
	var rules := UI.para("Your partner, your first Boki and your only Boki stay with you, and so do Boki that came from the pens (or wandered in). Up to %d others can be listed at a fair price (a 5%% listing fee, and 5%% of the sale)." % BokiPens.MAX_LISTED, 12, UI.FAINT)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rules)
	if not (choices.is_empty() or (Save.d["roster"] as Array).size() <= 1):
		for r in choices.slice(0, 4):
			var rr: Dictionary = r
			var ask := Ransom.value(rr)
			sell_row.add_child(UI.button("%s  ·  %d" % [rr["name"], ask], func():
				var res := BokiPens.list_mine(String(rr["uid"]), ask)
				_say(("Listed %s for %d gems" % [rr["name"], ask]) if res["ok"] else String(res["why"]), res["ok"])
				Sfx.play("pickup" if res["ok"] else "click")
				h._refresh_top()
				open_pens(), 0, "gem"))
	v.add_child(sell_row)
	if note != "":
		v.add_child(UI.label(note, 14, note_col))
		note = ""

func _banner(t: String, col: Color) -> Control:
	var c := UI.card(Color(col, 0.12), 12, 10)
	var l := UI.para(t, 13, col)
	l.custom_minimum_size = Vector2(780, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(l)
	return c

func _pen_card(L: Dictionary) -> Control:
	var rec: Dictionary = L["rec"]
	var sp: Dictionary = Data.KIN[String(rec["species"])]
	var mine: bool = String(L.get("seller", "")) == "you"
	var card := UI.card(UI.CARD, 10, 12)
	card.custom_minimum_size = Vector2(404, 0)
	var row := UI.hbox(10); card.add_child(row)
	var pv: Control = KinPortrait.view(rec, h.get_tree(), 60.0) if KinPortrait.available() else UI.IconDot.new("paw", sp["color"], 26.0)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pv)
	var info := UI.vbox(2); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UI.hbox(6)
	top.add_child(UI.label(String(sp["name"]), UI.T_BODY, UI.INK, UI.semi))
	top.add_child(UI.tag(Unique.size_tag(rec), Color("bfe9ff")))
	if mine: top.add_child(UI.tag("Yours", UI.GOLD))
	info.add_child(top)
	info.add_child(UI.label("Level %d  ·  IVs %d/%d  ·  %s" % [int(rec.get("level", 1)), Care.iv_total(rec), Care.IV_MAX * Care.IV_KEYS.size(), String(sp.get("type", "")).capitalize()], 12, UI.MUTED))
	info.add_child(UI.label(("Listed by you" if mine else "From %s's pens" % BokiPens.MERCHANT), 12, UI.FAINT))
	row.add_child(info)
	var lid := String(L["id"])
	if mine:
		row.add_child(UI.button("Take down", func():
			var r := BokiPens.unlist(lid)
			_say("%s came back to the farm" % rec["name"] if r["ok"] else String(r["why"]), r["ok"])
			open_pens(), 110))
	else:
		var b := UI.button(str(int(L["price"])), func():
			var r := BokiPens.buy(lid)
			if r["ok"]:
				Sfx.play("unlock")
				_say("%s is yours. It's waiting on the farm." % Data.KIN[String(r["rec"]["species"])]["name"])
				h._refresh_top()
				spawn_kin.call()
			else:
				Sfx.play("click")
				_say(String(r["why"]), false)
			open_pens(), 80, "gem")
		b.add_theme_color_override("font_color", UI.GOLD)
		b.disabled = int(Save.d["gems"]) < int(L["price"])
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	return card

# ------------------------------------------------------------------ the Exchange
func open_exchange() -> void:
	var v: VBoxContainer = h._new_panel("Tradewind Exchange", 900, true)
	UI.subtitle(v, "Post a price for wood, stone, scrap, crops, food and tonics. Offers match the best price first; each sale pays a %d%% tax." % int(Exchange.TAX * 100))
	UI.head_extra(v).add_child(UI.chip("gem", str(int(Save.d["gems"])), UI.GOLD, "Your gems"))
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6); tabs.add_theme_constant_override("v_separation", 6)
	for it in Exchange.ORDER:
		var ik: String = it
		tabs.add_child(UI.choice("%s  %d" % [Exchange.name_of(it), Exchange.have(it)], item == it, func(): item = ik; price = 0; open_exchange(), 0))
	v.add_child(tabs)
	var cols := UI.hbox(16)
	v.add_child(cols)
	# left: the book and the price history
	var left := UI.vbox(8); left.custom_minimum_size = Vector2(400, 0)
	cols.add_child(left)
	left.add_child(UI.section("%s  ·  order book" % Exchange.name_of(item)))
	var bk := Exchange.book(item)
	var grid := GridContainer.new(); grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22); grid.add_theme_constant_override("v_separation", 3)
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
	# right: your offer, and your open offers
	var right := UI.vbox(8); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UI.section("Your offer"))
	if price <= 0: price = Exchange.ref_price(item)
	var bd := Exchange.band(item)
	var qrow := UI.hbox(6)
	qrow.add_child(UI.label("Amount", 13, UI.MUTED))
	for dq in [-10, -1, 1, 10]:
		var ddq: int = dq
		qrow.add_child(UI.button(("%+d" % dq), func(): qty = clampi(qty + ddq, 1, 999); open_exchange(), 44))
	qrow.add_child(UI.label(str(qty), 16, UI.INK, UI.semi))
	right.add_child(qrow)
	var prow := UI.hbox(6)
	prow.add_child(UI.label("Each", 13, UI.MUTED))
	for dp in [-1, 1]:
		var ddp: int = dp
		prow.add_child(UI.button(("%+d" % dp), func(): price = clampi(price + ddp, bd.x, bd.y); open_exchange(), 44))
	prow.add_child(UI.label("%d gems" % price, 16, UI.GOLD, UI.semi))
	prow.add_child(UI.label("(%d-%d)" % [bd.x, bd.y], 12, UI.FAINT))
	right.add_child(prow)
	var act := UI.hbox(8)
	act.add_child(UI.primary("Buy %d for %d" % [qty, qty * price], func(): _post("buy"), 0, "gem"))
	act.add_child(UI.button("Sell %d (have %d)" % [qty, Exchange.have(item)], func(): _post("sell"), 0, "gem"))
	right.add_child(act)
	if note != "":
		var nl := UI.label(note, 14, note_col); nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(nl)
		note = ""
	right.add_child(UI.spacer(2))
	right.add_child(UI.section("Your open offers"))
	var mine := Exchange.mine()
	if mine.is_empty():
		right.add_child(UI.para("None. An offer that doesn't match right away waits on the book (your gems or goods held) and fills while you're out on expeditions.", 12, UI.FAINT))
	for o in mine:
		var oid := String(o["id"])
		var r := UI.hbox(8)
		var ol := UI.label("%s %d/%d %s at %d" % ["Buying" if o["side"] == "buy" else "Selling", int(o["qty"]) - int(o["left"]), int(o["qty"]), Exchange.name_of(String(o["item"])), int(o["price"])], 13, UI.INK)
		ol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(ol)
		r.add_child(UI.button("Cancel", func(): Exchange.cancel(oid); h._refresh_top(); open_exchange(), 80))
		right.add_child(r)
	if Exchange.BACKEND == "local":
		v.add_child(UI.para("Offline: Tradewind's traders fill the other side. With the online backend, every offer here is another player's.", 11, UI.FAINT))

func _post(side: String) -> void:
	var r := Exchange.post(side, item, qty, price)
	if r["ok"]:
		Sfx.play("pickup")
		var f := int(r["filled"])
		if f >= qty: _say("%s %d %s." % ["Bought" if side == "buy" else "Sold", f, Exchange.name_of(item)])
		elif f > 0: _say("%s %d now; the other %d wait on the book." % ["Bought" if side == "buy" else "Sold", f, qty - f])
		else: _say("Your offer is on the book. It fills when someone meets your price.")
	else:
		Sfx.play("click")
		_say(String(r["why"]), false)
	h._refresh_top()
	open_exchange()

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
		var lo := 1e9; var hi := -1e9
		for p in pts:
			lo = minf(lo, float(p[1])); hi = maxf(hi, float(p[1]))
		if hi - lo < 2.0: lo -= 1.0; hi += 1.0
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
