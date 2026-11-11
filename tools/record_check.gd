extends RefCounted
## --record-check: recording mode. F10 cycles off / clean / no HUD, Shift+F10 goes straight to
## no HUD; the debug and hint nodes hide in clean mode, the HUDs in no-HUD mode, the fps counter
## goes, tips stop, the camera softens and orbits only with the HUD hidden; turning it off puts
## everything back as it was.

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var bad := [0]
	var ok := func(cond: bool, what: String) -> void:
		print("RECCHECK %s %s" % ["ok  " if cond else "FAIL", what])
		if not cond: bad[0] += 1
	var press := func(shift: bool) -> void:
		var e := InputEventKey.new()
		e.physical_keycode = KEY_F10; e.keycode = KEY_F10; e.pressed = true; e.shift_pressed = shift
		Overlay._input(e)
	Settings.set_v("show_fps", true, false)
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	for i in 5: await main.get_tree().process_frame
	var dbg := Label.new(); dbg.text = "debug"; main.add_child(dbg); Record.hide_in_clean(dbg)
	var hint_hidden := Label.new(); hint_hidden.visible = false; main.add_child(hint_hidden); Record.hide_in_clean(hint_hidden)
	await main.get_tree().process_frame
	ok.call(Record.level == 0 and dbg.visible and m.hud.visible and Overlay.fps_lbl.visible, "off: debug label, HUD and fps shown")
	var cam_off: Array = Record.cam_rates()
	press.call(false)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok.call(Record.level == 1, "F10: clean (level %d)" % Record.level)
	ok.call(not dbg.visible and m.hud.visible and not Overlay.fps_lbl.visible, "clean: debug label and fps hidden, the HUD stays")
	ok.call(float(Record.cam_rates()[0]) < float(cam_off[0]) and float(Record.cam_rates()[4]) < 1.0, "clean: the camera follows softer, less shake")
	m.hud.tip("a tip"); m._tip_t = 99.0
	var tips_before: int = m.hud.msgs.count()
	m._tips()
	ok.call(m.hud.msgs.count() == tips_before, "clean: no new tips queued")
	press.call(false)
	await main.get_tree().process_frame
	ok.call(Record.level == 2 and not m.hud.visible, "F10 again: no HUD (level %d, hud visible %s)" % [Record.level, m.hud.visible])
	var y0 := Record.orbit_yaw
	var e9 := InputEventKey.new(); e9.physical_keycode = KEY_F9; e9.keycode = KEY_F9; e9.pressed = true
	Overlay._input(e9)
	for i in 10: await main.get_tree().process_frame
	ok.call(Record.orbit and absf(Record.orbit_yaw - y0) > 0.0001, "F9: the camera orbits (%.3f rad)" % Record.orbit_yaw)
	press.call(false)
	for i in 3: await main.get_tree().process_frame
	ok.call(Record.level == 0 and dbg.visible and not hint_hidden.visible and m.hud.visible and Overlay.fps_lbl.visible and not Record.orbit, "F10 a third time: off, all back as it was (a hidden one stays hidden)")
	press.call(true)
	await main.get_tree().process_frame
	ok.call(Record.level == 2 and not m.hud.visible and not dbg.visible, "Shift+F10: straight to no HUD")
	press.call(true)
	await main.get_tree().process_frame
	ok.call(Record.level == 1 and m.hud.visible, "Shift+F10 again: back to the clean HUD")
	Record.set_level(0)
	await main.get_tree().process_frame
	ok.call(InputMap.has_action("record") and Settings.ACTIONS.any(func(a): return a[0] == "record"), "F10 is a rebindable action (%s)" % Settings.key_cap("record"))
	# Settings > Demo: clear weather, no Blight, bots hold off fresh landers longer (offline matches)
	var o0 := Settings.demo_opts({})
	ok.call(not o0.has("raid") and not o0.has("blight") and not o0.has("fresh_t") and RaidLook.rolls({"big": true}), "demo settings at their defaults change nothing")
	Settings.set_v("demo_weather", "clear", false); Settings.set_v("demo_blight", false, false); Settings.set_v("demo_fresh", "long", false)
	var o1 := Settings.demo_opts({"teams": 10})
	ok.call(RaidLook.pick(o1, 12345) == "clear" and not BlightDir.enabled(o1) and float(o1.get("fresh_t", 0.0)) == Settings.DEMO_FRESH_T, "demo settings: clear weather, no Blight, %ds for fresh landers" % int(Settings.DEMO_FRESH_T))
	var seen := {}
	for sd in 40: seen[RaidLook.pick(Settings.demo_opts({}), sd + 1)] = true
	ok.call(seen.keys() == ["clear"], "always clear over 40 seeds (%s)" % ", ".join(seen.keys()))
	Settings.set_v("demo_weather", "random", false); Settings.set_v("demo_blight", true, false); Settings.set_v("demo_fresh", "normal", false)
	print("RECCHECK done, failures: %d" % bad[0])
	main.get_tree().quit(1 if bad[0] > 0 else 0)
