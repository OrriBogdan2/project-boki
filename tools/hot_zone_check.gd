extends RefCounted
## --hot-zone-check: each match has exactly one hot drop zone (HotZone, content/rules/hot_zone.json).
## The pick is seeded, skips perches and never repeats the previous match's zone; the zone's loot
## is exactly the tier-up better and every other area is untouched; a region id in the match opts
## (the lobby's "start" message online) makes every game build the same zone. Never touches the save.
## --hot-zone-shots --shots-dir=<dir>: the drop map, the minimap in the ship and on the ground.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HOTZONE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _match(main: Node, opts: Dictionary) -> Match:
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "no_drop": true}
	o.merge(opts, true)
	m.start(o)
	m.set_process(false)
	return m

func _shot(main: Node, dir: String, file: String) -> void:
	for i in 4:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	print("HOTZONE shot ", file)

func shots(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 31})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	await main.get_tree().create_timer(1.0).timeout
	print("HOTZONE zone ", m.hot.id, " planning ", m.skydrop.planning)
	m.hud.full_map.open(true)
	await _shot(main, dir, "drop_map")
	m.hud.full_map.close()
	await _shot(main, dir, "minimap_ship")
	m.player.teleport(m.hot.center() + Vector3(0, 6, 0))
	await _shot(main, dir, "minimap_ground")
	main.get_tree().quit(0)

func run(main: Node, mode := "check") -> void:
	if mode == "shots":
		await shots(main)
		return
	Save.no_write = true
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var layout := World.load_layout(World.layout_for_tier(0))
	var isl: Array = layout["islands"]
	# (a) the pick: seeded, no perches, never the last one
	HotZone.last_id = ""
	var p7 := HotZone.pick(isl, 7)
	ok(p7 == HotZone.pick(isl, 7) and p7 != "", "(a) the same seed picks the same zone")
	var perch := {}
	for i in isl:
		if String(i.get("role", "")) == "perch":
			perch[String(i["id"])] = true
	var seen := {}
	var repeats := 0
	var on_perch := 0
	for sd in 120:
		var pid := HotZone.pick(isl, sd)
		if pid == HotZone.last_id: repeats += 1
		if perch.has(pid): on_perch += 1
		seen[pid] = true
		HotZone.last_id = pid
	ok(repeats == 0, "(a) never the same zone twice in a row over 120 matches")
	ok(on_perch == 0 and seen.size() >= 4, "(a) no perch; %d different zones came up" % seen.size())
	# (b) one zone per match, loot raised only there
	HotZone.last_id = ""
	var m := _match(main, {"seed": 31})
	ok(m.hot != null and m.hot.active(), "(b) the match has a hot zone (%s)" % (m.hot.id if m.hot else "-"))
	if m.hot == null:
		print("HOTZONE DONE, failures: ", bad)
		main.get_tree().quit()
		return
	var tier_up := int(HotZone.rules()["tier_up"])
	var hot_n := 0
	var wrong := 0
	for ii in m.world.islands.size():
		var cells: Array = m.world.islands[ii]["cells"]
		var cell: Vector2i = cells[cells.size() / 2]
		var p := Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)
		var with_zone := ChestLoot.rarity_bonus(m, p)
		var zone := m.hot
		m.hot = null
		var without := ChestLoot.rarity_bonus(m, p)
		m.hot = zone
		var raised := with_zone - without
		if ii == m.hot.isl:
			if raised == tier_up: hot_n += 1
		elif raised != 0:
			wrong += 1
	ok(hot_n == 1, "(b) exactly one area is raised, by %d step (%s)" % [tier_up, m.hot.zone_name()])
	ok(wrong == 0, "(b) no other area's loot changes")
	var first := m.hot.id
	m.queue_free()
	# (c) the next match picks another; an id from the opts is used as given
	var m2 := _match(main, {"seed": 31})
	var second := m2.hot.id if m2.hot else "-"
	ok(second != first and second != "-", "(c) the next match's zone differs (%s -> %s)" % [first, second])
	m2.queue_free()
	var want := first if first != "" else "crown"
	var m3 := _match(main, {"seed": 5, "hot": want})
	ok(m3.hot != null and m3.hot.id == want, "(c) a region id in the opts (the lobby start) is the zone")
	m3.queue_free()
	var m4 := _match(main, {"seed": 5, "hot": "no_such_area"})
	ok(m4.hot == null, "(c) an unknown id leaves the match without a zone")
	print("HOTZONE DONE, failures: ", bad)
	main.get_tree().quit()
