class_name Shops
extends RefCounted
## In-match shops: vendors at the fixed spots a hand-made map lists (islands[].shops), each with a
## stock theme (content/rules/shops.json, ShopStock). Walk up and press the use key to open the
## panel (ShopPanel). Vendors sell for the gems a hunter picked up this run.
##
## Online, the host keeps each row's `left`: a buyer sends "sbuy" [shop, row, buyer], the host
## answers every game with "sgot" [shop, row, buyer, left] (or "sno" when it was gone), and the buyer's
## own game hands over the item and takes the gems when it sees its own "sgot".
##
## For other parts: Shops.list(m) -> vendors {idx, pos, theme, rows, node, island}; Shops.buy(m, h, v, i)
## -> "" or the reason it failed; Shops.legend_rows(m) -> what the full map shows.

const BOB_HEIGHT := 0.12      # m: the lantern's bob
const TOAST_COL := Color("ffd27a")

static func list(m) -> Array:
	return _st(m)["list"]

static func _st(m) -> Dictionary:
	if not m.has_meta("shops"):
		m.set_meta("shops", {"list": [], "pending": {}, "panel": null, "vendor": null})
	return m.get_meta("shops")

## Stands every vendor the map lists and stocks them (not in the arena, duels or training).
static func build(m) -> void:
	var s := _st(m)
	(s["list"] as Array).clear()
	if m.opts.get("arena", false) or m.opts.get("duel", false) or m.opts.get("training", false):
		return
	for ii in m.world.islands.size():
		for sp in m.world.islands[ii].get("shops", []):
			var v := {"idx": (s["list"] as Array).size(), "pos": sp["pos"], "theme": String(sp["theme"]), "island": ii}
			v["rows"] = ShopStock.stock_of(String(v["theme"]))
			var n := ShopModels.stall(String(v["theme"]))
			n.position = v["pos"]
			m.add_child(n)
			v["node"] = n
			(s["list"] as Array).append(v)

static func update(m, dt: float) -> void:
	var s := _st(m)
	for v in s["list"]:
		var bob := (v["node"] as Node3D).get_node("Bob") as Node3D
		bob.position.y = 2.7 + sin(m.time * 2.0 + float(v["idx"])) * BOB_HEIGHT
		(bob.get_child(0) as Node3D).rotation.y += dt * 1.5
	var v = s["vendor"]
	if v != null and (m.player == null or not near(m, m.player, v) or m.player.out or m.player.downed):
		close(m)

static func near(_m, h, v: Dictionary, reach := 0.0) -> bool:
	var r := float(ShopStock.rules().get("use_radius", 2.8)) + reach
	return h.flat_dist(v["pos"]) < r and absf(h.pos.y - float(v["pos"].y)) < 1.5

## The vendor within reach of a hunter, or {}.
static func vendor_near(m, h, reach := 0.0) -> Dictionary:
	for v in list(m):
		if near(m, h, v, reach):
			return v
	return {}

## The use prompt for the interact chain (empty when no vendor is close).
static func prompt(m, h) -> Dictionary:
	var v := vendor_near(m, h)
	if v.is_empty():
		return {}
	var th := ShopStock.theme(String(v["theme"]))
	var open: bool = _st(m)["vendor"] == v
	var verb := "close" if open else "shop at %s  ·  %s" % [th["name"], String(th["tag"]).to_lower()]
	return {"kind": "shop", "vendor": v, "label": "Press %s to %s" % [Settings.key_cap("interact"), verb],
		"col": Color(String(th["col"]))}

## The use key at a vendor: opens the panel, or closes it.
static func use(m, h, best: Dictionary) -> void:
	if h != m.player or m.hud == null:
		return
	var s := _st(m)
	if s["vendor"] == best["vendor"]:
		close(m)
		return
	close(m)
	s["vendor"] = best["vendor"]
	s["panel"] = ShopPanel.open(m, best["vendor"])
	Sfx.play("whoosh", null, -10.0, 0.05, 1.3)

static func close(m) -> void:
	var s := _st(m)
	s["vendor"] = null
	var p = s["panel"]
	s["panel"] = null
	if p != null and is_instance_valid(p):
		m.hud.ui_extra.erase(p)
		(p as Node).queue_free()

