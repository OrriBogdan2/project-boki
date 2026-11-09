class_name BuildEntries
extends RefCounted
## What the farm's catalog bar shows: the tiles of each tab (pieces and buildings with their prices, the Storage
## tab, upgrades and the island's own entries), in the shape BuildCatalog draws.

var hb: HomeBuild

func _init(build: HomeBuild) -> void:
	hb = build

## The price shown as icons on a tile: the construction cost, or the plain gems and materials ({} if it comes
## from storage). Lines and brushes are priced per tile.
func entry_cost(id: String) -> Dictionary:
	var c: Dictionary = HomeLayout.CATALOG[id]
	if int(hb.L()["inv"].get(id, 0)) > 0:
		return {}
	var site := hb._site_cost(id)
	if not site.is_empty():
		return site
	var out := {}
	for m in ["gems", "wood", "stone"]:
		if int(c.get(m, 0)) > 0: out[m] = int(c[m])
	return out

func model_of(id: String) -> Callable:
	return func() -> Node3D:
		return hb.make_deco({"id": id, "x": 0, "z": 0, "r": 0, "u": 1, "c": HomeLayout.COLOURS[0],
			"sp": String(Save.active_kin().get("species", "zapple"))})

## A tile for a catalog id: picture, name, price, how many are in storage.
func catalog_entry(id: String, cb: Callable) -> Dictionary:
	var c: Dictionary = HomeLayout.CATALOG[id]
	var pc := hb.cost_of(id, 1)
	var cost := entry_cost(id)
	var in_hand: bool = hb.held.get("kind", "") == "deco" and String(hb.held.get("id", "")) == id
	in_hand = in_hand and int(hb.held.get("from", -1)) < 0
	var short: bool = int(pc[2]) == 0 and not hb._can_pay(int(pc[0]), int(pc[1]), int(pc[3]), int(pc[4]))
	var e := {"id": id, "name": String(c["name"]), "cb": cb, "cost": cost, "owned": int(hb.L()["inv"].get(id, 0)),
		"on": in_hand, "off": short, "tip": String(c.get("desc", ""))}
	if c.has("line") or c.has("brush"):
		e["swatch"] = swatch(id)
		e["note"] = "per tile" if int(c.get("gems", 0)) > 0 else "free"
		e["off"] = false
	else:
		e["model"] = model_of(id)
		if int(c.get("scrap", 0)) > 0 and int(hb.L()["inv"].get(id, 0)) == 0:
			e["note"] = "+ %d scrap" % int(c["scrap"])
	if int(e["owned"]) > 0:
		e["note"] = "from storage"
		e["off"] = false
	if cost.is_empty() and not e.has("note") :
		e["note"] = "free"
	if not hb._site_cost(id).is_empty():
		var tip := " Free to mark out. The materials are spent as it goes up: %d swings of work."
		e["tip"] = String(e["tip"]) + tip % int(cost.get("labour", 0))
	return e

func swatch(id: String) -> Color:
	var c: Dictionary = HomeLayout.CATALOG[id]
	if c.has("col"):
		return Color(String(c["col"]))
	match String(c.get("brush", "")):
		"water": return Color("4a9fd8")
		"clear": return Color("5f8d45")
		"wild": return Color("6b8f3a")
	var line_colours := {"fence": Color("a67c52"), "picket": Color("e8e2d0"), "stone_wall": Color("a9a39a"),
		"hedge": Color("3f8a45")}
	return line_colours.get(id, Color("a67c52"))

func tab(tab_name: String) -> Array:
	var out: Array = []
	var lay := hb.L()
	match tab_name:
		"Buildings":
			if hb.h.visit.is_empty():
				for kind in Econ.FEEDER_ORDER:
					var nf := int(Save.d.get("feeder_inv", {}).get(kind, 0))
					if nf > 0: out.append(feeder_entry(kind, nf))
			if hb.fs():
				for id in HomeLayout.CATALOG:
					if String(HomeLayout.CATALOG[id]["cat"]) == "Buildings":
						add_fixture_entry(out, id)
			for b in hb.h.lots:
				add_lot_entry(out, b)
		"Storage":
			add_storage(out)
		"Upgrades":
			out.append_array(FarmBuildUi.upgrade_entries(hb))
			if out.is_empty():
				out.append({"name": "Nothing to upgrade yet", "note": "Build something first",
					"cb": func(): pass, "off": true, "glyph": "hammer"})
		"Island":
			add_island_entries(out)
		_:
			for id in HomeLayout.CATALOG:
				if String(HomeLayout.CATALOG[id]["cat"]) == tab_name and FarmUnlocks.open(id):
					var iid: String = id
					out.append(catalog_entry(id, func(): hb.take(iid)))
	return out

func feeder_entry(kind: String, count: int) -> Dictionary:
	return {"id": "feeder_" + kind, "name": String(Econ.FEEDERS[kind]["name"]), "owned": count, "note": "from storage",
		"cb": func(): hb.take_feeder(kind), "model": func() -> Node3D: return EconModels.feeder(kind),
		"on": _feeder_in_hand(kind)}

