extends RefCounted
## --hero-check: changing Hunter on the farm (J or the Hunters button opens the Hunters screen,
## HomeClasses). Every Hunter has a tile; picking one swaps the farm hunter's model in place and saves
## it as the expedition pick (weight, id, weapon family), so the expedition panel and the Training
## Grounds start on it. An old save has every Hunter open (the locks: --hunter-unlock-check).
## With --shots-dir=<dir>: the screen and the result.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HERO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	var tree := main.get_tree()
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip"); d["roster"].append(k); d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["cls"] = "medium"; d["arch"] = "gunslinger"
	d["classes"] = ClassUnlock.legacy()      # an old save, every Hunter open (the locks: --hunter-unlock-check)
	Save.d = d
	var hm = await main._hb_home()
	for i in 30: await tree.process_frame
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shot = a.substr(12)
	var items: Array = hm.hub_items().map(func(it): return String(it[0]))
	ok(items.has("hero"), "the farm's bottom bar has a Hunters button (%s)" % str(items))
	ok(InputMap.has_action("hero") and Settings.key_cap("hero") == "J", "and a key (%s), rebindable in Settings" % Settings.key_cap("hero"))
	var ev := InputEventAction.new(); ev.action = "hero"; ev.pressed = true
	hm._unhandled_input(ev)
	await tree.process_frame
	ok(hm.panel_open == "Relics", "J opens the Relics screen on the farm")
	var grid: GridContainer = hm.get_meta("hero_grid")
	var cards: Array = grid.get_children()
	var archs: Array = cards.map(func(c): return String(c.get_meta("arch", "")))
	var named := ["thief", "bulwark", "dolm", "tender"].all(func(a): return archs.has(a))
	ok(cards.size() == Arch.ids().size() and named, "every Hunter has a tile: %s" % str(archs))
	var tips_ok := cards.all(func(c): return c.tooltip_text.contains("Dash:") and not c.tooltip_text.contains("weight"))
	ok(tips_ok, "each shows its kit on hover, with no weight label")
	ok(Arch.ids().all(func(a): return HeroGrid.unlocked(a)), "an old save has every Hunter open")
	for i in 20: await tree.process_frame
	if shot != "": tree.root.get_texture().get_image().save_png(shot + "/hero_panel.png")
	if shot != "":      # the rest of the grid, scrolled into view
		var sc: Node = grid
		while sc != null and not (sc is ScrollContainer): sc = sc.get_parent()
		if sc != null:
			(sc as ScrollContainer).scroll_vertical = 100000
			for i in 20: await tree.process_frame
			tree.root.get_texture().get_image().save_png(shot + "/hero_panel_2.png")
			(sc as ScrollContainer).scroll_vertical = 0
	var old_model: Node3D = hm.player
	HomeHero.pick(hm, "archer")
	await tree.process_frame
	ok(String(Save.d["cls"]) == "light" and Arch.of_save() == "archer" and String(Save.d["weapon"]) == Arch.signature("archer"), "picking Ravyl saves it as your expedition pick (cls %s, arch %s, weapon %s)" % [Save.d["cls"], Arch.of_save(), Save.d["weapon"]])
	ok(hm.player != old_model and is_instance_valid(hm.player) and hm.panel_open == "", "and the farm hunter turns into it in place")
	hm._open_expedition()
	await tree.process_frame
	ok(hm.panel_open == "Expedition" and Arch.of_save() == "archer", "the expedition panel opens on it")
	hm._close_panel()
	for i in 12: await tree.process_frame
	if shot != "": tree.root.get_texture().get_image().save_png(shot + "/hero_swapped.png")
	hm.queue_free()
	print("HERO DONE, failures: %d" % bad)
	tree.quit()
