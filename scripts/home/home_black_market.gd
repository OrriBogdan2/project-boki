class_name HomeBlackMarket
extends RefCounted
## Old Pell's Black Market (the "ransom" building; docs/decisions/0013-market.md), as a panel on the
## home screen. Tabs: Ransom (Boki nobody came back for: pay or haggle), Captured (rivals holding
## yours: an offer and a message), Their offers (rivals asking for theirs back), Rare stock (the
## premium shop, BlackMarket) and the log. The rules are Ransom and BlackMarket.
## --open=blackmarket[:ransom|captured|offers|rare|log] (or the old --open=ransom[:...]).

const PANEL := "Black Market"
const TABS := {"ransom": "Ransom", "captured": "Captured", "offers": "Their offers", "rare": "Rare stock",
	"log": "What happened"}
## The old ransom tab names still open the right tab.
const OLD_TABS := {"house": "ransom", "rivals": "captured"}

var h                       # the Home screen
var tab := "ransom"
var said := {}              # uid -> the last thing the seller said
var bids := {}              # uid -> the offer you're making
var messages := {}          # uid -> the message going with an offer to a captor

func _init(home) -> void:
	h = home

func open(which := "") -> void:
	if which != "": tab = String(OLD_TABS.get(which, which))
	if not TABS.has(tab): tab = "ransom"
	var v: VBoxContainer = h._new_panel(PANEL, 860, true)
	var lost: Array = Save.d.get("lost_kin", [])
	var at_house: Array = lost.filter(func(L): return String(L["where"]) == "ransom")
	var held: Array = lost.filter(func(L): return String(L["where"]) == "rival")
	var offers: Array = Save.d.get("offers", [])
	var holds := [Ransom.BROKER, Ransom.SELL_AFTER]
	UiShell.subtitle(v, ("%s holds the Boki nobody came for (%d expeditions), carries word to whoever took yours, " % holds)
		+ "and keeps a few rare things under the counter.")
	UiShell.head_extra(v).add_child(UiWidgets.chip("gem", str(int(Save.d["gems"])), UI.GOLD, "Your gems"))
	var names: Array = TABS.values()
	UiShell.shell_tabs(v, names, String(TABS[tab]), func(t): open(String(TABS.find_key(t))),
		{TABS["ransom"]: at_house.size(), TABS["captured"]: held.size(), TABS["offers"]: offers.size()})
	match tab:
		"ransom", "captured":
			var list: Array = at_house if tab == "ransom" else held
			if list.is_empty():
				var none := "No rival is holding any of your Boki."
				if tab == "ransom": none = "Every Boki you've lost is home or with a rival."
				v.add_child(UiWidgets.empty_state("paw", "Nobody here", none))
			for L in list:
				v.add_child(_lost_card(L))
		"offers": _offers(v, offers)
		"rare": _rare(v)
		"log":
			var lg: Array = Save.d.get("ransom_log", [])
			if lg.is_empty():
				v.add_child(UiText.label("Nothing yet.", 15, UI.MUTED))
			for i in range(lg.size() - 1, maxi(-1, lg.size() - 13), -1):
				v.add_child(UiText.label("Expedition %d: %s" % [int(lg[i]["m"]), lg[i]["text"]], 13, UI.INK))

func _offers(v: VBoxContainer, offers: Array) -> void:
	if offers.is_empty():
		v.add_child(UiWidgets.empty_state("gem", "No offers",
			"When you take home a Boki a rival left behind, they may ask to buy it back. Their offers show up here."))
	for o in offers.duplicate():
		var k := Save.kin(String(o["uid"]))
		if k.is_empty():
			(Save.d["offers"] as Array).erase(o)
			continue
		var card := UI.card(UI.CARD, 12, 12)
		var row := UI.hbox(10)
		card.add_child(row)
		var info := UI.vbox(3)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col: Color = Data.KIN[k["species"]]["color"]
		info.add_child(UiText.label("%s wants %s back" % [o["from"], k["name"]], 17, col, UI.big))
		var terms := [int(o["gems"]), int(k.get("level", 1)), int(k["trust"])]
		var line := "They're offering %d gems. It's level %d and its trust in you is %d." % terms
		info.add_child(UiText.label(line, 13, UI.MUTED))
		row.add_child(info)
		var oo: Dictionary = o
		row.add_child(UiWidgets.primary("Sell for %d" % int(o["gems"]), func():
			Ransom.sell_back(oo)
			Sfx.play("pickup")
			h._toast("%s goes back to %s. +%d gems" % [k["name"], oo["from"], int(oo["gems"])])
			h._refresh_top()
			open(), 150))
		row.add_child(UiWidgets.button("Keep it", func():
			Ransom.decline(oo)
			open(), 100))
		v.add_child(card)

## Today's rare stock: a few rare and epic pieces, and now and then a Rare Egg.
func _rare(v: VBoxContainer) -> void:
	var intro := "A few rare pieces a day, never cheap. What you buy is gone until tomorrow's stock."
	v.add_child(UiText.para(intro, 13, UI.MUTED))
	var stock := BlackMarket.stock()
	if stock.is_empty():
		v.add_child(UiWidgets.empty_state("shop", "Sold out", "Come back tomorrow."))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 8)
	for e in stock:
		g.add_child(_rare_card(e))
	v.add_child(g)

