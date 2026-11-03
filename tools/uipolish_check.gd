extends RefCounted
## --uipolish-check: the settings audit and the one menu look (docs/SETTINGS_AUDIT.md, UiTheme).
##   1. every setting in Settings.DEFAULTS is read somewhere outside its own menu row
##   2. removed settings are gone: not in DEFAULTS, not read, and dropped from the settings file
##   3. every screen and menu uses the theme: the engine default theme is ours, and every panel and
##      button on the title, the farm, the Esc menu, each settings tab and a confirm box is drawn
##      with a box from it (or UiFrame)
##   4. no stray hard-coded panel styles: no StyleBoxFlat.new(), UI._box() or per-screen theme
##      outside the style module (the in-match HUD and reserved files excepted, see ALLOWED)
##   5. the field kit: text colours meet WCAG AA on every surface they sit on, hover never resizes
##      a button, every panel shell wears its section emblem, tabs carry icons, kit card keycaps
##      come from Settings.key_cap, "Fewer flashes" turns motion into plain fades, and the
##      interface size setting scales the menus and keeps a panel inside the window
##   6. more screens in the look: the armory, the market, the hero picker, the kit card, the
##      results screen and the loading screen

var main: Node
var fails := 0
var n := 0

## Files that may still build their own boxes: the HUD (ext/hudref owns its look) and reserved files.
const ALLOWED := ["scripts/ui/hud.gd", "scripts/ui/kin_reveal.gd"]
## Reserved files that still name a removed setting (handed to the main session, SETTINGS_AUDIT.md).
const REMOVED_READ_OK := ["scripts/combat/kin_tactics.gd"]
const STYLE_MODULE := ["scripts/ui/ui.gd", "scripts/ui/ui_theme.gd", "scripts/ui/ui_frame.gd", "scripts/ui/ui_skin.gd"]
const AA := 4.5          # WCAG AA for body text
const AA_LARGE := 3.0    # ... for large text (titles, stat numbers)

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
	_contrast()
	_steady_hover()
	await _screens()
	await _motion()
	await _scaling()
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
			return not p in REMOVED_READ_OK and p != "scripts/core/settings.gd")
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
	var layer := UI.confirm(Overlay.root, "Leave?", "A test question.", "Leave", func(): pass)
	await main.get_tree().process_frame
	var with_badge := layer.find_children("*", "PanelContainer", true, false).size() >= 2
	ok("confirm box: every box is the menu look, with its badge", _off_look(layer, ours).is_empty() and with_badge)
	layer.queue_free()
	UI.toast(Overlay.root, "Bramble Isle is open")
	await main.get_tree().process_frame
	var toast_box: Control = Overlay.root.get_child(Overlay.root.get_child_count() - 1)
	var glass_ok := toast_box is PanelContainer and toast_box.get_theme_stylebox("panel") is UiFrame
	ok("toast: a glass card from the menu look", glass_ok)
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
	await _home_panels(home, ours)
	await _results_and_loading(ours)

# ------------------------------------------------------------------ 5, 6: the field kit
## Text colours against the surfaces they sit on (panels, cards, button faces, smoked glass over a
## bright world), and dark ink on the amber primary and the bone keycap.
func _contrast() -> void:
	var glass_on_snow := Color(1, 1, 1).lerp(Color(0.1, 0.06, 0.04), 0.86)
	var surfaces := {"panel": UI.SURFACE, "card": UI.CARD, "button": UI.RAISED, "glass": glass_on_snow}
	var body := {"INK": UI.INK, "MUTED": UI.MUTED, "ACCENT_HI": UI.ACCENT_HI, "GOOD": UI.GOOD, "GOLD": UI.GOLD,
		"TEAL": UI.TEAL}
	for sec in [UiSkin.EXPEDITION, UiSkin.KIN, UiSkin.GEAR, UiSkin.MARKET, UiSkin.FARM, UiSkin.SYSTEM]:
		body["section " + sec.to_html(false)] = sec
	var low: Array = []
	for sname in surfaces:
		for cname in body:
			var r := UiSkin.contrast(body[cname], surfaces[sname])
			if r < AA:
				low.append("%s on %s %.2f" % [cname, sname, r])
	ok("text colours meet AA (4.5:1) on panels, cards, buttons, glass", low.is_empty(), str(low))
	var faint := UiSkin.contrast(UI.FAINT, UI.SURFACE)
	ok("hints (FAINT) meet AA on a panel", faint >= AA, "%.2f" % faint)
	var on_amber := UiSkin.contrast(UI.DARK_INK, UI.ACCENT)
	ok("dark ink on the amber primary meets AA", on_amber >= AA, "%.2f" % on_amber)
	var on_key := UiSkin.contrast(UI.DARK_INK, Color("f1e6d0"))
	ok("keycap text meets AA", on_key >= AA, "%.2f" % on_key)
	var bad_btn := UiSkin.contrast(Color("ffcabf"), UI.BAD.darkened(0.64))
	ok("danger button text meets AA", bad_btn >= AA, "%.2f" % bad_btn)
	var title_on_panel := UiSkin.contrast(UI.BRASS, UI.SURFACE)
	ok("brass eyebrows read on a panel (large/caps: 3:1)", title_on_panel >= AA_LARGE, "%.2f" % title_on_panel)

