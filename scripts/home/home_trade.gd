class_name HomeTrade
extends RefCounted
## The market stall's L2 and L3 tabs (docs/decisions/0013-market.md), drawn into HomeMarket's panel:
## the Shelter (adopt, give a Boki a new home, hand one to a player), your own stall, market
## search, and the Auction House. Also the dye row on a Boki's Dress card.

const STEPS := [1, 5, 25]           # gems: the price nudges on listings and auctions

var m: HomeMarket
var ask := {}                       # good key -> the price you're about to list it at
var query := ""                     # the search box
var lot_key := ""                   # the good you're about to auction
var lot_start := 0
var lot_hours := 24
var lot_friends := false
var send_to := ""                   # the player a transfer goes to

func _init(market: HomeMarket) -> void:
	m = market

## After an action: say how it went and redraw the tab.
func _done(r: Dictionary, good_text: String) -> void:
	m.say(good_text if r["ok"] else String(r["why"]), r["ok"])
	Sfx.play("pickup" if r["ok"] else "ui_deny")
	m.h._refresh_top()
	m.open()

func _confirm(head: String, text: String, yes: String, on_yes: Callable, dangerous := true) -> void:
	UI.confirm(m.h.panel_host.get_parent(), head, text, yes, on_yes, dangerous)

func _para(text: String, font_px := 13, col := UI.MUTED) -> Label:
	var l := UI.para(text, font_px, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## A good as a compact card: icon, name, a rarity tag, a line under it, and whatever goes right.
func _good_card(key: String, payload: Dictionary, sub: String, right: Control, width := 404.0) -> Control:
	var card := UI.card(UI.CARD, 10, 12)
	card.custom_minimum_size = Vector2(width, 0)
	card.tooltip_text = Goods.desc_of(key, payload)
	var hr := UI.hbox(10)
	card.add_child(hr)
	var b := UI.badge(Goods.icon_of(key, payload), Goods.col_of(key, payload), 32.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(b)
	var nv := UI.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UI.hbox(6)
	var nm := UI.label(Goods.name_of(key, payload), UI.T_BODY, UI.INK, UI.semi)
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	top.add_child(UI.tag(Goods.rarity_name(key, payload), Goods.rarity_col(key, payload)))
	nv.add_child(top)
	var sl := UI.label(sub, 12, UI.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nv.add_child(sl)
	hr.add_child(nv)
	if right != null:
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(right)
	return card

func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 8)
	return g

## A price with nudges: [-25 -5 -1] price [+1 +5 +25]. on_change gets the new price.
func _price_row(cur: int, on_change: Callable) -> HBoxContainer:
	var row := UI.hbox(4)
	for s in [-STEPS[2], -STEPS[1], -STEPS[0]] + STEPS:
		var ds: int = s
		var text := ("+%d" % ds) if ds > 0 else str(ds)
		row.add_child(UI.button(text, func():
			on_change.call(maxi(1, cur + ds))
			m.open(), 40))
		if ds == -STEPS[0]:
			row.add_child(UI.label("%d gems" % cur, 15, UI.GOLD, UI.semi))
	return row

# ------------------------------------------------------------------ the Shelter
func shelter(v: VBoxContainer) -> void:
	UI.subtitle(v, "Boki are never sold. Adopt one (the gems go to nobody), give one a new home (it pays nothing), "
		+ "or hand one to a friend.")
	var cards := Shelter.cards()
	v.add_child(UI.section("Looking for a home"))
	if cards.is_empty():
		v.add_child(_para("Nobody today. Strays turn up every morning."))
	var g := _grid()
	for c in cards:
		g.add_child(_shelter_card(c))
	v.add_child(g)
	m.show_note(v)
	v.add_child(UI.section("Give a Boki a new home"))
	var days := int(Goods.rules()["shelter"]["min_age_days"])
	v.add_child(_para("It pays nothing. Not your partner, your first or your only Boki, "
		+ "not one under %d days old, " % days + "and once a day at most. You can't adopt it back.", 12, UI.FAINT))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	var ready_ones: Array = (Save.d["roster"] as Array).filter(func(r): return Shelter.why_not(r) == "")
	for r in ready_ones.slice(0, 6):
		row.add_child(UI.button(String(r["name"]), _give_up.bind(r), 0, "paw"))
	if ready_ones.is_empty():
		row.add_child(UI.label("None of your Boki can go right now.", 13, UI.MUTED))
	v.add_child(row)
	_transfer(v)

func _give_up(rec: Dictionary) -> void:
	var nm := String(rec["name"])
	var give := func(): _done(Shelter.give_up(String(rec["uid"])), "%s is at the shelter now" % nm)
	_confirm("Give %s a new home?" % nm, "It goes to the shelter and someone else adopts it. You get nothing for it "
		+ "and can't take it back.", "Give it up", give)

func _shelter_card(c: Dictionary) -> Control:
	var rec: Dictionary = c["rec"]
	var sp: Dictionary = Data.KIN[String(rec["species"])]
	var card := UI.card(UI.CARD, 10, 12)
	card.custom_minimum_size = Vector2(404, 0)
	var row := UI.hbox(10)
	card.add_child(row)
	var pv: Control = UI.IconDot.new("paw", sp["color"], 26.0)
	if KinPortrait.available(): pv = KinPortrait.view(rec, m.h.get_tree(), 56.0)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pv)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := String(sp["name"])
	if String(rec["name"]) != title: title = "%s  ·  %s" % [rec["name"], title]
	info.add_child(UI.label(title, UI.T_BODY, UI.INK, UI.semi))
	var kind := String(sp.get("type", "")).capitalize()
	info.add_child(UI.label("Level %d  ·  %s" % [int(rec.get("level", 1)), kind], 12, UI.MUTED))
	var giver := String(c.get("from", ""))
	var story := "A stray"
	if Shelter.gave(String(rec.get("uid", ""))): story = "You gave it up: someone else will adopt it"
	elif giver != "": story = "Raised by %s" % giver
	info.add_child(UI.label(story, 12, UI.FAINT))
	row.add_child(info)
	var cid := String(c["id"])
	var b := UI.button("Adopt  ·  %d" % int(c["price"]), func():
		var r := Shelter.adopt(cid)
		if r["ok"]: m.spawn_kin.call()
		_done(r, "%s is coming home with you" % rec["name"]), 0, "gem")
	b.disabled = int(Save.d["gems"]) < int(c["price"]) or Shelter.gave(String(rec.get("uid", "")))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return card

## Handing a Boki to a named player: fee, once a week, they accept on their side.
func _transfer(v: VBoxContainer) -> void:
	v.add_child(UI.section("Hand a Boki to a player"))
	var fee := Transfer.fee()
	v.add_child(_para("A flat %d gems, one a week. They have to accept it; until then you can call it back " % fee
		+ "(fee refunded).", 12, UI.FAINT))
	var row := UI.hbox(8)
	var name_in := LineEdit.new()
	name_in.placeholder_text = "Player name"
	name_in.max_length = 24
	name_in.text = send_to
	name_in.custom_minimum_size.x = 180
	name_in.text_changed.connect(func(t): send_to = t)
	row.add_child(name_in)
	var wait := Transfer.wait_s()
	for r in (Save.d["roster"] as Array).filter(func(rr): return KinBox.pinned(rr) == "").slice(0, 4):
		var b := UI.button("Send %s" % r["name"], _send.bind(r), 0, "bond")
		b.disabled = wait > 0 or (Save.d["roster"] as Array).size() <= 1
		row.add_child(b)
	v.add_child(row)
	if wait > 0:
		v.add_child(UI.label("Your next transfer in %d h." % int(ceil(wait / 3600.0)), 12, UI.MUTED))
	for o in Transfer.outbox():
		var oid := String(o["id"])
		var orow := UI.hbox(8)
		var ol := UI.label("%s is waiting for %s to accept" % [o["rec"].get("name", "A Boki"), o["to"]], 13, UI.INK)
		ol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		orow.add_child(ol)
		orow.add_child(UI.button("Call back", func():
			var r := Transfer.recall(oid)
			if r["ok"]: m.spawn_kin.call()
			_done(r, "It came back to the farm"), 110))
		v.add_child(orow)

func _send(rec: Dictionary) -> void:
	var to := send_to
	var nm := String(rec["name"])
	var send := func(): _done(Transfer.send(String(rec["uid"]), to), "%s is waiting for %s to accept" % [nm, to])
	var terms := "It costs %d gems. %s has to accept it." % [Transfer.fee(), to]
	_confirm("Hand %s to %s?" % [nm, to], terms, "Send", send, false)

# ------------------------------------------------------------------ your stall
func stall(v: VBoxContainer) -> void:
	var fees: Dictionary = Goods.rules()["fees"]
	UI.subtitle(v, "Price your own gear, utility, Boki wear, trophies, dyes and rare materials. "
		+ "A %d%% listing fee, and %d%% of each sale." % [int(fees["list_fee"] * 100), int(fees["sale_tax"] * 100)])
	var mine := Stalls.mine()
	v.add_child(UI.section("On your stall  (%d / %d)" % [mine.size(), int(Goods.rules()["stall"]["max_listed"])]))
	var g := _grid()
	for L in mine:
		var lid := String(L["id"])
		var down := UI.button("Take down", func(): _done(Stalls.unlist(lid), "Back in your things"), 110)
		g.add_child(_good_card(String(L["key"]), L["payload"], "Asking %d gems" % int(L["price"]), down))
	v.add_child(g)
	if mine.is_empty():
		v.add_child(_para("Nothing yet. What you list waits here; offline, traders from the isles buy a fair-priced "
			+ "piece now and then."))
	m.show_note(v)
	v.add_child(UI.section("Put something up"))
	var have := Goods.mine()
	if have.is_empty():
		v.add_child(_para("You have nothing to sell yet: trophies come from bosses, rare materials from expeditions."))
	for key in have.slice(0, 8):
		v.add_child(_list_row(String(key)))

func _list_row(key: String) -> Control:
	var cur := int(ask.get(key, Stalls.npc_pays(key)))
	var low := Stalls.lowest(key)
	var right := UI.hbox(6)
	right.add_child(_price_row(cur, func(p): ask[key] = p))
	var list_it := func(): _done(Stalls.list(key, cur), "On your stall for %d gems" % cur)
	right.add_child(UI.primary("List  ·  fee %d" % Stalls.list_fee(cur), list_it, 0, "gem"))
	var market := ("lowest on the market %d" % low) if low > 0 else "nobody else has one"
	return _good_card(key, {}, "You have %d  ·  %s" % [Goods.have(key), market], right, 860.0)

# ------------------------------------------------------------------ search
func search(v: VBoxContainer) -> void:
	UI.subtitle(v, "Look an item up: the lowest prices across every stall today.")
	var box := LineEdit.new()
	box.placeholder_text = "Search: a trophy, a dye, a charm..."
	box.text = query
	box.custom_minimum_size.x = 420
	box.text_submitted.connect(_search_for)
	var row := UI.hbox(8)
	row.add_child(box)
	row.add_child(UI.button("Search", func(): _search_for(box.text), 100))
	v.add_child(row)
	m.show_note(v)
	var found := Stalls.search(query)
	if found.is_empty():
		v.add_child(UI.empty_state("shop", "Nobody is selling that", "Try another name, or check again tomorrow."))
	var g := _grid()
	for f in found.slice(0, 12):
		g.add_child(_found_card(f))
	v.add_child(g)

func _search_for(text: String) -> void:
	query = text
	m.open()

func _found_card(f: Dictionary) -> Control:
	var rows: Array = f["rows"]
	var best: Dictionary = rows[0]
	var key := String(f["key"])
	var others: Array = rows.slice(1, 3).map(func(L): return "%d" % int(L["price"]))
	var where := "your stall" if String(best["seller"]) == "you" else String(best["seller"])
	var sub := "%d at %s" % [int(best["price"]), where]
	if not others.is_empty(): sub += "  ·  then " + ", ".join(others)
	var right: Button = null
	if String(best["seller"]) != "you":
		var bid := String(best["id"])
		var buy := func(): _done(Stalls.buy(bid), "Bought %s" % Goods.name_of(key))
		right = UI.button(str(int(best["price"])), buy, 76, "gem")
		right.add_theme_color_override("font_color", UI.GOLD)
		right.disabled = int(Save.d["gems"]) < int(best["price"]) or not Goods.can_take_in(key)
	return _good_card(key, best["payload"], sub, right)

# ------------------------------------------------------------------ auctions
func auctions(v: VBoxContainer) -> void:
	for line in Auction.settle():
		m.say(String(line))
	Auction.refill()
	UI.subtitle(v, "Rare pieces go to the highest bid. Bids are held at once and come back if you're outbid; "
		+ "a bid in the last minute adds time.")
	m.show_note(v)
	var g := _grid()
	for lot in Auction.lots():
		g.add_child(_lot_card(lot))
	v.add_child(g)
	v.add_child(UI.section("Put a rare piece up"))
	var have: Array = Goods.mine()
	if have.is_empty():
		v.add_child(_para("You have nothing to put up yet."))
		return
	if not have.has(lot_key):
		lot_key = String(have[0])
		lot_start = Goods.ref_of(lot_key)
	v.add_child(_lot_pick(have))
	var start := UI.hbox(8)
	start.add_child(UI.label("Starts at", 13, UI.MUTED))
	start.add_child(_price_row(lot_start, func(p): lot_start = p))
	var step := maxi(1, int(ceil(lot_start * 0.05)))
	start.add_child(UI.label("raise by %d+" % step, 13, UI.MUTED))
	var create := func():
		var r := Auction.create(lot_key, lot_start, step, lot_hours, lot_friends)
		_done(r, "Up for auction for %d hours" % lot_hours)
	start.add_child(UI.primary("Start  ·  fee %d" % Stalls.list_fee(lot_start), create, 0, "gem"))
	v.add_child(start)

## What to put up, for how long, and whether only friends may bid.
func _lot_pick(have: Array) -> HBoxContainer:
	var pick := UI.hbox(6)
	pick.add_child(UI.button("Item: %s" % Goods.name_of(lot_key), func():
		lot_key = String(have[(have.find(lot_key) + 1) % have.size()])
		lot_start = Goods.ref_of(lot_key)
		m.open(), 0, "swap"))
	for hours in Goods.rules()["auction"]["hours"]:
		var hh := int(hours)
		pick.add_child(UI.choice("%dh" % hh, lot_hours == hh, func():
			lot_hours = hh
			m.open(), 56))
	pick.add_child(UI.choice("Friends only", lot_friends, func():
		lot_friends = not lot_friends
		m.open(), 0))
	return pick

func _lot_card(lot: Dictionary) -> Control:
	var left := int(lot["ends"]) - MarketSave.now()
	var when := ("%dh %02dm left" % [left / 3600, (left % 3600) / 60]) if left >= 60 else "ending now"
	var mine := String(lot["seller"]) == "you"
	var winning := String(lot["bidder"]) == "you"
	var top := "no bids yet"
	if int(lot["top"]) > 0:
		top = "top bid %d (%s)" % [int(lot["top"]), "you" if winning else lot["bidder"]]
	var sub := "%s  ·  %s  ·  %s" % ["Your lot" if mine else String(lot["seller"]), top, when]
	if bool(lot["friends"]): sub += "  ·  friends only"
	var right: Control = null
	if winning:
		right = UI.tag("Winning", UI.GOOD)
	elif not mine:
		var lid := String(lot["id"])
		var amount := Auction.min_bid(lot)
		var bid := func(): _done(Auction.bid(lid, amount), "You're the top bidder at %d" % amount)
		var b := UI.button("Bid %d" % amount, bid, 0, "gem")
		b.disabled = int(Save.d["gems"]) < amount
		right = b
	return _good_card(String(lot["key"]), lot["payload"], sub, right)

# ------------------------------------------------------------------ dyes
## The dyes you own, as buttons that recolour what this Boki wears (one dye each), plus its own
## colour back. null when it wears nothing or you have no dyes. on_done redraws the Boki.
static func dye_row(rec: Dictionary, on_done: Callable) -> Control:
	var owned: Array = Goods.mine().filter(func(k): return Goods.is_dye(k))
	if String(rec.get("acc", "")) == "" or (owned.is_empty() and not rec.has("dye")):
		return null
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_child(UI.label("Dye it", 13, UI.MUTED))
	for key in owned:
		var dye_id := Goods.id_of(String(key))
		var b := UI.button("%s  ×%d" % [Goods.name_of(String(key)), Goods.have(String(key))], func():
			if Goods.dye(rec, dye_id) == "": on_done.call(), 0, "paw")
		b.add_theme_color_override("font_color", Goods.col_of(String(key)))
		row.add_child(b)
	if rec.has("dye"):
		row.add_child(UI.button("Its own colour", func():
			rec.erase("dye")
			Save.save_game()
			on_done.call(), 0))
	return row
