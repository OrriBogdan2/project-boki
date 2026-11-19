extends RefCounted
## --window-mode-check: the export opens fullscreen unless the player chose windowed, F11 and Alt+Enter flip the
## window, and the title and Settings stay on screen (Settings, Quit, the Fullscreen switch, Done) in small windows.

const SIZES := [Vector2i(1280, 720), Vector2i(1280, 640), Vector2i(1024, 576), Vector2i(800, 600), Vector2i(640, 480)]

var bad := 0
var tree: SceneTree

func ok(cond: bool, what: String) -> void:
	print("WINMODE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _write_cfg(fullscreen: Variant, video_v: int) -> void:
	var cf := ConfigFile.new()
	cf.set_value("s", "video_v", video_v)
	if fullscreen != null:
		cf.set_value("s", "fullscreen", fullscreen)
	cf.save(Settings.PATH)

## What an export (desktop_export on) or the editor loads from a save with this state.
func _loads_fullscreen(exported: bool, fullscreen: Variant, video_v: int) -> bool:
	Settings.desktop_export = exported
	_write_cfg(fullscreen, video_v)
	Settings.load_file()
	return bool(Settings.v["fullscreen"])

func _press(keycode: Key, alt := false) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.alt_pressed = alt
	e.pressed = true
	Input.parse_input_event(e)
	await tree.process_frame

func _inside(c: Control, view: Rect2) -> bool:
	return c != null and view.grow(0.5).encloses(c.get_global_rect())

func _button(text: String) -> Button:
	for b in tree.root.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			return b
	return null

## A real left click at the middle of a control (what the player does; a covering layer would eat it).
func _click(c: Control) -> void:
	var at := c.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	Input.parse_input_event(mv)
	await tree.process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = down
		Input.parse_input_event(e)
		await tree.process_frame

func run(main: Node) -> void:
	tree = main.get_tree()
	# the engine itself makes a Windows window fullscreen (no switch after the window is up to lose a race);
	# the editor, Linux shots and the browser start windowed and Settings takes over from there
	ok(int(ProjectSettings.get_setting("display/window/size/mode")) == DisplayServer.WINDOW_MODE_WINDOWED,
		"project: base window mode is windowed")
	ok(int(ProjectSettings.get_setting("display/window/size/mode.windows", -1)) == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"project: Windows builds create the window fullscreen")
	var was_export := Settings.desktop_export
	ok(_loads_fullscreen(true, null, 5), "export, no save: opens fullscreen")
	ok(_loads_fullscreen(true, false, 4), "export, old save that says windowed (never chosen): opens fullscreen")
	ok(not _loads_fullscreen(true, false, 5), "export, player chose windowed: stays windowed")
	ok(_loads_fullscreen(true, true, 5), "export, player chose fullscreen: fullscreen")
	ok(not _loads_fullscreen(false, null, 5), "editor, no save: windowed")
	Settings.desktop_export = true
	Settings.reset_all()
	ok(Settings.get_v("fullscreen") == true, "export, Reset to defaults: fullscreen")
	Settings.desktop_export = was_export
	Settings.reset_all()
	# F11 and Alt+Enter flip the window as it is (headless windows stay windowed, so a press asks for fullscreen)
	await _press(KEY_ENTER)
	ok(not Settings.get_v("fullscreen"), "plain Enter does not toggle")
	await _press(KEY_F11)
	ok(Settings.get_v("fullscreen") == true, "F11 asks for fullscreen")
	Settings.set_v("fullscreen", false)
	await _press(KEY_ENTER, true)
	ok(Settings.get_v("fullscreen") == true, "Alt+Enter asks for fullscreen")
	Settings.set_v("fullscreen", false)
	if main.fade:
		main.fade.reveal(0.05)
		await tree.create_timer(0.35).timeout
	# a window that came up windowed while the choice is fullscreen: Settings shows it off, keeps the choice
	Settings.v["fullscreen"] = true
	Overlay.ctx = "title"
	Overlay.tab = "Main"
	Overlay.open_settings()
	for _i in 3: await tree.process_frame
	var sw: CheckButton = null
	for r in Overlay.root.find_children("*", "HBoxContainer", true, false):
		if String(r.get_meta("setting", "")) == "fullscreen":
			sw = r.find_children("*", "CheckButton", true, false)[0]
	ok(sw != null and not sw.button_pressed, "settings: the switch shows the window as it is (windowed)")
	ok(Settings.v["fullscreen"] == true, "settings: opening it does not overwrite the saved fullscreen choice")
	Overlay.close()
	Settings.v["fullscreen"] = false
	await tree.process_frame
	for sz: Vector2i in SIZES:
		tree.root.size = sz
		main.show_screen("title", {})
		for _i in 6: await tree.process_frame
		var view := Overlay.root.get_viewport().get_visible_rect()
		var tag := "at %dx%d" % [sz.x, sz.y]
		ok(_inside(_button("Settings"), view), "title: Settings button is on screen " + tag)
		ok(_inside(_button("Quit"), view), "title: Quit button is on screen " + tag)
		Overlay.tab = "Main"
		var gear := _button("Settings")
		if gear:
			await tree.create_timer(1.8).timeout      # (the menu pops in over ~1.5 s)
			await _click(gear)
		for _i in 3: await tree.process_frame
		ok(Overlay.page == "settings", "title: a mouse click on Settings opens it " + tag)
		if Overlay.page != "settings":
			Overlay.ctx = "title"
			Overlay.open_settings()
			for _i in 3: await tree.process_frame
		var row: Control = null
		for r in Overlay.root.find_children("*", "HBoxContainer", true, false):
			if String(r.get_meta("setting", "")) == "fullscreen":
				row = r
		ok(_inside(row, view), "settings: Fullscreen row is on screen " + tag)
		ok(_inside(_button("Done"), view), "settings: Done button is on screen " + tag)
		Overlay.close()
		await tree.process_frame
	print("WINMODE %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	tree.quit(1 if bad > 0 else 0)
