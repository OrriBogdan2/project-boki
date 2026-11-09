extends RefCounted
## --loot-full-check: looting with a full inventory (LootFull, LootHold). Smart loot takes only what
## fits and says so; a click on a thing that doesn't fit moves nothing and reports no success; swap puts
## your thing in the box and the held one in your backpack; drop puts yours on the ground; counts stay
## right; a full capsule box doesn't hang smart loot; the box window and the hold window build.
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LOOTFULL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A deathbox dictionary holding `pack` things, like the ones Life makes.
static func make_box(owner_h: Hunter, at: Vector3, pack: Array) -> Dictionary:
	return {"owner": owner_h, "team": owner_h.team, "pos": at, "gems": 0, "seeds": {}, "caught": [], "belt": [],
		"soul_until": 0.0, "prog": {}, "node": null, "empty": false, "gear": [], "pack": pack}

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var P: Hunter = m.player
	var Q: Hunter = m.hunters.filter(func(x): return x != P)[0]
	P.gear = Gear.empty_slots()
	P.refresh_gear()
	# ---------------------------------------------------------------- 1. smart loot with no room
	P.pack_cap = 2
	P.pack = [Loot.valuable("kin_idol"), Loot.valuable("sky_pearl")]
	var bx := make_box(Q, P.pos, [Loot.valuable("old_coin"), Loot.valuable("old_coin")])
	var got := Life.smart_loot(m, P, bx)
	ok(got == 0, "full pack, worse things in the box: smart loot took %d" % got)
	ok(P.pack.size() == 2 and (bx["pack"] as Array).size() == 2,
		"nothing moved (pack %d, box %d)" % [P.pack.size(), (bx["pack"] as Array).size()])
	ok(LootFull.blocked(m, P, bx) == 2, "both things are counted as having no room")
	var none := LootFull.smart_text(0, 2)
	ok(none == "Inventory full, took nothing", "the report says so: %s" % none)
	# ---------------------------------------------------------------- 2. partial: gems fit, the pack things don't
	bx["gems"] = 12
	var g0 := P.gems
	got = LootFull.smart(m, P, bx)
	ok(got == 1 and P.gems == g0 + 12, "gems still come (took %d)" % got)
	var report := LootFull.smart_text(got, LootFull.blocked(m, P, bx))
	ok(report == "Took 1 of 3, inventory full", "report: %s" % report)
	ok(LootFull.smart_text(3, 0) == "Took 3", "everything fit: a plain count")
	# ---------------------------------------------------------------- 3. a click that doesn't fit
	var row: Dictionary = Life.box_items(m, P, bx).filter(func(r): return r["key"] == "pack")[0]
	ok(not LootFull.fits(P, row, bx), "the row is marked as not fitting")
	var moved := LootFull.click(m, P, bx, row)
	ok(not moved and P.pack.size() == 2 and (bx["pack"] as Array).size() == 2, "click: no success, nothing moved")
	ok(LootFull.holdable(row), "a backpack thing can be held for a swap")
	# ---------------------------------------------------------------- 4. swap
	var mine_before: Dictionary = P.pack[0]
	var held_before: Dictionary = bx["pack"][0]
	var total := P.pack.size() + (bx["pack"] as Array).size()
	ok(LootFull.swap_held(m, P, bx, 0, 0), "swap works")
	ok(P.pack[0] == held_before and bx["pack"][0] == mine_before, "swap: yours is in the box, the held one is yours")
	ok(P.pack.size() + (bx["pack"] as Array).size() == total and P.pack.size() == 2, "swap: counts stay right")
	ok(not LootFull.swap_held(m, P, bx, 9, 0), "a stale index swaps nothing")
	# ---------------------------------------------------------------- 5. drop
	var drop_held: Dictionary = bx["pack"][1]
	var drop_mine: Dictionary = P.pack[1]
	var on_ground := m.wpicks.size()
	ok(LootFull.drop_for_held(m, P, bx, 1, 1), "drop works")
	ok(P.pack.size() == 2 and P.pack.has(drop_held) and not P.pack.has(drop_mine), "drop: the held one took the slot")
	ok(m.wpicks.size() == on_ground + 1 and (bx["pack"] as Array).size() == 1,
		"drop: yours is on the ground, the box lost the held one")
	# ---------------------------------------------------------------- 6. room: smart loot takes it
	bx["pack"] = [Loot.valuable("crown_shard")]
	P.pack = [Loot.valuable("kin_idol")]
	got = Life.smart_loot(m, P, bx)
	ok(got == 1 and P.pack.size() == 2, "with room, smart loot takes it")
	# ---------------------------------------------------------------- 7. a full capsule box
	var bc := make_box(Q, P.pos, [])
	bc["caught"] = [Save.new_kin("cindle", "Pip")]
	var filler: Array = []
	for i in Capture.box_cap():
		filler.append({"uid": "x%d" % i})
	P.caught = filler
	got = Life.smart_loot(m, P, bc)
	ok(got == 0 and (bc["caught"] as Array).size() == 1, "capsule box full: smart loot ends and leaves the Boki")
	ok(LootFull.blocked(m, P, bc) == 1, "and counts it as no room")
	P.caught = []
	# ---------------------------------------------------------------- 8. the windows
	P.pack = [Loot.valuable("kin_idol"), Loot.valuable("sky_pearl")]
	var bw := make_box(Q, P.pos, [Loot.valuable("old_coin")])
	m.boxes.append(bw)
	m.hud.open_loot(bw)
	ok(m.hud.loot_panel != null and is_instance_valid(m.hud.loot_panel), "the box window opens")
	m.hud.open_hold(Life.box_items(m, P, bw)[0])
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var lh: PanelContainer = m.hud.loot_hold
	ok(lh != null and is_instance_valid(lh) and lh.visible, "clicking a thing that doesn't fit opens the hold window")
	print("LOOTFULL hold pos=%s size=%s modulate=%s scale=%s" % [lh.position, lh.size, lh.modulate, lh.scale])
	var noop := func(_i: int): pass
	var hold := LootHold.build(P, bw["pack"][0], noop, noop, func(): pass)
	var buttons := hold.find_children("*", "Button", true, false).filter(
		func(b): return (b as Button).text in ["Swap", "Drop"])
	ok(buttons.size() == 2 * P.pack.size(), "hold window: Swap and Drop for each of your %d things" % P.pack.size())
	hold.free()
	m.hud.close_loot()
	print("LOOT FULL CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