# ------------------------------------------------------------------ buying

## One purchase by a hunter of this game (the player or a bot). "" on success (or sent), else why not.
static func buy(m, h, v: Dictionary, i: int) -> String:
	var row: Dictionary = v["rows"][i]
	var why := why_not(h, row)
	if why != "":
		return why
	if m.net_on and not m.is_host:
		var pend: Dictionary = _st(m)["pending"]
		if pend.has(h.nid):
			return "One moment"
		pend[h.nid] = true
		m.net_event(["sbuy", int(v["idx"]), i, h.nid])
		return ""
	return _complete(m, h, v, i)

static func _complete(m, h, v: Dictionary, i: int) -> String:
	var row: Dictionary = v["rows"][i]
	var gems_before: int = h.gems
	if not ShopStock.sell(h, row):
		return "Can't buy that"
	row["left"] = int(row["left"]) - 1
	if m.net_on:
		m.net_event(["sgot", int(v["idx"]), i, h.nid, row["left"]])
	_bought(m, h, row, gems_before - int(h.gems))
	return ""

## Why a hunter can't buy this row (sold out, or ShopStock.can_buy's reason); "" when they can.
static func why_not(h, row: Dictionary) -> String:
	return "Sold out" if int(row["left"]) <= 0 else ShopStock.can_buy(h, row)

static func _bought(m, h, row: Dictionary, paid: int) -> void:
	var s := _st(m)
	if h == m.player and s["panel"] != null and is_instance_valid(s["panel"]):
		ShopPanel.refresh(m, s["panel"], s["vendor"])
	var col := ShopStock.col_of(row)
	m.sfx("bond", h.pos, -6.0, 1.5)
	m.fx.ring(h.pos, 1.3, col, 0.3)
	if h == m.player and m.hud:
		m.hud.toast_small("Bought %s  ·  %d gems left" % [ShopStock.name_of(row), int(h.gems)], TOAST_COL)
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "-%d" % paid, TOAST_COL, false)

## Remote events: "sbuy" (the host settles it), "sgot" (a sale happened), "sno" (it was gone).
static func on_net(m, x: Array) -> void:
	var v := _vendor_by_idx(m, int(x[1]))
	if v.is_empty():
		return
	var i := int(x[2])
	var row: Dictionary = v["rows"][i]
	match String(x[0]):
		"sbuy":
			if not m.is_host:
				return
			if int(row["left"]) <= 0:
				m.net_event(["sno", int(v["idx"]), i, String(x[3]), 0])
				return
			row["left"] = int(row["left"]) - 1
			m.net_event(["sgot", int(v["idx"]), i, String(x[3]), row["left"]])
		"sgot":
			row["left"] = int(x[4])
			if m.player != null and String(x[3]) == m.player.nid:
				_st(m)["pending"].erase(m.player.nid)
				var gems_before: int = m.player.gems
				if ShopStock.sell(m.player, row):
					_bought(m, m.player, row, gems_before - int(m.player.gems))
		"sno":
			row["left"] = int(x[4])
			if m.player != null and String(x[3]) == m.player.nid:
				_st(m)["pending"].erase(m.player.nid)
				if m.hud:
					m.hud.toast_small("Sold out", Color("ff8a6a"))

static func _vendor_by_idx(m, idx: int) -> Dictionary:
	for v in list(m):
		if int(v["idx"]) == idx:
			return v
	return {}

# ------------------------------------------------------------------ the full map

## What the full map's legend shows: one row per vendor, then one per region with the area's lean.
## Rows: {kind: "shop"|"area", name, text, col, icon, pos}.
static func legend_rows(m) -> Array:
	var out: Array = []
	for v in list(m):
		var th := ShopStock.theme(String(v["theme"]))
		out.append({"kind": "shop", "name": String(th["name"]), "text": String(th["tag"]),
			"col": Color(String(th["col"])), "icon": String(th["icon"]), "pos": v["pos"]})
	if m.biomes != null:
		out.append_array(ShopLegend.area_rows(m))
	return out
