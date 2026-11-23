extends RefCounted
## --loot-full-check: looting with a full inventory (LootFull, LootWindow). Smart loot takes only what
## fits and says so; a click on a thing that doesn't fit moves nothing and reports no success; swap puts
## your thing in the box and the held one in your backpack; counts stay right; a full capsule box doesn't
## hang smart loot; the box window builds and holds a clicked thing with a Swap on each of yours.
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
	var p: Hunter = m.player
	var q: Hunter = m.hunters.filter(func(x): return x != p)[0]
	p.gear = Gear.empty_slots()
	p.refresh_gear()
	# ---------------------------------------------------------------- 1. smart loot with no room
	p.pack_cap = 2
	p.pack = [Loot.valuable("kin_idol"), Loot.valuable("sky_pearl")]
	var bx := make_box(q, p.pos, [Loot.valuable("old_coin"), Loot.valuable("old_coin")])
	var got := Life.smart_loot(m, p, bx)
	ok(got == 0, "full pack, worse things in the box: smart loot took %d" % got)
	ok(p.pack.size() == 2 and (bx["pack"] as Array).size() == 2,
		"nothing moved (pack %d, box %d)" % [p.pack.size(), (bx["pack"] as Array).size()])
	ok(LootFull.blocked(m, p, bx) == 2, "both things are counted as having no room")
	var none := LootFull.smart_text(0, 2)
	ok(none == "Inventory full, took nothing", "the report says so: %s" % none)
	# ---------------------------------------------------------------- 2. partial: gems fit, the pack things don't
	bx["gems"] = 12
	var g0 := p.gems
	got = LootFull.smart(m, p, bx)
	ok(got == 1 and p.gems == g0 + 12, "gems still come (took %d)" % got)
	var report := LootFull.smart_text(got, LootFull.blocked(m, p, bx))
	ok(report == "Took 1 of 3, inventory full", "report: %s" % report)
	ok(LootFull.smart_text(3, 0) == "Took 3", "everything fit: a plain count")
	# ---------------------------------------------------------------- 3. a click that doesn't fit
	var row: Dictionary = Life.box_items(m, p, bx).filter(func(r): return r["key"] == "pack")[0]
	ok(not LootFull.fits(p, row, bx), "the row is marked as not fitting")
	var moved := LootFull.click(m, p, bx, row)
	ok(not moved and p.pack.size() == 2 and (bx["pack"] as Array).size() == 2, "click: no success, nothing moved")
	ok(LootFull.holdable(row), "a backpack thing can be held for a swap")
	# ---------------------------------------------------------------- 4. swap
	var mine_before: Dictionary = p.pack[0]
	var held_before: Dictionary = bx["pack"][0]
	var total := p.pack.size() + (bx["pack"] as Array).size()
	ok(LootFull.swap_held(m, p, bx, 0, 0), "swap works")
	ok(p.pack[0] == held_before and bx["pack"][0] == mine_before, "swap: yours is in the box, the held one is yours")
	ok(p.pack.size() + (bx["pack"] as Array).size() == total and p.pack.size() == 2, "swap: counts stay right")
	ok(not LootFull.swap_held(m, p, bx, 9, 0), "a stale index swaps nothing")
	# ---------------------------------------------------------------- 6. room: smart loot takes it
	bx["pack"] = [Loot.valuable("crown_shard")]
	p.pack = [Loot.valuable("kin_idol")]
	got = Life.smart_loot(m, p, bx)
	ok(got == 1 and p.pack.size() == 2, "with room, smart loot takes it")
	# ---------------------------------------------------------------- 7. a full capsule box
	var bc := make_box(q, p.pos, [])
	bc["caught"] = [Save.new_kin("cindle", "Pip")]
	var filler: Array = []
	for i in Capture.box_cap():
		filler.append({"uid": "x%d" % i})
	p.caught = filler
	got = Life.smart_loot(m, p, bc)
	ok(got == 0 and (bc["caught"] as Array).size() == 1, "capsule box full: smart loot ends and leaves the Boki")
	ok(LootFull.blocked(m, p, bc) == 1, "and counts it as no room")
	p.caught = []
	# ---------------------------------------------------------------- 8. the windows
	p.pack = [Loot.valuable("kin_idol"), Loot.valuable("sky_pearl")]
	var bw := make_box(q, p.pos, [Loot.valuable("old_coin")])
	m.boxes.append(bw)
	m.hud.open_loot(bw)
	ok(m.hud.loot_panel != null and is_instance_valid(m.hud.loot_panel), "the box window opens")
	m.hud.loot_panel.take(Life.box_items(m, p, bw)[0])
	await main.get_tree().process_frame
	var buttons: Array = m.hud.loot_panel.find_children("*", "Button", true, false).filter(
		func(b): return (b as Button).text == "Swap")
	ok(buttons.size() == p.pack.size(),
		"clicking a thing that doesn't fit: a Swap on each of your %d things" % p.pack.size())
	(buttons[0] as Button).pressed.emit()
	ok(p.pack.any(func(it): return String(it.get("id", "")) == "old_coin"), "Swap puts the held thing in your backpack")
	m.hud.close_loot()
	_double_f(m, p, q)
	_merged_drops(m, p)
	_ground_compare(p)
	print("LOOT FULL CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## First F opens the box window, a second F press closes it even when smart loot takes nothing
## (a full pack, worse things inside), and the player's inputs are free right after.
func _double_f(m: Match, p: Hunter, q: Hunter) -> void:
	p.pack = [Loot.valuable("kin_idol"), Loot.valuable("sky_pearl")]
	p.backpack = 0
	m.boxes.clear()      # the nearest box wins the prompt: earlier sections' boxes sit on the same spot
	var bx := make_box(q, p.pos, [Loot.valuable("old_coin")])
	m.boxes.append(bx)
	p.inp["interact"] = true
	m._update_interact(0.016)
	ok(m.hud.loot_is(bx), "double F: the first press opens the box window")
	p.inp["interact"] = false
	m._update_interact(0.016)
	p.inp["interact"] = true
	m._update_interact(0.016)
	ok(not m.hud.loot_is(bx) and m.hud.loot_open == null, "double F: the second press closes it with nothing taken")
	ok(not bx["empty"] and (bx["pack"] as Array).size() == 1, "double F: the box still holds what you didn't take")
	ok(m.hud.loot_panel == null and not m.hud.mouse_on_panel(), "double F: no window is left to eat mouse input")
	p.inp["interact"] = false
	m._update_interact(0.016)
	m.boxes.erase(bx)

## Most loose pickups one monster kill, one chest or one prop may leave (one per kind: gem, seed, tonic, armor, key).
const MAX_PER_KILL := 5

## Ground drops are merged: each kind comes as one pickup holding the total. Counts what a whole map's
## monsters, chests and props leave on the ground (the numbers are printed for the perf notes).
func _merged_drops(m: Match, p_v: Hunter) -> void:
	p_v.gems = 0
	m.pickups.clear()
	var worst := 0
	var gems_by_kill := 0
	for mb in m.mobs.duplicate():
		var before: int = m.pickups.size()
		m.on_mob_dead(mb, p_v, {})
		var made: Array = m.pickups.slice(before)
		worst = maxi(worst, made.size())
		var kinds := {}
		for p in made:
			kinds[p["kind"]] = int(kinds.get(p["kind"], 0)) + 1
		gems_by_kill = maxi(gems_by_kill, int(kinds.get("gem", 0)))
	var from_mobs: int = m.pickups.size()
	ok(worst <= MAX_PER_KILL and gems_by_kill <= 1,
		"one kill makes at most %d pickups, one gem pile (worst %d, %d piles)" % [MAX_PER_KILL, worst, gems_by_kill])
	var chest_n := 0
	for c in m.chests:
		var before: int = m.pickups.size()
		ChestLoot.drop(m, p_v, c, true)
		chest_n += m.pickups.size() - before
		worst = maxi(worst, m.pickups.size() - before)
	var prop_n: int = m.pickups.size()
	for b in m.breaks.duplicate():
		var before: int = m.pickups.size()
		m.brk.smash(b, p_v)
		worst = maxi(worst, m.pickups.size() - before)
	prop_n = m.pickups.size() - prop_n
	ok(worst <= MAX_PER_KILL, "a chest or a prop leaves at most %d pickups (worst %d)" % [MAX_PER_KILL, worst])
	var total := 0
	for p in m.pickups:
		if p["kind"] == "gem":
			total += int(p["v"])
	print("LOOTFULL drops on this map: %d monsters -> %d pickups, %d chests -> %d, %d props -> %d" % [
		m.mobs.size(), from_mobs, m.chests.size(), chest_n, m.breaks.size(), prop_n])
	print("LOOTFULL gem value on the ground %d, gear/treasure on the ground %d" % [total, m.wpicks.size()])

## Gear on the ground for a worn slot: the card over the prompt names the piece and slot it replaces,
## then one line per changed number marked better or worse; nothing for an empty slot or a valuable.
func _ground_compare(p: Hunter) -> void:
	var slot := Gear.slot_on(p, "windstep_boots")
	p.gear[slot] = {}
	var at := {"kind": "weapon", "wp": {"gear": "windstep_boots", "rar": 3}}
	ok(GroundCompare.lines(p, at).is_empty(), "ground gear for an empty slot: no compare card")
	ok(GroundCompare.lines(p, {"kind": "weapon", "wp": {"item": Loot.valuable("old_coin"), "val": 1}}).is_empty(),
		"a ground valuable: no compare card")
	p.gear[slot] = {"id": "windstep_boots", "rar": 0}
	var ls := GroundCompare.lines(p, at)
	var head := String(ls[0][0]) if ls.size() > 0 else ""
	ok(ls.size() >= 2 and head.begins_with("Replaces ") and head.contains(InvText.slot_label(slot)),
		"ground gear for a worn slot: names what it replaces and where (%s)" % head)
	var better := ls.slice(1).filter(func(l): return String(l[0]).ends_with("(better)"))
	ok(better.size() == ls.size() - 1, "a higher rarity: every changed line says better (%d)" % better.size())
	p.gear[slot] = {"id": "windstep_boots", "rar": 3}
	at["wp"] = {"gear": "windstep_boots", "rar": 0}
	var worse := GroundCompare.lines(p, at).slice(1).filter(func(l): return String(l[0]).ends_with("(worse)"))
	ok(worse.size() >= 1, "a lower rarity: its lines say worse (%d)" % worse.size())
