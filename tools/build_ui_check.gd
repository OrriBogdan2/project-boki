extends RefCounted
## --build-ui-check: the shared build and decorate UI on the farm (HomeBuild) and in the house (Decorate).
##   rotate (animated, never a snap), place, store, move, the blocked reason with the blocker lit, leaving build
##   mode after placing one thing, lines and brushes staying in their tool, Shift keeping the piece in hand,
##   a new house starting empty, and an old save's furniture (the journal and gramophone too) all movable.
## Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	printerr("BUILDUI %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--build-ui-shots="):
			await load("res://tools/build_ui_shots.gd").new().run(m, arg.substr(17))
			return
	Save.no_write = true
	await _farm()
	await _house()
	_migration()
	_card_clamp()
	printerr("BUILDUI DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ the farm
func _farm_save() -> void:
	Save.d = Save.fresh()
	var kin := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(kin)
	Save.d["active"] = kin["uid"]
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	Save.d["gems"] = 5000
	Save.d["scrap"] = 100
	Econ.ensure()

func _spot(hb: HomeBuild, item: Dictionary, span := Vector2i(1, 1), skip := 0) -> Array:
	var seen := 0
	for z in range(34, 46):
		for x in range(52, 62):
			var cs := HomeLayout.cells_of([x, z, x + span.x - 1, z + span.y - 1])
			if hb.fits(item, cs):
				if seen == skip:
					return cs
				seen += 1
	return []

func _put(hb: HomeBuild, cs: Array, keep := false) -> bool:
	hb.cells = cs
	hb._check_cells()
	return hb.click_place(keep)

func _decos(id: String) -> Array:
	return (HomeLayout.of(Save.d)["deco"] as Array).filter(func(e): return String(e["id"]) == id)

func _farm() -> void:
	_farm_save()
	var home = await main._hb_home()
	var hb: HomeBuild = home.hb
	hb.toggle()
	ok(hb.active and hb.bar is BuildCatalog and hb.keys is BuildKeys,
		"build mode opens the shared catalog bar and key hints")
	ok(home.cam.top_to > 0.0, "the camera eases to the build view")
	var tabs := hb._tabs()
	ok(tabs.has("Buildings") and tabs.has(BuildCatalog.STORAGE), "the bar has category tabs and a Storage tab (%s)" % ",
		".join(tabs))
	hb.cat = "Furniture"
	hb._build_bar()
	var bench: Dictionary = hb._tab_items().filter(func(e): return e["name"] == "Bench")[0]
	ok(bench.has("model") and bench.has("cost") and int(bench["cost"]["gems"]) > 0,
		"a tile has a picture, a name and a price in gems")
	# rotate: the ghost turns over a few frames
	hb.take("bench")
	var bench_spot := _spot(hb, hb.held, Vector2i(2, 1))
	hb.debug_m = Vector2(bench_spot[0].x + 1.0, bench_spot[0].y + 0.5)
	hb.tick(0.016)
	var yaw0 := hb.ghost.rotation.y
	hb.rotate_held()
	hb.tick(0.016)
	var yaw1 := hb.ghost.rotation.y
	ok(int(hb.held["r"]) == 1 and yaw1 > yaw0 and yaw1 < PI * 0.5 - 0.05,
		"Rotate turns the ghost a quarter turn over several frames, not in one pop (%.2f)" % yaw1)
	for i in 40: hb.tick(0.016)
	ok(absf(hb.ghost.rotation.y - PI * 0.5) < 0.02, "and it settles on the quarter turn")
	ok(hb.keys.tag.visible, "the key card shows while something is held")
	# place: one thing, then build mode ends
	var g0 := int(Save.d["gems"])
	var cs := _spot(hb, hb.held, HomeLayout.size_of("bench", 1))
	ok(_put(hb, cs), "the bench goes down")
	ok(_decos("bench").size() == 1 and int(Save.d["gems"]) < g0, "it is in the layout and was paid for")
	ok(not hb.active and home.cam.top_to == 0.0, "placing one thing leaves build mode and eases the camera back")
	ok(Placement.placed_text().contains(Settings.key_cap("build")),
		"the toast names the build key ('%s')" % Placement.placed_text())
	# Shift keeps the same item in hand
	hb.toggle()
	hb.take("lantern")
	var l1 := _spot(hb, hb.held)
	_put(hb, l1, true)
	ok(hb.active and hb.held.get("id", "") == "lantern", "holding Shift keeps the same piece in hand to place another")
	var l2 := _spot(hb, hb.held)
	ok(_put(hb, l2, false) and not hb.active and _decos("lantern").size() == 2,
		"and a click without Shift places it and leaves")
	# lines and brushes stay
	hb.toggle()
	hb.take("fence")
	var line := _spot(hb, hb.held)
	_put(hb, line)
	ok(hb.active and hb.held.get("id", "") == "fence", "a fence line stays in its tool after placing")
	hb.take("path_stone")
	hb.cells = _spot(hb, hb.held)
	hb._check_cells()
	hb.drag = {"from": hb.cells[0], "tiles": {hb.cells[0]: true}, "last": hb.cells[0]}
	hb.click_place()
	ok(hb.active and hb.held.get("id", "") == "path_stone", "a path brush stays in its tool after painting")
	hb._cancel_held()
	# blocked: red, named, the blocker lit
	var bench_e: Dictionary = _decos("bench")[0]
	var tag := "d:%d" % int(bench_e["u"])
	hb.take("lantern")
	var on_bench := HomeLayout.deco_cells(bench_e).slice(0, 1)
	hb.debug_m = Vector2(on_bench[0].x + 0.5, on_bench[0].y + 0.5)
	hb.tick(0.016)
	ok(not hb.ghost_ok and hb.why == "Blocked by: Bench" and hb.blocker == tag,
		"a blocked spot says why: '%s'" % hb.why)
	ok(hb.glowing == hb.nodes[int(bench_e["u"])], "and the Bench that is in the way is lit up")
	ok(hb.keys.tag.visible, "the cursor tag is up with the reason")
	hb._cancel_held()
	# the piece menu, move, rotate, store
	hb.open_menu(tag)
	var labels: Array = []
	for b in hb.menu.find_children("*", "Button", true, false):
		labels.append(String(b.text))
	ok(is_instance_valid(hb.menu) and labels.has("Move") and labels.has("Rotate") and labels.has("Store"),
			"clicking a placed piece opens its menu (%s)" % ", ".join(labels))
	var turn0 := int(_decos("bench")[0].get("r", 0))
	hb.rotate_placed(tag)
	ok(int(_decos("bench")[0].get("r", 0)) == (turn0 + 1) % 4 and hb.held.is_empty(),
		"Rotate on the menu turns it in place")
	hb.pick_up_tag(tag)
	ok(hb.held.get("id", "") == "bench" and int(hb.held["from"]) == int(bench_e["u"]), "Move picks the placed piece up")
	var elsewhere := _spot(hb, hb.held, HomeLayout.size_of("bench", int(hb.held["r"])), 3)
	var old_x := int(bench_e["x"])
	hb.cells = elsewhere
	hb._check_cells()
	hb.place_held()
	ok(int(_decos("bench")[0]["x"]) != old_x or int(_decos("bench")[0]["z"]) != int(bench_e["z"]),
		"and it can be put down somewhere else")
	var inv0 := int(HomeLayout.of(Save.d)["inv"].get("bench", 0))
	hb.store_placed(tag)
	ok(_decos("bench").is_empty() and int(HomeLayout.of(Save.d)["inv"].get("bench", 0)) == inv0 + 1,
		"Store puts it in storage in one step")
	hb.cat = BuildCatalog.STORAGE
	ok(hb._tab_items().any(func(e): return e["name"] == "Bench" and int(e["owned"]) == 1),
		"the Storage tab lists it with its count")
	ok(hb.undo_last() and _decos("bench").size() == 1, "Undo brings it back")
	hb.toggle()
	home.queue_free()
	await main.get_tree().process_frame

# ------------------------------------------------------------------ the house
func _house_save(old: bool) -> void:
	Save.d = Save.fresh()
	Save.d["gems"] = 900
	if old:
		var kin := Save.new_kin("zapple", "Pip")
		Save.d["roster"].append(kin)
		Save.d["active"] = kin["uid"]
		Save.d["v"] = 10
		Save.d.erase("furniture")
		Save.migrate(Save.d)

func _room() -> Node:
	var room = load("res://scripts/home/interior.gd").new()
	main.add_child(room)
	await main.get_tree().process_frame
	return room

func _free_cell(room, id: String, turn: int, skip := 0) -> Vector2i:
	var seen := 0
	for z in range(1, room.D - 2):
		for x in range(0, room.W):
			if room._fits(id, x, z, turn):
				if seen == skip:
					return Vector2i(x, z)
				seen += 1
	return Vector2i(-1, -1)

func _house() -> void:
	_house_save(false)
	var room = await _room()
	var dec: Decorate = room.dec
	ok(room.decor.is_empty(), "a new house starts empty")
	ok(int(Save.d["furniture"].get("journal", 0)) == 1 and int(Save.d["furniture"].get("gramophone", 0)) == 1,
			"with the journal and gramophone waiting in storage")
	dec.toggle()
	ok(dec.active and dec.bar is BuildCatalog and room.cam.top_to > 0.0,
		"decorate opens the same catalog bar and eases the camera")
	dec.cat = BuildCatalog.STORAGE
	ok(dec._entries(BuildCatalog.STORAGE).size() == 2, "the Storage tab lists the two stored pieces")
	# place a chair: leaves decorate mode
	dec.take("chair")
	var at := _free_cell(room, "chair", 0)
	dec.debug_m = Vector2(at.x + 0.5, at.y + 0.5)
	dec.tick(0.016)
	var g0 := int(Save.d["gems"])
	ok(dec.click_place() and room.decor.size() == 1 and not dec.active and int(Save.d["gems"]) < g0,
		"placing a chair buys it and leaves decorate mode")
	# shift keeps it
	dec.toggle()
	dec.take("stool")
	dec.debug_m = Vector2(5.5, 3.5)
	dec.tick(0.016)
	dec.click_place(true)
	ok(dec.active and dec.held.get("id", "") == "stool" and room.decor.size() == 2,
		"Shift keeps the stool in hand to place another")
	dec.cancel_held()
	# rotate animates
	dec.take("bed")
	dec.debug_m = Vector2(6.0, 3.5)
	dec.tick(0.016)
	var yaw0: float = dec.ghost.rotation.y
	dec.rotate_held()
	dec.tick(0.016)
	var yaw1: float = dec.ghost.rotation.y
	ok(int(dec.held["r"]) == 1 and absf(yaw1 - yaw0) > 0.0 and absf(yaw1 - yaw0) < PI * 0.5 - 0.05,
		"Rotate turns the ghost over a few frames (%.2f)" % yaw1)
	# blocked by the chair
	var chair: Dictionary = room.decor[0]
	var bed_size: Vector2i = room.footprint("bed", 1)
	dec.debug_m = Vector2(float(chair["x"]), float(chair["z"])) + Vector2(bed_size) * 0.5
	dec.tick(0.016)
	ok(not dec.ghost_ok and room.why == "Blocked by: Chair" and room.blocker == 0,
		"a blocked spot says why: '%s'" % room.why)
	ok(dec._glowing == room.nodes[0], "and the Chair in the way is lit up")
	dec.cancel_held()
	dec.take("stool")
	dec.debug_m = Vector2(room.W * 0.5, room.D - 0.5)
	dec.tick(0.016)
	ok(not dec.ghost_ok and room.why == "Keep the doorway clear", "the doorway says so ('%s')" % room.why)
	dec.cancel_held()
	# menu, move, rotate, store
	dec.open_menu(0)
	ok(is_instance_valid(dec.menu), "clicking a placed piece opens its menu")
	dec.rotate_placed(0)
	ok(int(room.decor[0].get("r", 0)) == 1, "Rotate turns the chair in place")
	dec.pick_up(0)
	var spot2 := _free_cell(room, "chair", 1, 5)
	dec.debug_m = Vector2(spot2.x + 0.5, spot2.y + 0.5)
	dec.tick(0.016)
	dec.place()
	ok(room.decor.size() == 2 and int(room.decor[0]["x"]) == spot2.x, "Move puts it down somewhere else")
	var stored := dec.stored("chair")
	dec.store_placed(0)
	ok(room.decor.size() == 1 and dec.stored("chair") == stored + 1, "Store puts it away in one step")
	ok(dec.undo_last() and room.decor.size() == 2, "Undo brings it back")
	dec.toggle()
	room.queue_free()
	await main.get_tree().process_frame
	# an old save keeps its furniture, and every piece can be moved or stored
	_house_save(true)
	room = await _room()
	dec = room.dec
	var ids: Array = room.decor.map(func(e): return String(e["id"]))
	var fixtures: bool = ids.has("bed") and ids.has("table") and ids.has("journal") and ids.has("gramophone")
	ok(fixtures, "an old save's house keeps its furniture and the two former fixtures (%s)" % ", ".join(ids))
	dec.toggle()
	var moved := 0
	for id in ["bed", "journal", "gramophone", "stove"]:
		var index: int = room.decor.map(func(e): return String(e["id"])).find(id)
		dec.pick_up(index)
		var open_cell := _free_cell(room, id, 0, 1)
		dec.debug_m = Vector2(open_cell) + Vector2(room.footprint(id, 0)) * 0.5
		dec.tick(0.016)
		if dec.place(): moved += 1
	ok(moved == 4, "the bed, journal, gramophone and stove can all be picked up and moved (%d of 4)" % moved)
	var count: int = room.decor.size()
	var jindex: int = room.decor.map(func(e): return String(e["id"])).find("journal")
	dec.store_placed(jindex)
	ok(room.decor.size() == count - 1 and dec.stored("journal") == 1, "and stored")
	ok(room.spots.size() == 2, "the gramophone still plays and the door stays (%d spots)" % room.spots.size())
	dec.toggle()
	room.queue_free()
	await main.get_tree().process_frame

# ------------------------------------------------------------------ the save
func _migration() -> void:
	var old := {"v": 10, "roster": [{"uid": "a"}]}
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION and old["decor"]["house"].size() == 10,
		"a v10 save that has played keeps its 8 pieces and gets the two former fixtures as pieces")
	var fresh_old := {"v": 10, "roster": []}
	Save.migrate(fresh_old)
	ok(int(fresh_old["furniture"]["journal"]) == 1 and not fresh_old["decor"].has("house"),
		"a v10 save with no Boki yet starts with an empty house")

## The cursor card and the piece menu never cover the catalog bar, the top band or the Goals card.
func _card_clamp() -> void:
	var vp := Vector2(1280, 720)
	var blocked := [Rect2(16, 620, 1248, 88), Rect2(0, 0, 1280, BuildKeys.TOP_BAND), Rect2(1000, 60, 270, 160)]
	var card := Vector2(190, 120)
	var clear := true
	for cursor in [Vector2(640, 360), Vector2(1270, 710), Vector2(10, 10), Vector2(640, 600), Vector2(1200, 260),
			Vector2(1270, 360), Vector2(640, 700)]:
		var at := BuildKeys.place_card(card, cursor, BuildKeys.TAG_OFFSET, blocked, vp)
		var rect := Rect2(at, card)
		var inside := Rect2(Vector2.ZERO, vp).encloses(rect)
		if not inside or blocked.any(func(r: Rect2) -> bool: return r.intersects(rect)):
			clear = false
			printerr("BUILDUI card at %s lands on %s" % [cursor, rect])
	ok(clear, "the cursor card keeps off the bar, the top band and the Goals card at every edge")