## A farm-start island's own things (the house and the essentials), with their built / all placed states.
func add_fixture_entry(out: Array, id: String) -> void:
	var c: Dictionary = HomeLayout.CATALOG[id]
	var mx := HomeLayout.max_of(id, hb.h._d())
	var full: bool = mx > 0 and int(hb.L()["inv"].get(id, 0)) == 0 and HomeLayout.count_of(id, hb.h._d()) >= mx
	if not full and not FarmUnlocks.open(id):
		return
	var e := catalog_entry(id, func(): hb.take(id))
	if full:
		e["note"] = "built" if mx == 1 else "all placed"
		e["off"] = true
		e["cost"] = {}
		e["tip"] = hb._max_text(id, mx) + ". " + String(c.get("desc", ""))
	out.append(e)

func add_lot_entry(out: Array, b: String) -> void:
	var nm: String = Data.BUILDINGS[b]["name"]
	var unplaced := not HomeLayout.placed(b, hb.h._d())
	if unplaced and (not FarmUnlocks.open(b) or FarmBuilder.not_yet_arrived(b, hb.h._has_b(b))):
		return
	var picture := func() -> Node3D:
		if hb.h._has_b(b):
			return Models.building(b)
		var lot_size := HomeLayout.base_size(b)
		return Models.lot(lot_size.x, lot_size.y, nm, "")
	var on: bool = hb.held.get("kind", "") == "b" and String(hb.held.get("id", "")) == b
	if unplaced:
		var lot_cost := FarmBuilder.lot_cost(b)
		var cost: Dictionary = lot_cost if not lot_cost.is_empty() else {"gems": int(Data.BUILDINGS[b]["cost"])}
		if hb.h._has_b(b) or (bool(Data.BUILDINGS[b].get("free", false)) and lot_cost.is_empty()):
			cost = {}
		out.append({"id": "lot_" + b, "name": nm, "cost": cost, "note": "Place it" if hb.h._has_b(b) else "Mark a lot",
			"cb": func(): hb.take_building(b), "on": on, "model": picture, "tip": String(Data.BUILDINGS[b]["desc"])})
		return
	var isl: int = hb.h.world.island_of(hb.h.lots[b]["at"].x, hb.h.lots[b]["at"].z)
	var at: Vector3 = hb.h.lots[b]["at"]
	var open: bool = isl >= 0 and hb._isle_ok(hb.h.world.idx(int(floor(at.x)), int(floor(at.z))))
	if FarmUnlocks.gated() and not open:
		return      # a lot that cannot be reached yet is not shown at all
	var blocked_msg := "Build the bridge to its isle first"
	var go: Callable = func(): hb.take_building(b)
	if not open:
		go = func(): hb.h._toast(blocked_msg)
	out.append({"id": "lot_" + b, "name": nm, "note": "Move" if hb.h._has_b(b) else "Move the lot", "on": on,
		"off": not open, "cb": go, "model": picture, "tip": "" if open else blocked_msg})

func _feeder_in_hand(kind: String) -> bool:
	var held: Dictionary = hb.held
	var same: bool = String(held.get("id", "")) == kind and String(held.get("from", "x")) == ""
	return held.get("kind", "") == "feeder" and same

func add_storage(out: Array) -> void:
	var inv: Dictionary = hb.L()["inv"]
	for id in HomeLayout.CATALOG:
		if int(inv.get(id, 0)) > 0:
			var iid: String = id
			out.append(catalog_entry(id, func(): hb.take(iid)))
	if hb.h.visit.is_empty():
		for kind in Econ.FEEDER_ORDER:
			var nf := int(Save.d.get("feeder_inv", {}).get(kind, 0))
			if nf > 0: out.append(feeder_entry(kind, nf))

func add_island_entries(out: Array) -> void:
	var lay := hb.L()
	for t in HomeLayout.THEMES:
		var theme: String = t
		var td: Dictionary = HomeLayout.THEMES[t]
		var own: bool = (lay["themes"] as Array).has(t)
		var now: bool = String(lay["theme"]) == t
		var note := "Owned" if own else ""
		if now:
			note = "In use"
		var leaf := Color(String(td["leaf"])) if td.has("leaf") else Color("5f8d45")
		out.append({"name": "%s theme" % td["name"], "note": note,
			"cost": {} if own else {"gems": int(td["gems"])}, "swatch": leaf,
			"cb": func(): hb.set_theme(theme), "on": now, "off": not own and int(Save.d["gems"]) < int(td["gems"])})
	var lv := int(lay["grow"])
	if lv < HomeLayout.EXPAND.size():
		var c: Array = HomeLayout.EXPAND[lv]
		var cm: Array = HomeLayout.EXPAND_MATS[mini(lv, HomeLayout.EXPAND_MATS.size() - 1)]
		var extra := ""
		if int(cm[0]) > 0:
			extra = ": also %d wood and %d stone" % [int(cm[0]), int(cm[1])]
		var step := "Grow the island's edge (step %d of %d)%s" % [lv + 1, HomeLayout.EXPAND.size(), extra]
		out.append({"name": "Expand island", "glyph": "plus",
			"cost": {"gems": int(c[0]), "wood": int(cm[0]), "stone": int(cm[1])},
			"note": "+ %d scrap" % int(c[1]), "cb": func(): hb.open_expand(), "tip": step})
	else:
		out.append({"name": "Expand island", "note": "full size", "glyph": "plus", "cb": func(): pass, "off": true})
	if hb._seed() != 0:
		out.append(catalog_entry("clear_wild", func(): hb.take("clear_wild")))
	out.append({"name": "Reset layout", "note": "undoable", "glyph": "back", "cb": func(): hb.reset_layout(),
		"tip": "Buildings back on their lots, decorations into storage, paths and ponds cleared"})