func _rare_card(e: Dictionary) -> Control:
	var key := String(e["key"])
	var egg := key.begins_with("egg:")
	var card := UI.card(UI.CARD, 10, 12)
	card.custom_minimum_size = Vector2(404, 0)
	var hr := UI.hbox(10)
	card.add_child(hr)
	var col: Color = Data.KIN[BlackMarket.id_of(key)]["color"] if egg else Goods.col_of(key)
	var b := UiWidgets.badge("egg" if egg else Goods.icon_of(key), col, 32.0, UI.R_CTRL)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(b)
	var nv := UI.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UI.hbox(6)
	var nm := UiText.label(BlackMarket.name_of(key), UI.T_BODY, UI.INK, UI.semi)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	if egg:
		top.add_child(UiWidgets.tag("Rare Egg", Color("c08cff")))
	else:
		top.add_child(UiWidgets.tag(Goods.rarity_name(key), Goods.rarity_col(key)))
	nv.add_child(top)
	var sub := UiText.label("Hatches a rare Boki on the Incubator" if egg else Goods.desc_of(key), 12, UI.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nv.add_child(sub)
	hr.add_child(nv)
	var eid := String(e["id"])
	var buy := UiWidgets.button(str(int(e["price"])), func():
		var r := BlackMarket.buy(eid)
		Sfx.play("unlock" if r["ok"] else "ui_deny")
		h._toast(("%s is yours" % BlackMarket.name_of(key)) if r["ok"] else String(r["why"]))
		h._refresh_top()
		open(), 76, "gem")
	buy.add_theme_color_override("font_color", UI.GOLD)
	buy.disabled = int(Save.d["gems"]) < int(e["price"])
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(buy)
	return card

## One lost Boki: where it is, what's asked, and your offer (with a message for a captor).
func _lost_card(L: Dictionary) -> Control:
	var rec: Dictionary = L["rec"]
	var uid := String(rec["uid"])
	var sp: Dictionary = Data.KIN[rec["species"]]
	var rival_side := String(L["where"]) == "rival"
	var card := UI.card(UI.CARD, 12, 12)
	UI.set_card_border(card, sp["color"])
	var v := UI.vbox(6)
	card.add_child(v)
	var top := UI.hbox(10)
	var title := Data.kin_title(String(rec["name"]), String(sp["name"]))
	var nm := UiText.label("%s  ·  level %d" % [title, int(rec.get("level", 1))], 18, sp["color"], UI.big)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	top.add_child(UiText.label("Asking %d" % int(L["ask"]), 16, UI.GOLD, UI.big))
	v.add_child(top)
	var selling_soon := not rival_side and int(L.get("waited", 0)) >= Ransom.SELL_AFTER - 1
	var wl := UiText.label(_where(L), 13, UI.BAD if selling_soon else UI.MUTED)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(wl)
	if said.has(uid):
		var sl := UiText.label("%s: \"%s\"" % [L["holder"] if rival_side else Ransom.BROKER, said[uid]], 14, UI.INK)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sl)
	if rival_side:
		var msg := LineEdit.new()
		msg.placeholder_text = "A message to %s with your offer (optional)" % L["holder"]
		msg.max_length = 140
		msg.text = String(messages.get(uid, ""))
		msg.text_changed.connect(func(t): messages[uid] = t)
		v.add_child(msg)
	v.add_child(_offer_row(L))
	return card

func _where(L: Dictionary) -> String:
	var waited := int(L.get("waited", 0))
	var s := "" if waited == 1 else "s"
	if String(L["where"]) == "rival":
		return ("Held by %s for %d expedition%s. " % [L["holder"], waited, s]
			+ "You may meet them out there: your bond lets you sense it nearby.")
	var left := "Sold on after your next expedition!"
	if waited < Ransom.SELL_AFTER:
		left = "Sold on after %d more." % (Ransom.SELL_AFTER - waited)
	return "Waiting here for %d expedition%s. %s" % [waited, s, left]

func _offer_row(L: Dictionary) -> HBoxContainer:
	var rec: Dictionary = L["rec"]
	var uid := String(rec["uid"])
	var row := UI.hbox(10)
	var bid := int(bids.get(uid, int(round(float(L["ask"]) * 0.75))))
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = maxi(int(L["ask"]), 1)
	sl.step = 5
	sl.value = clampi(bid, 0, int(L["ask"]))
	sl.custom_minimum_size = Vector2(240, 24)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bl := UiText.label("Offer %d" % int(sl.value), 15, UI.INK)
	bl.custom_minimum_size.x = 96
	sl.value_changed.connect(func(val):
		bids[uid] = int(val)
		bl.text = "Offer %d" % int(val))
	row.add_child(sl)
	row.add_child(bl)
	var patience := int(L.get("patience", 0))
	var ob := UiWidgets.button("Make offer", func():
		var res := Ransom.offer(L, int(bids.get(uid, int(sl.value))), String(messages.get(uid, "")))
		said[uid] = String(res["line"])
		if res["result"] == "accept":
			Sfx.play("unlock")
			h._toast("%s is coming home!" % rec["name"])
			said.erase(uid)
			messages.erase(uid)
		elif res["result"] == "counter":
			bids[uid] = int(res["ask"])
		h._refresh_top()
		open(), 130)
	ob.disabled = patience <= 0
	ob.tooltip_text = "%d more tries before they stop haggling" % patience
	if patience <= 0:
		ob.tooltip_text = "They've stopped haggling until after your next expedition."
	row.add_child(ob)
	var pay := UiWidgets.primary("Pay %d" % int(L["ask"]), func():
		if Ransom.pay(L):
			Sfx.play("unlock")
			h._toast("%s is coming home!" % rec["name"])
			said.erase(uid)
			h._refresh_top()
			open()
		else:
			h._toast("You need %d gems" % int(L["ask"])), 130)
	pay.disabled = int(Save.d["gems"]) < int(L["ask"])
	row.add_child(pay)
	return row
