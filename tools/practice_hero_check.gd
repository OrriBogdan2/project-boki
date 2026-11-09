extends RefCounted
## --practice-hero-check: changing hero in the practice areas (Practice, PracticeHero, HeroGrid). In the
## Training Area, the Duel room and the tutorial: the bottom bar exists (Hero, the area's
## menu, Leave), its Hero button and J open the picker with every hero, picking swaps the hunter's archetype
## in place, keeps the Boki, opens every rank and saves the expedition pick, the Esc menu has Change hero,
## and the mouse wheel zooms the camera (the Duel room included). A real match gets none of it.

var bad := 0
const DT := 1.0 / 60.0
const OPTS := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}

func ok(cond: bool, what: String) -> void:
	print("PRACTICEHERO %s %s" % ["ok  " if cond else "FAIL", what])
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
	var areas := {
		"arena": Match.arena_opts("gunslinger"),
		"duel": Match.duel_opts(),
		"tutorial": {"tutorial": true},
	}
	for area in areas:
		var o: Dictionary = OPTS.duplicate()
		o.merge(areas[area], true)
		var m := Match.new()
		main.add_child(m)
		await m.start(o)
		m.set_process(false)
		for i in 5: await tree.process_frame
		await _area(main, m, String(area))
		m.queue_free()
		await tree.process_frame
	# a real match gets none of it
	var rm := Match.new()
	main.add_child(rm)
	await rm.start({"teams": 2, "squad": 1, "tier": 0, "seed": 77, "no_drop": true})
	rm.set_process(false)
	ok(Practice.of(rm) == null and rm.cam.user_zoom == 1.0, "a real match has no practice bar, picker or wheel zoom")
	rm.queue_free()
	print("PRACTICEHERO DONE, failures: %d" % bad)
	tree.quit()

func _area(main: Node, m: Match, area: String) -> void:
	var tree := main.get_tree()
	var P: Hunter = m.player
	var pr := Practice.of(m)
	ok(pr != null and pr.bar != null and pr.bar.is_inside_tree(), "%s: the bottom bar exists" % area)
	if pr == null:
		return
	var want: Array = ["hero", "leave"] + (["menu"] if area in ["training", "arena", "duel"] else [])
	ok(want.all(func(i): return pr.bar_btns.has(i)), "%s: it has %s (%s)" % [area, str(want), str(pr.bar_btns.keys())])
	ok(m.hud != null and m.hud.ui_extra.has(pr.bar), "%s: the bar owns the mouse (no shooting through it)" % area)
	# the Hero button opens the picker; J toggles it
	(pr.bar_btns["hero"] as Button).pressed.emit()
	await tree.process_frame
	ok(pr.picker != null and m.paused, "%s: the Hero button opens the picker (the game pauses)" % area)
	var grid: GridContainer = pr.picker.get_meta("grid")
	var archs: Array = grid.get_children().map(func(c): return String(c.get_meta("arch", "")))
	ok(archs.size() == Arch.ORDER.size() and Arch.ORDER.all(func(a): return archs.has(a)), "%s: the picker shows all %d heroes" % [area, Arch.ORDER.size()])
	await _key(tree, "hero")
	ok(pr.picker == null and not m.paused, "%s: J closes it" % area)
	await _key(tree, "hero")
	ok(pr.picker != null, "%s: J opens it" % area)
	grid = pr.picker.get_meta("grid")
	# the same card code as the farm: clicking a card picks
	var kin_before: Ent = P.kin
	var target := "ostra" if P.arch != "ostra" else "mage"
	var card: Control = null
	for c in grid.get_children():
		if String(c.get_meta("arch", "")) == target: card = c
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	card.gui_input.emit(click)
	await tree.process_frame
	ok(pr.picker == null and not m.paused, "%s: picking closes the picker" % area)
	ok(m.player == P and P.arch == target and P.cls == Arch.weight(target), "%s: the hunter swapped in place to %s (%s)" % [area, target, P.arch])
	ok(P.kin == kin_before and (kin_before == null or is_instance_valid(kin_before)), "%s: your Boki stays" % area)
	ok(Hunter.SLOTS.all(func(s): return int(P.slot_lv[s]) >= 1), "%s: every rank is open" % area)
	ok(Arch.of_save() == target and String(Save.d["weapon"]) == Arch.signature(target), "%s: saved as your expedition pick" % area)
	for i in 3: m.step(DT)
	ok(not P.out and P.hp > 0.0, "%s: the new hero plays on" % area)
	# the Esc menu
	var was: Node = main.get("current")
	main.set("current", m)         # (the Esc menu finds the match through the current screen)
	Overlay.open_pause("match")
	await tree.process_frame
	var labels: Array = Overlay.host.find_children("*", "Button", true, false).map(func(b): return String((b as Button).text))
	ok(labels.any(func(t): return t.contains("Change Hunter")), "%s: the Esc menu has Change Hunter" % area)
	Overlay.close()
	main.set("current", was)
	await tree.process_frame
	# zoom
	var z0 := m.cam.user_zoom
	await _wheel(tree, MOUSE_BUTTON_WHEEL_UP)
	var zin := m.cam.user_zoom
	m.set_process(true)        # (the camera follows in the render frame)
	for i in 90: await tree.process_frame
	m.set_process(false)
	ok(zin < z0 and m.cam.zoom < 1.0, "%s: the wheel zooms in (user zoom %.2f -> %.2f, camera %.2f)" % [area, z0, zin, m.cam.zoom])
	await _wheel(tree, MOUSE_BUTTON_WHEEL_DOWN)
	await _wheel(tree, MOUSE_BUTTON_WHEEL_DOWN)
	await _wheel(tree, MOUSE_BUTTON_WHEEL_DOWN)
	ok(m.cam.user_zoom > zin, "%s: and out again (%.2f)" % [area, m.cam.user_zoom])
	for i in 200: await _wheel(tree, MOUSE_BUTTON_WHEEL_DOWN)
	ok(is_equal_approx(m.cam.user_zoom, Practice.ZOOM_MAX), "%s: zoom stops at its limit (%.2f)" % [area, m.cam.user_zoom])

func _key(tree: SceneTree, action: String) -> void:
	var ev := InputEventAction.new(); ev.action = action; ev.pressed = true
	Input.parse_input_event(ev)
	await tree.process_frame
	await tree.process_frame

func _wheel(tree: SceneTree, button: int) -> void:
	var ev := InputEventMouseButton.new(); ev.button_index = button; ev.pressed = true
	Input.parse_input_event(ev)
	await tree.process_frame
