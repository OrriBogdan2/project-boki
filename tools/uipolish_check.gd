extends RefCounted
## --uipolish-check: the settings audit and the one menu look (docs/SETTINGS_AUDIT.md, UiTheme).
##   1. every setting in Settings.DEFAULTS is read somewhere outside its own menu row
##   2. removed settings are gone: not in DEFAULTS, not read, and dropped from the settings file
##   3. every screen and menu uses the theme: the engine default theme is ours, and every panel and
##      button on the title, the farm, the Esc menu, each settings tab and a confirm box is drawn
##      with a box from it (or UiFrame)
##   4. no stray hard-coded panel styles: no StyleBoxFlat.new(), UI._box() or per-screen theme
##      outside the style module (the in-match HUD and reserved files excepted, see ALLOWED)

var main: Node
var fails := 0
var n := 0

## Files that may still build their own boxes: the HUD (ext/hudref owns its look), its loot rows and
## full-pack window (LootHold, split out of hud.gd) and reserved files.
const ALLOWED := ["scripts/ui/hud.gd", "scripts/ui/loot_hold.gd", "scripts/ui/kin_reveal.gd"]
const STYLE_MODULE := [
	"scripts/ui/ui.gd", "scripts/ui/ui_theme.gd", "scripts/ui/ui_frame.gd", "scripts/ui/hud_style.gd",
]

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	printerr("UIPOLISH %-58s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	var src := _sources("res://scripts")
	_settings_read(src)
	_removed(src)
	await _migration()
	_static_styles(src)
	await _screens()
	print("UIPOLISH DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

# ------------------------------------------------------------------ 1, 2: the settings
## path -> source text of every script under dir.
func _sources(dir: String) -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out[dir.trim_prefix("res://") + "/" + f] = FileAccess.get_file_as_string(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.merge(_sources(dir + "/" + d))
	return out

## Lines that use `key`, minus its DEFAULTS entry and the settings menu's own rows.
func _uses(src: Dictionary, key: String) -> Array:
	var out: Array = []
	var quoted := "\"%s\"" % key
	for path in src:
		var in_defaults := false
		for line in String(src[path]).split("\n"):
			if path == "scripts/core/settings.gd" and line.begins_with("const DEFAULTS"):
				in_defaults = true
			if in_defaults:
				in_defaults = line != "}"
				continue
			if not line.contains(quoted) or line.strip_edges().begins_with("#"):
				continue
			if not (path == "scripts/ui/overlay.gd" and _is_menu_row(line)):
				out.append(path)
	return out

func _is_menu_row(line: String) -> bool:
	return line.contains("_toggle(") or line.contains("_choice(") or line.contains("_slider(")

func _settings_read(src: Dictionary) -> void:
	var unread: Array = []
	for k in Settings.DEFAULTS:
		if _uses(src, String(k)).is_empty():
			unread.append(k)
	ok("every setting is read somewhere", unread.is_empty(), str(unread))
	var tabs := ["Gameplay", "Controls", "Camera", "Audio", "Video", "Accessibility", "Demo"]
	ok("the settings menu shows the new tabs", Overlay.SETTINGS_TABS == tabs)

func _removed(src: Dictionary) -> void:
	for k in Settings.REMOVED:
		var reads: Array = _uses(src, String(k)).filter(func(p):
			return p != "scripts/core/settings.gd")
		var gone := not Settings.DEFAULTS.has(k) and not Settings.v.has(k)
		ok("removed '%s': not a setting, nothing reads it" % k, gone and reads.is_empty(), str(reads))
		ok("removed '%s': get_v gives nothing (off)" % k, Settings.get_v(String(k)) == null)

## A settings file from before the audit loses the removed keys on the next start, and keeps the rest.
func _migration() -> void:
	var keep := ConfigFile.new()
	var had := keep.load(Settings.PATH) == OK
	var cf := ConfigFile.new()
	cf.load(Settings.PATH)
	for k in Settings.REMOVED:
		cf.set_value("s", k, true)
	cf.set_value("s", "music", 0.42)
	cf.save(Settings.PATH)
	var fresh: Node = load("res://scripts/core/settings.gd").new()
	main.add_child(fresh)
	for i in 3:
		await main.get_tree().process_frame
	var after := ConfigFile.new()
	after.load(Settings.PATH)
	var left: Array = Settings.REMOVED.filter(func(k): return after.has_section_key("s", k))
	ok("an old settings file drops the removed keys on start", left.is_empty(), str(left))
	var kept := is_equal_approx(float(after.get_value("s", "music", 0.0)), 0.42)
	ok("...and keeps the others", kept and is_equal_approx(float(fresh.get_v("music")), 0.42))
	main.remove_child(fresh)
	fresh.free()
	if had:
		keep.save(Settings.PATH)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))

# ------------------------------------------------------------------ 3, 4: the look
func _static_styles(src: Dictionary) -> void:
	var stray: Array = []
	var own_theme: Array = []
	for path in src:
		if path in STYLE_MODULE or path in ALLOWED:
			continue
		var text := String(src[path])
		if text.contains("StyleBoxFlat.new()") or text.contains("UI._box(") or text.contains("UI._pad("):
			stray.append(path)
		if text.contains("theme = UI.theme()"):
			own_theme.append(path)
	ok("no hand-made panel styles outside the style module", stray.is_empty(), str(stray))
	ok("no screen sets its own theme (UI.install covers all)", own_theme.is_empty(), str(own_theme))

func _theme_boxes() -> Dictionary:
	var out := {}
	var t := UI.theme()
	for type in t.get_stylebox_type_list():
		for nm in t.get_stylebox_list(type):
			out[t.get_stylebox(nm, type)] = true
	return out

## Panels and buttons under `root` whose box doesn't come from the menu look: [path, ...].
func _off_look(root: Node, ours: Dictionary) -> Array:
	var out: Array = []
	for c in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		var sb: StyleBox = null
		if ctl is PanelContainer:
			sb = ctl.get_theme_stylebox("panel")
		elif ctl is Button and not ctl is CheckButton:
			sb = ctl.get_theme_stylebox("normal")
		if sb == null or sb is UiFrame or sb is StyleBoxEmpty or ours.has(sb):
			continue
		var owner_script: Script = ctl.get_script()
		out.append(String(root.get_path_to(ctl)) + (" (%s)" % owner_script.resource_path if owner_script else ""))
	return out

func _go(screen: String) -> Node:
	Game.goto(screen)
	for i in 10:
		await main.get_tree().process_frame
	return main.current

func _screens() -> void:
	var dt := ThemeDB.get_default_theme()
	var panel_box := dt.get_stylebox("panel", "PanelContainer")
	var is_ours := panel_box == UI.theme().get_stylebox("panel", "PanelContainer")
	ok("the menu theme is every Control's default", panel_box is UiFrame and is_ours)
	ok("tooltips use it too", dt.get_stylebox("panel", "TooltipPanel") is UiFrame)
	var ours := _theme_boxes()
	var title: Node = await _go("title")
	ok("title screen: every box is the menu look", _off_look(title, ours).is_empty(), str(_off_look(title, ours)))
	Overlay.ctx = "title"
	for t in Overlay.SETTINGS_TABS:
		Overlay.tab = t
		Overlay.open_settings()
		await main.get_tree().process_frame
		var off := _off_look(Overlay.root, ours)
		ok("settings > %s: every box is the menu look" % t, off.is_empty(), str(off))
	Overlay.close()
	Overlay.open_pause("home")
	await main.get_tree().process_frame
	var off_menu := _off_look(Overlay.root, ours)
	ok("Esc menu: every box is the menu look", off_menu.is_empty(), str(off_menu))
	var shown := _shown_buttons()
	var five := ["Continue", "Settings", "More...", "Save and quit to menu"]
	if not OS.has_feature("web"): five.append("Quit game")
	var lean := five.all(func(t): return shown.has(t)) and Overlay.pause_acts.size() == five.size()
	lean = lean and not shown.any(func(t): return t.contains("Admin") or t == "Inventory")
	ok("Esc menu: only Continue / Settings / More... / Save and quit / Quit, no Admin", lean, str(shown))
	Overlay.pause_acts[2].call()
	shown = _shown_buttons()
	var folded := shown.has("Inventory") and shown.has("Save files") and shown.has("Less")
	ok("Esc menu: key 3 opens More... (Inventory, Save files)", folded, str(shown))
	var layer := UI.confirm(Overlay.root, "Leave?", "A test question.", "Leave", func(): pass)
	await main.get_tree().process_frame
	var with_badge := layer.find_children("*", "PanelContainer", true, false).size() >= 2
	ok("confirm box: every box is the menu look, with its badge", _off_look(layer, ours).is_empty() and with_badge)
	layer.queue_free()
	UI.toast(Overlay.root, "Bramble Isle is open")
	await main.get_tree().process_frame
	var toast_box: Control = MsgLane.of(Overlay.root).get_child(0)
	var glass_ok := toast_box is PanelContainer and toast_box.get_theme_stylebox("panel") is UiFrame
	ok("toast: a glass card from the menu look", glass_ok)
	MsgLane.of(Overlay.root).clear()
	var host := Control.new()
	Overlay.root.add_child(host)
	for t in ["Harvest ready", "Harvest ready", "Egg hatched", "A", "B", "C", "D", "E", "F", "G"]:
		UI.toast(host, t)
	var lane := MsgLane.of(host)
	ok("toast: a few at a time, repeats merged, the queue capped", lane.texts().size() == MsgLane.MAX_SHOWN
		and lane.texts()[0] == "Harvest ready  x2" and lane.waiting() == MsgLane.WAIT_CAP)
	host.queue_free()
	var wide := Control.new()
	Overlay.root.add_child(wide)
	UI.toast(wide, "Pip, Moss and Fern heard you from the house and are on their way")
	await main.get_tree().process_frame
	var long_box := MsgLane.of(wide).get_child(0) as Control
	ok("toast: a long line wraps at a sane width", long_box.size.y < 130.0 and long_box.size.x > 200.0)
	wide.queue_free()
	Overlay.close()
	Save.no_write = true
	if Save.d["roster"].is_empty():
		var rec := Save.new_kin("cindle", "Pip")
		Save.d["roster"].append(rec)
		Save.d["active"] = rec["uid"]
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	var home: Node = await _go("home")
	for i in 30:
		await main.get_tree().process_frame
	ok("farm: every box is the menu look", _off_look(home, ours).is_empty(), str(_off_look(home, ours)))

## The labels of the Esc menu's buttons that are on screen.
func _shown_buttons() -> Array:
	var bs := Overlay.host.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree())
	return bs.map(func(b): return String(b.text))
