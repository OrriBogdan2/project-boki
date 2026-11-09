extends RefCounted
## --base-hud-check: the farm HUD in base mode (GARDEN.md 8). Off: the counters, tutorial line and work
## feed are as they were. On: gems stay, the mats/crop counters and the work feed are hidden, and one
## BaseHud card shows the Boki's four needs and one next-action line.
## --base-hud-shots --shots-dir=<dir> [--size=WxH]: off.png and on.png of the same farm (under xvfb with a renderer).

var fails := 0

func ok(cond: bool, what: String) -> void:
	print("BASEHUD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1

func _chip_texts(home) -> Array:
	var chips: Array = home.top_chips.get_children().filter(func(c): return not c.is_queued_for_deletion())
	return chips.map(func(c): return (c.find_children("*", "Label", true, false)[0] as Label).text)

func _home(m: Node):
	Save.no_write = true
	Save.d = Save.fresh()
	var kin := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(kin)
	Save.d["active"] = kin["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	Save.d["items"]["tonic"] = 2
	Save.d["crops"]["sunroot"] = 3
	Save.d["gems"] = 40
	Save.d["mats"] = {"wood": 5, "stone": 4}
	var home = await m._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await m.get_tree().process_frame
	home._close_panel()
	return home

func _shots(m: Node, home) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			m.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	var rules: Dictionary = FarmUnlocks.rules()
	Save.active_kin()["needs"]["food"] = 10.0
	for on in [false, true]:
		rules["base_mode"] = on
		BaseHud.arrived(["Pip: ate Boki kibble", "Work: ember done"] if on else [])
		home._refresh_top()
		for i in 40:
			await m.get_tree().process_frame
		m.get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % ("on" if on else "off")))
		print("BASEHUDSHOT ", on)
	m.get_tree().quit()

func run(m: Node, mode := "check") -> void:
	var home = await _home(m)
	if mode == "shots":
		await _shots(m, home)
		return
	var rules: Dictionary = FarmUnlocks.rules()
	var card: BaseHud = home.root_ui.get_node("BaseHud")
	home._refresh_top()
	var off: Array = _chip_texts(home)
	var shows_mats: bool = off.any(func(t): return t.contains("wood")) and off.has("3")
	ok(not FarmUnlocks.base_mode() and shows_mats,
			"off: the mats and crop counters show: %s" % str(off))
	await m.get_tree().process_frame
	ok(not card.visible, "off: no base card")
	rules["base_mode"] = true
	BaseHud.arrived(["Pip: ate Boki kibble", "Work: ember done"])
	Save.active_kin()["needs"]["food"] = 10.0
	home._refresh_top()
	var on: Array = _chip_texts(home)
	ok(on.any(func(t): return t == "40") and not on.any(func(t): return t.contains("wood") or t.contains("stone")),
			"on: gems show, the mats counters are hidden: %s" % str(on))
	ok(on.size() <= 2, "on: the top bar is the partner and gems only (%d chips)" % on.size())
	card.t = 1.0
	card._process(0.0)
	await m.get_tree().process_frame
	var texts: Array = card.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	ok(card.visible and texts.any(func(t): return t.begins_with("While you were away: Pip") and t.contains("+1 more")),
			"on: the card says what changed")
	ok(["Pip", "Full", "Energy", "Happy", "Clean"].all(func(n): return texts.has(n)), "on: the Boki's four needs show")
	ok(texts.any(func(t): return t.contains("Pip is hungry")), "on: one next action: %s" % str(texts.back()))
	ok(not is_instance_valid(home.guide.hint_box), "on: no tutorial line")
	ok(card.find_children("*", "Label", true, false).size() <= 9, "on: the card stays short")
	rules["base_mode"] = false
	BaseHud.arrived([])
	home.queue_free()
	await m.get_tree().process_frame
	print("BASEHUD DONE, failures: %d" % fails)
	m.get_tree().quit(1 if fails > 0 else 0)
