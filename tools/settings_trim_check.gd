extends RefCounted
## --settings-trim-check: the trimmed settings menu. The first page (Main) shows only quality, window, size and
## volume, with Controls next and every other tab behind "More...". Every setting is still on some page, changing
## it there is saved to settings.cfg, and a fresh load keeps every saved value. With --shots-dir=<dir>, screenshots
## of Main, Controls and the opened More tabs.

const MAIN_KEYS := ["quality", "fullscreen", "ui_scale", "master"]
## Not rows on the settings tabs: version markers, the auto-detected preset, the per-hunter model switches
## (Video, one row per modelled hunter), the bot level (Admin tools) and the held-panel sizes.
const NOT_ROWS := ["keys", "keys_v", "keys2_v", "keys3_v", "keys4_v", "keys5_v", "keys6_v", "video_v",
		"quality_found", "warden_models", "bot_diff", "audio_v", "keys7_v", "hold_done"]

var bad := 0
var tree: SceneTree

func ok(cond: bool, what: String) -> void:
	print("TRIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _open(tab: String) -> void:
	Overlay.tab = tab
	Overlay.open_settings()
	await tree.process_frame
	await tree.process_frame

func _rows() -> Array:
	var rows := Overlay.root.find_children("*", "HBoxContainer", true, false)
	return rows.filter(func(r): return String(r.get_meta("setting", "")) != "")

func _row_keys() -> Array:
	return _rows().map(func(r): return String(r.get_meta("setting")))

func _row_of(key: String) -> Control:
	for r in _rows():
		if String(r.get_meta("setting")) == key:
			return r
	return null

func _tab_names() -> Array:
	var names: Array = []
	for b in Overlay.root.find_children("*", "Button", true, false):
		if Overlay.SETTINGS_TABS.has(b.text) or b.text == "More...":
			names.append(b.text)
	return names

func _saved(key: String):
	var cf := ConfigFile.new()
	cf.load(Settings.PATH)
	return cf.get_value("s", key)

## Changes a row the way a player would, and returns false if nothing about it moved.
func _drive(key: String) -> bool:
	var row := _row_of(key)
	var before = Settings.get_v(key)
	if row == null:
		return false
	var cb := row.find_children("*", "CheckButton", true, false)
	var sl := row.find_children("*", "HSlider", true, false)
	var ob := row.find_children("*", "OptionButton", true, false)
	if not cb.is_empty():
		cb[0].button_pressed = not cb[0].button_pressed
	elif not sl.is_empty():
		var s: HSlider = sl[0]
		s.value = s.min_value if absf(s.value - s.min_value) > 0.01 else s.max_value
		Settings.save()          # a slider writes when the drag ends
	elif not ob.is_empty():
		var o: OptionButton = ob[0]
		o.select(0 if o.selected != 0 else o.item_count - 1)
		o.item_selected.emit(o.selected)
	else:
		var swatches := row.find_children("*", "Button", true, false)
		swatches[-1].pressed.emit()
	await tree.process_frame
	await tree.process_frame
	return Settings.get_v(key) != before

## Types into the settings search box the way a player does, then lets the page rebuild.
func _type(q: String) -> void:
	var le := Overlay.root.find_children("*", "LineEdit", true, false)[0] as LineEdit
	le.text = q
	le.text_changed.emit(q)
	await tree.process_frame
	await tree.process_frame

## The tab tag beside a search hit ("" when the row has none).
func _tag_of(key: String) -> String:
	var row := _row_of(key)
	var tag := row.find_child(SettingsSearch.TAG, true, false) if row != null else null
	return "" if tag == null else (tag as Label).text

func _search(shot: String) -> void:
	Overlay.more_tabs = false
	await _open("Main")
	await _type("SHAKE")
	ok(_row_keys() == ["screen_shake"], "'SHAKE' finds one row on a tab behind More... (%s)" % str(_row_keys()))
	ok(_tag_of("screen_shake") == "Accessibility", "the hit names its tab (%s)" % _tag_of("screen_shake"))
	ok(Overlay.root.get_viewport().gui_get_focus_owner() is LineEdit, "typing keeps the keyboard in the box")
	ok(await _drive("screen_shake"), "a hit's control still changes its setting")
	await _type("ATTACK")
	var fire: Array = _row_keys()
	var atk := fire.has("bind:fire") and _tag_of("bind:fire") == "Controls"
	ok(atk, "'ATTACK' finds the Weapon attack bind on Controls (%s)" % str(fire))
	var labelled := _rows().all(func(r): return String(r.get_meta("label")).to_lower().contains("attack"))
	ok(labelled, "every hit has the text in its label")

	ok(_rows().all(func(r): return r.is_visible_in_tree()), "hits show even when their tab folds them")
	await _type("size")
	var sized := {"ui_scale": "Main", "hud_scale": "Accessibility", "text_size": "Accessibility"}
	var tagged := sized.keys().all(func(k): return _tag_of(k) == sized[k])
	ok(tagged, "'size' finds rows from two tabs, each tagged (%s)" % str(_row_keys()))
	if shot != "":
		tree.root.get_texture().get_image().save_png(shot + "/trim_search.png")
	await _type("ping")
	ok(_row_keys().has("bind:ping"), "a key bind folded behind More keys is found")
	await _type("zzzz")
	ok(_rows().is_empty() and Overlay.search == "zzzz", "no match: no rows")
	await _type(" ")
	ok(not SettingsSearch.active(Overlay.search) and not _rows().is_empty(), "only spaces is no search: the tab shows")
	await _type("m")
	var keys := _row_keys()
	var once := {}
	for k in keys:
		once[k] = true
	ok(keys.size() == once.size() and keys.size() > 3, "each row once, not copied (%d rows)" % keys.size())
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	Overlay._input(esc)
	await tree.process_frame
	await tree.process_frame
	var back_on_tab: bool = Overlay.search == "" and Overlay.page == "settings" and _row_keys() == MAIN_KEYS
	ok(back_on_tab, "Esc clears the search and shows the tab again (page %s)" % Overlay.page)
	Overlay._input(esc)
	ok(Overlay.page == "", "Esc with an empty box leaves Settings")

func run(main: Node) -> void:
	tree = main.get_tree()
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shot = a.substr(12)
	if main.fade:
		main.fade.reveal(0.05)
		await tree.create_timer(0.35).timeout
	Settings.reset_all()
	Overlay.ctx = "title"
	Overlay.more_tabs = false
	# the first page
	ok(Overlay.SETTINGS_TABS[0] == "Main" and Overlay.tab == "Main", "settings open on Main")
	await _open("Main")
	ok(_row_keys() == MAIN_KEYS, "Main shows only quality, fullscreen, size, volume (%s)" % str(_row_keys()))
	ok(_tab_names() == ["Main", "Controls", "More..."], "tab bar: Main, Controls, More... (%s)" % str(_tab_names()))
	if shot != "":
		tree.root.get_texture().get_image().save_png(shot + "/trim_main.png")
	# Controls: the common binds first, the rest behind More keys
	await _open("Controls")
	var fold: Button = null
	for b in Overlay.root.find_children("*", "Button", true, false):
		if b.text.begins_with("More keys"):
			fold = b
	ok(fold != null, "Controls has a More keys button")
	var shown := _rows().filter(func(r): return r.is_visible_in_tree())
	var seen: Array = shown.map(func(r): return String(r.get_meta("setting")))
	var basics: bool = seen.has("bind:dash") and seen.has("bind:fire")
	ok(basics and not seen.has("bind:ping"), "Moving and Fighting binds show, Squad and map wait")
	if shot != "":
		tree.root.get_texture().get_image().save_png(shot + "/trim_controls.png")
	if fold != null:
		fold.pressed.emit()
	await tree.process_frame
	var all_visible := _rows().all(func(r): return r.is_visible_in_tree())
	ok(all_visible and fold.text.begins_with("Fewer"), "More keys shows every bind")
	# More...
	Overlay.more_tabs = false
	await _open("Main")
	for b in Overlay.root.find_children("*", "Button", true, false):
		if b.text == "More...":
			b.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	ok(_tab_names() == Overlay.SETTINGS_TABS, "More... brings back every other tab (%s)" % str(_tab_names()))
	# every setting is on a page, and changing it there is saved
	var reached := {}
	var moved: Array = []
	var unsaved: Array = []
	for t in Overlay.SETTINGS_TABS:
		await _open(t)
		if shot != "" and t != "Main" and t != "Controls":
			tree.root.get_texture().get_image().save_png(shot + "/trim_%s.png" % t.to_lower())
		for key in _row_keys():
			reached[key] = true
			if key.begins_with("bind:"):
				continue
			await _open(t)
			var changed: bool = await _drive(key)
			if not changed:
				moved.append(key)
			elif _saved(key) != Settings.get_v(key):
				unsaved.append(key)
	var missing: Array = []
	for k in Settings.DEFAULTS:
		if not reached.has(k) and not NOT_ROWS.has(k):
			missing.append(k)
	for a in Settings.ACTIONS:
		if not reached.has("bind:" + String(a[0])):
			missing.append("bind:" + String(a[0]))
	ok(missing.is_empty(), "every setting and key bind has a row (missing: %s)" % str(missing))
	ok(moved.is_empty(), "every row changes its setting (stuck: %s)" % str(moved))
	ok(unsaved.is_empty(), "and the new value is in settings.cfg (not saved: %s)" % str(unsaved))
	# a fresh load keeps every saved value
	var later = load("res://scripts/core/settings.gd").new()
	tree.root.add_child(later)
	var lost: Array = []
	for k in Settings.DEFAULTS:
		if String(k).ends_with("_v"):
			continue          # migration step markers
		if later.get_v(k) != Settings.get_v(k):
			lost.append(k)
	tree.root.remove_child(later)
	later.free()
	ok(lost.is_empty(), "a fresh load keeps every saved value (changed: %s)" % str(lost))
	await _search(shot)
	Overlay.close()
	Settings.reset_all()
	print("TRIM DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)