## Every button tier's states have the same content margins and minimum size: hover and press
## light or sink a button, they never resize it.
func _steady_hover() -> void:
	var t := UI.theme()
	var jumpy: Array = []
	for type in ["Button", "Primary", "Danger", "Chosen", "Ghost", "IconBtn", "Seg", "SegOn", "Tile", "MenuItem",
			"MenuMain"]:
		var base := t.get_stylebox("normal", type).get_minimum_size()
		for st in ["hover", "pressed", "hover_pressed"]:
			var sb := t.get_stylebox(st, type)
			if sb and sb.get_minimum_size() != base:
				jumpy.append("%s.%s" % [type, st])
	ok("hover and press never resize a button (every tier)", jumpy.is_empty(), str(jumpy))

## The shell wears its section emblem and colour; tabs get icons.
func _shell_ok(panel: Control) -> bool:
	return panel.has_meta("sec_col") and panel.has_meta("emblem") and is_instance_valid(panel.get_meta("emblem"))

## "Fewer flashes" off: a panel slides in. On: it only fades, a press doesn't scale, toggles snap.
func _motion() -> void:
	var was: bool = Settings.get_v("reduce_flashes")
	var holder := Control.new()
	Overlay.root.add_child(holder)
	for calm in [false, true]:
		Settings.set_v("reduce_flashes", calm, false)
		var c := Control.new()
		holder.add_child(c)
		UiMotion.open(c)
		await main.get_tree().process_frame
		var moved := not is_zero_approx(c.position.y)
		var b := UI.button("Press", Callable())
		holder.add_child(b)
		b.button_down.emit()
		for i in 3:
			await main.get_tree().process_frame
		var dipped := b.scale != Vector2.ONE
		if calm:
			ok("fewer flashes: panels fade in place, presses don't bounce", not moved and not dipped)
		else:
			ok("motion: panels slide up, presses dip and spring", moved and dipped)
	holder.queue_free()
	Settings.set_v("reduce_flashes", was, false)

## The interface size setting: the root scales with it, and the settings panel stays in the window.
func _scaling() -> void:
	var was := float(Settings.get_v("ui_scale"))
	var vp := main.get_viewport()
	var last := 0.0
	var grows := true
	var fits := true
	for sc in [0.75, 1.0, 1.25, 1.5]:
		Settings.set_v("ui_scale", sc, false)
		await main.get_tree().process_frame
		var f: float = main.get_tree().root.content_scale_factor
		grows = grows and f >= last - 0.001
		last = f
		Overlay.tab = "Gameplay"
		Overlay.open_settings()
		for i in 4:
			await main.get_tree().process_frame
		var shell := _first_shell(Overlay.root)
		var view := Rect2(Vector2.ZERO, vp.get_visible_rect().size)
		if shell == null or not view.grow(1.0).encloses(shell.get_global_rect()):
			fits = false
	Overlay.close()
	Settings.set_v("ui_scale", was, false)
	ok("interface size: the menus scale up with the setting", grows and last > 0.0)
	ok("interface size: settings stays inside the window at 75-150%", fits)

func _first_shell(root: Node) -> Control:
	for c in root.find_children("*", "PanelContainer", true, false):
		if c.has_meta("sec_col"):
			return c
	return null

## Panels on the farm: the armory, the market, the hero picker and the kit card.
func _home_panels(home: Node, ours: Dictionary) -> void:
	var opens := {"armory": func(): home.hecon.open_armory(), "market": func(): home.call("_open_shop"),
		"hero picker": func(): HomeHero.open(home), "kit card": func(): home.call("_open_kit_card")}
	for what in opens:
		(opens[what] as Callable).call()
		for i in 6:
			await main.get_tree().process_frame
		var off := _off_look(home, ours)
		var shell := _first_shell(home)
		ok("%s: every box is the menu look" % what, off.is_empty(), str(off))
		ok("%s: the shell wears its section emblem" % what, shell != null and _shell_ok(shell))
		if what == "armory":
			var tabs: Array = home.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("tab"))
			ok("armory: its tabs carry icons", not tabs.is_empty() and tabs.all(func(b): return b.has_meta("glyph")))
		if what == "kit card":
			_kit_keys(home)
		home.call("_close_panel")
		await main.get_tree().process_frame

## The kit card's keycaps say what Settings.key_cap says for the slot's action.
func _kit_keys(home: Node) -> void:
	var card: Array = home.find_children("*", "KitCard", true, false)
	if card.is_empty():
		ok("kit card: found", false)
		return
	var texts: Array = (card[0] as Node).find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	var want := [Settings.key_cap("dash"), Settings.key_cap("signature"), Settings.key_cap("secondary")]
	ok("kit card: keycaps come from Settings.key_cap", want.all(func(k): return texts.has(k)), str(want))

## The results screen and the loading screen.
func _results_and_loading(ours: Dictionary) -> void:
	Game.goto("results", {"extracted": true, "gems": 12, "time": 90.0, "knocks": 2})
	for i in 16:
		await main.get_tree().process_frame
	var res: Node = main.current
	var off_res := _off_look(res, ours) if res else ["no results screen"]
	ok("results: every box is the menu look", off_res.is_empty(), str(off_res))
	var shell := _first_panel(res)
	ok("results: the sheet is the leather panel with its guards", shell != null and (shell.get_theme_stylebox("panel")
		as UiFrame).guards.a > 0.0)
	var ld := LoadingScreen.new()
	ld.setup({"tier": 1, "teams": 6, "squad": 1, "seed": 3})
	main.add_child(ld)
	for i in 4:
		await main.get_tree().process_frame
	ok("loading: its tip card is the stitched leather frame", ld.tip_frame(1.0).stitch.a > 0.0)
	ld.queue_free()

func _first_panel(root: Node) -> PanelContainer:
	if root == null:
		return null
	for c in root.find_children("*", "PanelContainer", true, false):
		if (c as Control).get_theme_stylebox("panel") is UiFrame:
			return c
	return null

