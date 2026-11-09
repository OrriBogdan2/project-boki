extends CanvasLayer
## Menus that sit on top of any screen: the Esc menu, settings, save files and the admin panel.
## Screens open it (Esc at home, in town, in a match; buttons on the title screen) and listen for
## `closed` to carry on.

signal closed

const SETTINGS_TABS := ["Gameplay", "Controls", "Camera", "Audio", "Video", "Accessibility", "Demo"]

var root: Control
var dim: ColorRect              # the blurred backdrop (UI.backdrop)
var host: CenterContainer
var fps_lbl: PerfOverlay
var page := ""                  # "" when nothing is open
var ctx := ""                   # title | home | town | match
var stack: Array = []           # pages to go back to with Esc
var tab := "Gameplay"
var listening := ""             # an action waiting for its new key
var listening_slot := 0         # ...in which slot (0 primary, 1 secondary)
var listen_lbl: Label = null
var delete_armed := -1

func _ready() -> void:
	Game.screen_changed.connect(func(_n):
		if page != "": close())
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# behind every overlay menu: the screen blurred and darkened, fading in and out
	dim = UI.backdrop()
	root.add_child(dim)
	host = CenterContainer.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(host)
	fps_lbl = PerfOverlay.new()
	fps_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fps_lbl.position.y = 4
	fps_lbl.offset_right = -8
	root.add_child(fps_lbl)

func _process(_d: float) -> void:
	Record.tick(get_tree(), _d)
	fps_lbl.tick("" if Record.clean() else Settings.fps_mode(), _d)

func is_open() -> bool:
	return page != ""

## Admin tools are for the game's owner: always on desktop, and on the web for the artifact's owner. They are hidden
## (no F1 / ` panel, no Admin or Mod mode entries in the menus) only when launched with `-- --showcase`, or while
## recording mode (F10) is on, so filmed footage never shows them.
func admin_allowed() -> bool:
	if OS.get_cmdline_user_args().has("--showcase") or Record.clean():
		return false
	return not OS.has_feature("web") or Social.is_owner

# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if listening != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
				listening = ""
				_show_settings()
			else:
				_finish_rebind(event)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			_finish_rebind(event)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		var typing := get_viewport().gui_get_focus_owner() is LineEdit
		# recording mode (Record): F10 cycles off / clean HUD / no HUD, Shift+F10 straight to no HUD,
		# F9 the slow camera orbit with the HUD hidden. Anywhere, menus open or not.
		if not typing and event.is_action_pressed("record"):
			if (event as InputEventKey).shift_pressed: Record.toggle_cinema()
			else: Record.cycle()
			get_viewport().set_input_as_handled()
			return
		if not typing and event.is_action_pressed("record_orbit") and Record.cinema():
			Record.toggle_orbit()
			get_viewport().set_input_as_handled()
			return
		if not typing and event.is_action_pressed("inventory") and ctx_now() in ["home", "town", "interior"]:
			if page == "inventory": close()
			elif page == "": open_inventory()
			get_viewport().set_input_as_handled()
			return
		if (k == KEY_F1 or (k == KEY_QUOTELEFT and not typing)) and admin_allowed() and Game.main and ctx_now() != "title":
			if page == "admin": close()
			else: open_admin()
			get_viewport().set_input_as_handled()
			return
	if page != "" and (event.is_action_pressed("menu") or (event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"))):
		back()
		get_viewport().set_input_as_handled()

## Screenshots (--overlay=<which>[:arg]): opens one menu, or a confirm box, tooltip or toast over it.
func shot_demo(which: PackedStringArray) -> void:
	ctx = ctx_now()
	var arg := which[1] if which.size() > 1 else ""
	match which[0]:
		"pause":
			open_pause(ctx)
		"settings":
			if arg != "":
				tab = arg
			open_settings()
		"admin":
			open_admin()
		"saves":
			open_saves()
		"inventory":
			if arg != "":
				inv_tab = arg
			open_inventory()
		"dex":
			inv_tab = "Field Book"
			open_inventory()
			open_dex(arg if arg != "" else "cindle")
		"hunters":
			var psc = Game.main.screen_node() if Game.main else null
			if psc is Match and Practice.of(psc):
				PracticeHero.open(Practice.of(psc))      # the Hunters picker (class titles)
		"confirm":
			open_pause(ctx)
			UI.confirm(root, "Leave the match?", "You lose everything you carry, and any Boki you brought is left behind.",
				"Leave", close)
		"tooltip":
			tab = "Controls"
			open_settings()
			var tip := PanelContainer.new()
			tip.add_theme_stylebox_override("panel", UI.theme().get_stylebox("panel", "TooltipPanel"))
			var tl := Label.new()
			tl.text = "Main key: click, then press a key or mouse button"
			tl.theme_type_variation = "TooltipLabel"
			tip.add_child(tl)
			tip.top_level = true
			tip.position = Vector2(700, 300)
			host.get_child(host.get_child_count() - 1).add_child(tip)

func ctx_now() -> String:
	var s = Game.main.screen_node() if Game.main else null
	if s == null: return "title"
	var path := String(s.get_script().resource_path) if s.get_script() else ""
	if path.ends_with("home.gd"): return "home"
	if path.ends_with("town.gd"): return "town"
	if path.ends_with("interior.gd"): return "interior"
	if s is Match: return "match"
	return "title"

# ------------------------------------------------------------------ pages
func _page(name: String, title_txt: String, width := 620.0, scroll := false) -> VBoxContainer:
	for ch in host.get_children():
		ch.queue_free()
	if page != "" and page != name and not stack.has(page):
		stack.append(page)
	var was_open := page != ""
	var same := page == name
	page = name
	if not was_open:
		UI.show_backdrop(dim, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not was_open and Game.main:
		var s = Game.main.screen_node()
		if s and s.has_method("on_menu_opened"):
			s.on_menu_opened()
	var pb := UI.scroll_panel(title_txt, width, back, "Back" if stack.size() > 0 else "Close", scroll)
	host.add_child(pb[0])
	if not same:
		UI.pop_in(pb[0])
	return pb[1]

func back() -> void:
	if stack.size() > 0:
		var prev: String = stack.pop_back()
		page = ""
		match prev:
			"pause": open_pause(ctx)
			"settings": open_settings()
			"saves": open_saves()
			"inventory": open_inventory()
			"dex": open_dex(dex_open)
			_: close()
	else:
		close()

func close() -> void:
	for ch in host.get_children():
		ch.queue_free()
	page = ""
	stack.clear()
	listening = ""
	delete_armed = -1
	UI.show_backdrop(dim, false)
	Sfx.play("ui_close", null, -14.0)
	closed.emit()

## The Esc menu: Resume on top, the places you go most next, the rare ones as quiet links, and
## leaving at the bottom.
func open_pause(where: String) -> void:
	ctx = where
	Sfx.play("ui_open", null, -10.0)
	stack.clear()
	page = ""
	var v := _page("pause", "Paused" if where == "match" else "Menu", 440)
	UI.subtitle(v, {"match": "The expedition waits while you're here", "home": "Your island", "town": "In town", "interior": "At home"}.get(where, ""))
	var bw := 388.0
	var item := func(txt: String, icon: String, cb: Callable, key := "", tier := "") -> Button:
		var b := UI.button(txt, cb, bw, icon)
		if tier != "": b.theme_type_variation = tier
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if key != "": UI.with_key(b, key)
		v.add_child(b)
		return b
	var res: Button = item.call("Resume", "next", close, "Esc", "Primary")
	var psc = Game.main.screen_node() if where == "match" and Game.main else null
	var practice: Practice = Practice.of(psc) if psc is Match else null
	if practice:
		item.call("Change Hunter", "swap", func(): close(); PracticeHero.open(practice), Settings.key_cap("hero"))
	if where != "match":
		item.call("Inventory", "bag", open_inventory, Settings.key_cap("inventory"))
	if where == "home" and Game.main:
		item.call("Training area", "jump", func():
			close()
			Game.main.screen_node()._start_training())
	item.call("Settings", "gear", func():
		if tab == "Controls": tab = "Gameplay"
		open_settings())
	item.call("Controls", "dash", func(): tab = "Controls"; open_settings())
	if where != "match":
		item.call("Save files", "satchel", open_saves)
	# the rarely used ones: quiet text links in a row
	var minor := HFlowContainer.new()
	minor.add_theme_constant_override("h_separation", 4); minor.add_theme_constant_override("v_separation", 2)
	if where == "home":
		minor.add_child(UI.ghost("Change your look", func():
			close()
			Game.goto("hatch", {"create": true})))
	var scr = Game.main.screen_node() if Game.main else null
	if scr and scr.has_method("unstick"):
		minor.add_child(UI.ghost("I'm stuck", func():
			close()
			scr.unstick()
			Sfx.play("whoosh")))
	if admin_allowed():
		minor.add_child(UI.ghost("Admin tools  (F1)", open_admin))
	if minor.get_child_count() > 0:
		v.add_child(minor)
	v.add_child(UI.spacer(2))
	if where == "match":
		var m = Game.main.screen_node()
		var tut: bool = m.opts.get("tutorial", false) or m.opts.get("training", false)
		var leave := func():
			close()
			Practice.leave(m, tut)
		if tut:
			item.call("Leave the training area" if m.opts.get("training", false) else "Skip the tutorial", "back", leave)
		else:
			var lb: Button = item.call("Leave match", "back", func():
				UI.confirm(root, "Leave the match?", "You lose everything you carry, and any Boki you brought is left behind.", "Leave", leave), "", "Danger")
			lb.tooltip_text = "You lose what you carry"
	else:
		item.call("Save and go to the main menu", "home", func():
			Save.save_game()
			close()
			RateCard.gate(root, func(): Game.goto("title")))
	if not OS.has_feature("web"):
		var q: Button = item.call("Save and quit the game", "close", func():
			Save.save_game()
			RateCard.gate(root, get_tree().quit), "", "Ghost")
		q.add_theme_color_override("font_color", UI.MUTED)
	res.grab_focus.call_deferred()

# ------------------------------------------------------------------ settings
func open_settings() -> void:
	_show_settings()

func _show_settings() -> void:
	var v := _page("settings", "Settings", 720, true)
	UI.shell_tabs(v, SETTINGS_TABS, tab, func(t):
		tab = t
		_show_settings())
	match tab:
		"Gameplay": _tab_gameplay(v)
		"Controls": _tab_controls(v)
		"Camera": _tab_camera(v)
		"Audio": _tab_audio(v)
		"Video": _tab_video(v)
		"Accessibility": _tab_access(v)
		"Demo": _tab_demo(v)
	UI.footer_left(v).add_child(UI.ghost("Reset to defaults", func():
		UI.confirm(root, "Reset every setting?", "Volume, video, gameplay and every key binding go back to how the game ships.", "Reset", func():
			Settings.reset_all()
			_show_settings())))
	var done := UI.with_key(UI.primary("Done", back, 120), "Esc")
	UI.footer(v).add_child(done)
	(v.get_meta("shell") as Control).set_meta("primary", done)

func _tab_gameplay(v: VBoxContainer) -> void:
	_group(v, "You")
	var name_row := _row(v, "Your name", "What other hunters and your Boki call you")
	var ne := LineEdit.new()
	ne.text = Save.d.get("name", "Hunter")
	ne.max_length = 16
	ne.custom_minimum_size.x = 280
	ne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ne.text_changed.connect(func(t):
		Save.d["name"] = t.strip_edges() if t.strip_edges() != "" else "Hunter"
		Save.save_game())
	name_row.add_child(ne)
	_group(v, "Expeditions")
	_toggle(v, "Damage numbers", "damage_numbers", "Numbers pop up where your hits land")
	_toggle(v, "Tips during expeditions", "tips", "Short hints about what's around you")
	_reticle_rows(v)
	_group(v, "Boki")
	var talk := [["quiet", "Quiet"], ["normal", "Normal"], ["chatty", "Chatty"]]
	_choice(v, "How much your Boki talks", "kin_chatter", talk, Callable(), "Quiet: only danger and your health. Chatty: everything it notices")
	if admin_allowed():
		_group(v, "Admin")
		_toggle(v, "Pre-match lobby", "lobby_enabled", "The 90 s lobby before each expedition. Off: plain loading")
		_toggle(v, "Mod mode", "mod_mode", "Everything unlocked, free building and bridges, god mode, spawn Boki (F1)")

func _tab_controls(v: VBoxContainer) -> void:
	_group(v, "How keys behave")
	_toggle(v, "Quick cast", "cast_on_press", "Abilities fire the moment you press them. Off: hold to aim, release to cast")
	_toggle(v, "Dash toward the cursor", "dash_to_cursor", "Off: you dash the way you're moving, or toward the cursor when standing still")
	_toggle(v, "Tap to sneak", "crouch_toggle", "Tap the sneak key to start and stop, instead of holding it")
	UI.subtitle(v, "Two keys per action: click one, then press the new key or mouse button (Esc cancels, x clears it).")
	var groups := [["Moving", ["up", "down", "left", "right", "jump", "glide", "dash", "crouch"]],
		["Fighting", [
			"fire", "secondary", "gear1", "gear2", "signature", "throw", "hunter_ult", "ultimate",
			"util1", "util2", "util3", "util4", "base",
		]],
		["Squad and map", ["ping", "map", "scores", "emote", "pass_lead", "separate"]],
		["At home", ["interact", "play", "talk", "details", "inventory", "hero"]]]
	var named := {}
	for a in Settings.ACTIONS:
		named[String(a[0])] = String(a[1])
	var shown := {}
	for g in groups:
		_group(v, String(g[0]))
		for an in g[1]:
			if not named.has(an):
				continue
			shown[an] = true
			_bind_row(v, an, named[an])
	var rest: Array = Settings.ACTIONS.filter(func(a): return not shown.has(String(a[0])))
	if not rest.is_empty():
		_group(v, "Other")
		for a in rest:
			_bind_row(v, String(a[0]), String(a[1]))
	_note(v, "Esc always opens the menu. Your gun also reloads by itself when you stop shooting.")

func _tab_camera(v: VBoxContainer) -> void:
	_group(v, "View")
	var styles: Array = CamRig.STYLES.keys().map(func(k): return [k, CamRig.STYLES[k]["name"]])
	_choice(v, "Camera", "cam_style", styles, Callable(), "How high and how wide the camera looks down on you")
	var follow := [["supervive", "Cursor lean"], ["standard", "Standard dynamic"], ["dynamic", "Fully dynamic"], ["locked", "Locked"]]
	_choice(v, "Camera follow", "cam_follow", follow, Callable(), "Cursor lean: the view slides toward where you aim")
	_slider(v, "Lean toward the cursor", "cam_lead", 0.0, 1.5)

func _tab_audio(v: VBoxContainer) -> void:
	_group(v, "Volume")
	_slider(v, "Master", "master", 0.0, 1.0)
	_slider(v, "Music", "music", 0.0, 1.0)
	_slider(v, "Sound effects", "sfx", 0.0, 1.0)
	_slider(v, "Ambience", "ambience", 0.0, 1.0, 0.05, "Wind, rain and the sea")
	_group(v, "Sounds")
	var cues := [["a", "Rising bells"], ["b", "Bell with a glide"], ["c", "Soft whoomp and ping"]]
	_choice(v, "Ability ready again", "reset_cue", cues, func(): Sfx.play_reset_cue(), "Plays when a reset hands an ability back")
	_group(v, "Window")
	_toggle(v, "Mute when the window isn't focused", "mute_unfocused")

func _tab_video(v: VBoxContainer) -> void:
	_group(v, "Display")
	_toggle(v, "Fullscreen", "fullscreen")
	if not OS.has_feature("web"):
		_toggle(v, "V-sync", "vsync", "Stops tearing; can add a little input delay")
	var fps := [[0, "None"], [30, "30"], [60, "60"], [120, "120"], [144, "144"]]
	_choice(v, "Frame rate limit", "max_fps", fps)
	_group(v, "Quality")
	var auto_pick := Settings.quality() if String(Settings.get_v("quality")) == "auto" else Settings.detect_quality()
	var qopts := [["auto", "Auto (%s)" % String(Settings.QUALITY[auto_pick]["name"])]]
	for qk in Settings.QUALITY_ORDER:
		qopts.append([qk, String(Settings.QUALITY[qk]["name"])])
	_choice(v, "Graphics quality", "quality", qopts, func(): _show_settings.call_deferred(),
		"Grass, draw distance, cloud layers and particles change from your next expedition")
	_choice(v, "Anti-aliasing", "msaa", [[0, "Off"], [2, "2x"], [4, "4x"]], Callable(), "Smooths jagged edges")
	_toggle(v, "Shadows", "shadows")
	_choice(v, "Frame rate", "show_fps", [[0, "Hidden"], [1, "Frame rate"], [2, "Performance overlay"]], Callable(),
		"Top right. The overlay adds frame time, draw calls, triangles and script costs")
	var modelled: Array = Arch.ORDER.filter(WardenGlb.has_model)
	if not modelled.is_empty():
		_group(v, "Hunter models")
		for a in modelled:
			var hint := "Off: the simpler built-in model. From the next match or Hunter swap"
			var r := _row(v, String(WardenGlb.ART[a]).capitalize(), hint)
			var cb := CheckButton.new()
			cb.text = "3D model"
			cb.button_pressed = WardenGlb.uses_model(a)
			cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cb.toggled.connect(func(on): WardenGlb.set_model(a, on))
			r.add_child(cb)

func _tab_access(v: VBoxContainer) -> void:
	_group(v, "Readability")
	_slider(v, "Interface size", "ui_scale", 0.75, 1.5, 0.05, "Menus and the HUD, on top of fitting your window")
	_toggle(v, "Height cues", "depth_cues", "Shaded cliffs, lit edges, a shadow under every hunter (next expedition)")
	_group(v, "Comfort")
	_slider(v, "Screen shake", "screen_shake", 0.0, 1.0, 0.05, "Only big hits on you shake the view; 0 turns it off")
	_toggle(v, "Fewer flashes", "reduce_flashes", "Softer full-screen flashes when you're hit or level up")

## Filming: kept between launches, applied when the next offline match starts.
func _tab_demo(v: VBoxContainer) -> void:
	_group(v, "Recording")
	var rec_hint := "Clean HUD hides tips and debug text and smooths the camera. %s cycles it in a match, %s orbits the camera with No HUD"
	var rec_row := _row(v, "Recording mode", rec_hint % [Settings.key_cap("record"), Settings.key_cap("record_orbit")])
	var rec_ob := OptionButton.new()
	rec_ob.custom_minimum_size.x = 280
	rec_ob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in Record.NAMES.size():
		rec_ob.add_item(String(Record.NAMES[i]), i)
	rec_ob.selected = Record.level
	rec_ob.item_selected.connect(func(i):
		Record.set_level(i)
		Settings.set_v("rec_level", i))
	rec_row.add_child(rec_ob)
	_group(v, "Next match")
	_choice(v, "Weather", "demo_weather", [["random", "Random"], ["clear", "Always clear"]])
	_choice(v, "Blight", "demo_blight", [[true, "On"], [false, "Off"]])
	var fresh := [["normal", "Normal (%d s)" % int(Bot.FRESH_T)], ["long", "Longer (%d s)" % int(Settings.DEMO_FRESH_T)]]
	_choice(v, "Bots leave you be after landing", "demo_fresh", fresh)
	_toggle(v, "All Relics open (offline only)", "demo_all_masks", "Every Relic is pickable. Unlocks are untouched")
	_note(v, "These apply from the next match you start, offline only. Online matches play the host's rules.")

## Settings > Gameplay > Reticle: the aiming reticle's shape (with a preview), size, colour, opacity and outline.
func _reticle_rows(v: VBoxContainer) -> void:
	_group(v, "Reticle")
	_choice(v, "Shape", "reticle_shape", Reticle.SHAPES, Callable(), "Default: a small broken ring with a dot")
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(40, 40)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.draw.connect(func():
		preview.draw_rect(Rect2(Vector2.ZERO, preview.size), Color(0.16, 0.2, 0.17))
		Reticle.draw(preview, preview.size * 0.5))
	Settings.changed.connect(preview.queue_redraw.unbind(1))
	v.get_child(v.get_child_count() - 1).add_child(preview)
	_slider(v, "Size", "reticle_size", 0.5, 2.0)
	var row := _row(v, "Colour", "High-vis yellow stands out best on busy ground")
	for id in Reticle.COLORS:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(26, 26)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.tooltip_text = String(Reticle.COLORS[id][0])
		var chosen: bool = Settings.get_v("reticle_col") == id
		var face := UI.frame(Reticle.COLORS[id][1], 13, UI.INK if chosen else Color(0, 0, 0, 0), 3)
		for state in ["normal", "hover", "pressed"]:
			sw.add_theme_stylebox_override(state, face)
		sw.pressed.connect(func():
			Settings.set_v("reticle_col", id)
			_show_settings.call_deferred())
		row.add_child(sw)
	_slider(v, "Opacity", "reticle_alpha", 0.2, 1.0)
	_toggle(v, "Dark outline", "reticle_outline", "Keeps it readable over bright effects")

## A small heading over a group of settings rows.
func _group(v: VBoxContainer, txt: String) -> void:
	if v.get_child_count() > 0:
		v.add_child(UI.spacer(4))
	v.add_child(UI.section(txt, UI.FAINT.lightened(0.2)))

## One settings row: the name on the left (with an optional hint under it), the control on the right.
func _row(v: VBoxContainer, label_txt: String, hint := "") -> HBoxContainer:
	var r := UI.hbox(16)
	r.custom_minimum_size.y = 40
	var lc := UI.vbox(1)
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lc.add_child(UI.label(label_txt, UI.T_BODY, UI.INK, UI.semi))
	if hint != "":
		lc.add_child(UI.para(hint, UI.T_SMALL - 1, UI.MUTED))
	r.add_child(lc)
	v.add_child(r)
	return r

func _bind_row(v: VBoxContainer, an: String, what: String) -> void:
	var r := _row(v, what)
	r.custom_minimum_size.y = 34
	var sl := Settings.slots(an)
	for slot in 2:
		var cell := UI.hbox(2)
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var code: String = sl[slot]
		var b := UI.button(_bind_text(code, slot), Callable(), 132)
		b.tooltip_text = ("Main key" if slot == 0 else "Second key") + ": click, then press a key or mouse button"
		if code == "" and slot == 1:
			b.modulate = Color(1, 1, 1, 0.55)
		b.pressed.connect(func():
			listening = an
			listening_slot = slot
			b.text = "Press a key..."
			b.theme_type_variation = "Chosen"
			listen_lbl = null)
		cell.add_child(b)
		var x := UI.ghost("x", func():
			Settings.clear_bind(an, slot)
			_show_settings())
		x.custom_minimum_size.x = 26
		x.tooltip_text = "Clear this key"
		x.disabled = code == ""
		x.modulate.a = 1.0 if code != "" else 0.25
		cell.add_child(x)
		r.add_child(cell)

func _bind_text(code: String, slot: int) -> String:
	if code != "":
		return Settings.code_text(code)
	return "Not set" if slot == 0 else "+ second key"

func _slider(v: VBoxContainer, label_txt: String, key: String, lo: float, hi: float, step := 0.05, hint := "") -> void:
	var r := _row(v, label_txt, hint)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(Settings.get_v(key))
	sl.custom_minimum_size.x = 228
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := UI.label("%d%%" % int(round(sl.value * 100.0)), UI.T_SMALL, UI.MUTED, UI.semi)
	pct.custom_minimum_size.x = 44
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if key == "ui_scale":
		# applies when you let go (or click the track), so the slider doesn't run away from the mouse
		sl.drag_ended.connect(func(_c): Settings.set_v(key, sl.value))
		sl.value_changed.connect(func(val):
			pct.text = "%d%%" % int(round(val * 100.0))
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				Settings.set_v(key, val))
	else:
		sl.value_changed.connect(func(val):
			pct.text = "%d%%" % int(round(val * 100.0))
			Settings.set_v(key, val, false))
		sl.drag_ended.connect(func(_c): Settings.save())
	r.add_child(sl)
	r.add_child(pct)

func _toggle(v: VBoxContainer, label_txt: String, key: String, hint := "") -> void:
	var r := _row(v, label_txt, hint)
	var cb := CheckButton.new()
	cb.button_pressed = bool(Settings.get_v(key))
	cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cb.toggled.connect(func(on): Settings.set_v(key, on))
	r.add_child(cb)

## A quiet line of fine print under a group.
func _note(v: VBoxContainer, txt: String) -> void:
	v.add_child(UI.para(txt, UI.T_SMALL, UI.MUTED))

func _choice(v: VBoxContainer, label_txt: String, key: String, opts: Array, then := Callable(), hint := "") -> void:
	var r := _row(v, label_txt, hint)
	var ob := OptionButton.new()
	ob.custom_minimum_size.x = 280
	ob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cur = Settings.get_v(key)
	for i in opts.size():
		ob.add_item(String(opts[i][1]), i)
		if opts[i][0] == cur:
			ob.select(i)
	ob.item_selected.connect(func(i):
		Settings.set_v(key, opts[i][0])
		if then.is_valid():
			then.call())
	r.add_child(ob)

func _finish_rebind(ev: InputEvent) -> void:
	var an := listening; var slot := listening_slot
	listening = ""
	Sfx.play("click")
	var cf: Array = Settings.conflicts(ev, an)
	if cf.is_empty():
		Settings.rebind(an, ev, slot)
		_show_settings()
		return
	# already someone else's key: say whose, and offer to swap (they get what this slot had)
	var named := {}
	for a in Settings.ACTIONS: named[String(a[0])] = String(a[1])
	var other: String = cf[0][0]; var oslot: int = cf[0][1]
	var mine: String = Settings.slots(an)[slot]
	var key_txt := Settings.code_text(Settings.ev_code(ev))
	var oname := "\"%s\"" % named.get(other, other)
	var txt := "%s is already the key for %s.\nSwap them (%s gets %s), or use it for both?" % [key_txt, oname, oname, Settings.code_text(mine) if mine != "" else "no key"]
	_show_settings()
	var layer := UI.confirm(root, "Key already in use", txt, "Swap", func():
		Settings.swap_bind(an, slot, ev, other, oslot)
		_show_settings(), false)
	set_meta("bind_conflict", layer)
	var row: Node = layer.find_children("*", "HBoxContainer", true, false).back()
	var both := UI.ghost("Use for both", func():
		layer.queue_free()
		Settings.rebind(an, ev, slot)
		_show_settings())
	row.add_child(both)
	row.move_child(both, 1)

# ------------------------------------------------------------------ inventory
var inv_tab := "Items"
const INV_H := 404.0          # the inventory's body height on every tab (fits a 720p window)
var dex_open := ""            # the species whose Field Book page is open

## A Boki's page in the Field Book (a sub-page of the inventory: Esc or Back returns to the grid).
func open_dex(spk: String) -> void:
	dex_open = spk
	var v := _page("dex", "Field Book", 760)
	UI.hold(v, INV_H + 58.0)        # the inventory's height (a sub-page has no tab row, so its body is taller)
	DexView.detail(v, spk, get_tree())

func open_inventory() -> void:
	var v := _page("inventory", "Inventory", 760)
	UI.hold(v, INV_H)          # every tab the same size: switching tabs never resizes the panel
	if inv_tab == "Items":      # one currency, and only where it matters
		UI.head_extra(v).add_child(UI.chip("gem", str(int(Save.d["gems"])), UI.GOLD, "Gems"))
	var icon_of := {"Items": "tonic", "Seeds": "seed", "Crops": "seed", "Furniture": "home", "Kin": "paw", "Field Book": "egg"}
	UI.shell_tabs(v, ["Items", "Seeds", "Crops", "Furniture", "Kin", "Field Book"], inv_tab, func(t):
		inv_tab = t; UI._page_of.erase("Inventory"); open_inventory())
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var cell := func(title_txt: String, count_txt: String, desc: String, col: Color, action_txt := "", action := Callable(), icon := "") -> void:
		var c := UI.card(UI.CARD, 12, 12)
		c.custom_minimum_size = Vector2(222, 0)
		var cv := UI.vbox(6); c.add_child(cv)
		var top := UI.hbox(10)
		var dot := UI.badge(icon if icon != "" else String(icon_of.get(inv_tab, "gem")), col, 36.0, UI.R_CTRL)
		top.add_child(dot)
		var tc := UI.vbox(0); tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tl := UI.label(title_txt, UI.T_BODY, UI.INK, UI.semi); tl.clip_text = true
		tc.add_child(tl)
		if count_txt != "": tc.add_child(UI.label(count_txt, UI.T_SMALL, UI.GOLD))
		top.add_child(tc)
		cv.add_child(top)
		if desc != "":
			var dl := UI.para(desc, 12, UI.MUTED)
			cv.add_child(dl)
		if action.is_valid():
			cv.add_child(UI.button(action_txt, action))
		grid.add_child(c)
	var empty := true
	match inv_tab:
		"Items":
			empty = false
			cell.call("Gems", str(int(Save.d["gems"])), "Spend them at the stall, on buildings and furniture.", UI.GOLD, "", Callable(), "gem")
			cell.call("Tonics", "×%d" % int(Save.d["items"].get("tonic", 0)), "Heal 40% in a match (belt key %s)." % Settings.key_cap("util1"), Color("8ff0a0"), "", Callable(), "tonic")
			for f in Care.FOODS:
				var fn := int(Save.d["items"].get(f, 0))
				if fn > 0: cell.call(Care.FOODS[f]["name"], "×%d" % fn, Care.FOODS[f]["desc"] + " Feed it from a Boki's card.", Care.FOODS[f]["col"])
			var tr: String = Save.d.get("treat", "")
			if tr != "":
				cell.call("Treat ready", "", "Your partner eats it before the next expedition.", Color("f2c84a"))
		"Seeds":
			for k in Data.CROPS:
				var n := int(Save.d["seeds"].get(k, 0))
				if n <= 0: continue
				empty = false
				cell.call(Data.CROPS[k]["name"] + " seed", "×%d" % n, "Plant it in a farm plot.", Data.CROPS[k]["color"])
		"Crops":
			for k in Data.CROPS:
				var n := int(Save.d["crops"].get(k, 0))
				if n <= 0: continue
				empty = false
				var ck: String = k
				cell.call(Data.CROPS[k]["name"], "×%d" % n, Data.CROPS[k]["desc"], Data.CROPS[k]["color"], "Feed to your partner", func():
					var ak := Save.active_kin()
					if ak.is_empty() or int(Save.d["crops"].get(ck, 0)) <= 0: return
					Save.d["crops"][ck] = int(Save.d["crops"][ck]) - 1
					for af in Evo.AFF:
						if Evo.AFF[af]["food"] == ck: Evo.add(ak, af, 6.0)
					Save.remember(ak, "fed", "was fed a %s" % Data.CROPS[ck]["name"].to_lower(), 4.0)
					Sfx.play("kin_happy")
					Save.save_game()
					open_inventory())
		"Furniture":
			for k in Data.FURN:
				var n := int(Save.d.get("furniture", {}).get(k, 0))
				if n <= 0: continue
				empty = false
				cell.call(Data.FURN[k]["name"], "×%d" % n, "Place it inside your house: go in and press B.", Color("c99a6a"))
		"Kin":
			for rec in Save.d["roster"]:
				empty = false
				grid.add_child(_boki_card(rec))
		"Field Book":
			# the Field Book: numbered tiles, each opening its own page (DexView)
			empty = false
			grid.queue_free()
			DexView.grid(v, get_tree(), func(spk: String): open_dex(spk))
	if empty:
		var es: Array = {"Seeds": ["No seeds", "Find them on expeditions or buy them at the stall."], "Crops": ["No crops yet", "Harvest your plots."],
			"Furniture": ["Nothing stored", "Furniture you buy or put away lands here."], "Kin": ["No Boki yet", "Hatch an egg to get your first."]}.get(inv_tab, ["Nothing here", ""])
		v.add_child(UI.empty_state(String(icon_of.get(inv_tab, "gem")), es[0], es[1]))

## A Boki in the inventory's Boki tab: its portrait, name with its sex, level, form and bond.
func _boki_card(rec: Dictionary) -> Control:
	var c := UI.card(UI.CARD, 10, 12)
	c.custom_minimum_size = Vector2(222, 0)
	var h := UI.hbox(10); c.add_child(h)
	h.add_child(KinPortrait.view(rec, get_tree(), 56.0))
	var tv := UI.vbox(2); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.name_with_sex(rec, String(rec["name"]), UI.T_BODY, UI.INK, UI.semi, 13.0)
	tv.add_child(nm)
	tv.add_child(UI.label("Lv %d  ·  %s" % [int(rec["level"]), Evo.form_name(rec)], UI.T_SMALL, UI.MUTED))
	var bits: Array = ["%s bond" % Care.bond(rec)[1]]
	if rec["uid"] == Save.d.get("active", ""): bits.push_front("Partner")
	elif KinBox.is_boxed(rec): bits.push_front("In the Burrow")
	tv.add_child(UI.label("  ·  ".join(bits), 12, UI.MUTED))
	h.add_child(tv)
	return c

# ------------------------------------------------------------------ save files
func open_saves() -> void:
	var v := _page("saves", "Save files", 640, true)
	UI.subtitle(v, "Each save has its own island, Boki and gems. Settings are shared.")
	var first: Button = null
	for n in range(1, Save.SLOTS + 1):
		var info := Save.slot_info(n)
		var playing: bool = n == Save.slot
		var c := UI.card(Color(UI.ACCENT, 0.1) if playing else UI.CARD, 14, 14)
		if playing: UI.set_card_border(c, Color(UI.ACCENT, 0.6), 1)
		var h := UI.hbox(14); c.add_child(h)
		var num := UI.title(str(n), 30, UI.ACCENT_HI if playing else UI.MUTED)
		num.custom_minimum_size.x = 26
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(num)
		var col := UI.vbox(2); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(col)
		var sn: int = n
		if info["exists"]:
			var tr := UI.hbox(8)
			tr.add_child(UI.label(String(info["name"]), UI.T_HEAD, UI.INK, UI.big))
			if playing: tr.add_child(UI.tag("Playing", UI.ACCENT))
			col.add_child(tr)
			col.add_child(UI.label("%d Boki  ·  %d gems  ·  %d expeditions  ·  %s" % [info["kin"], info["gems"], info["matches"], info["when"]], UI.T_SMALL, UI.MUTED))
			if not playing:
				var pb := UI.primary("Play", func(): _play_slot(sn), 96)
				pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				h.add_child(pb)
				if first == null: first = pb
			var del := UI.icon_button("close", func():
				UI.confirm(root, "Delete save %d?" % sn, ("This is the save you're playing: deleting it takes you back to the title. " if playing else "") + "Its island, Boki and gems are gone for good.", "Delete", func():
					Save.delete_slot(sn)
					if playing:
						# that was the save in play: start over from the title, on this now-empty slot
						Save.save_game()
						close()
						Game.goto("title")
					else:
						open_saves()), "Delete this save", 12.0)
			del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(del)
		else:
			col.add_child(UI.label("Empty slot", UI.T_HEAD, UI.MUTED, UI.big))
			col.add_child(UI.label("Start a new story here", UI.T_SMALL, UI.FAINT))
			var nb := UI.button("New game", func(): _play_slot(sn), 120, "plus")
			nb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(nb)
		v.add_child(c)
	if first: first.grab_focus.call_deferred()

func _play_slot(n: int) -> void:
	Save.use_slot(n)
	close()
	Social.refresh_guild()
	# a brand-new save opens with the story, which then leads into the first egg
	Game.goto("home" if not Save.d["roster"].is_empty() else "prologue")

# ------------------------------------------------------------------ admin
func open_admin() -> void:
	if page != "admin" and page != "":
		stack.append(page)
	var c := ctx_now()
	var v := _page("admin", "Admin tools", 640)
	v.add_child(UI.label("For testing. F1 or ` opens this anywhere.", 13, UI.MUTED))
	var god := CheckButton.new()
	god.text = "God mode: can't be hurt or fall, no cooldowns, endless ammo"
	god.button_pressed = Game.god
	god.toggled.connect(func(on): Game.god = on)
	v.add_child(god)
	# bot difficulty: Auto follows the run tier (and your experience); the rest force one
	v.add_child(UI.section("Bot difficulty"))
	var drow := HFlowContainer.new()
	drow.add_theme_constant_override("h_separation", 8); drow.add_theme_constant_override("v_separation", 8)
	var cur_d := String(Settings.get_v("bot_diff"))
	for dk in ["auto"] + Data.BOT_ORDER:
		var dkey: String = dk
		drow.add_child(UI.choice("Auto" if dkey == "auto" else String(Data.BOT_DIFF[dkey]["name"]), dkey == cur_d, func():
			Settings.set_v("bot_diff", dkey)
			Sfx.play("pickup")
			open_admin(), 104))
	v.add_child(drow)
	var dnote := "Auto: Meadow bots are Easy, Dusk Isles Medium, the Hollow Hard, one step up once you've extracted a lot."
	if c == "match":
		var mm = Game.main.screen_node()
		dnote += "  This run: %s. Changes apply from the next expedition." % String(Data.BOT_DIFF[mm.bot_diff]["name"])
	v.add_child(UI.label(dnote, 13, UI.MUTED))
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var add := func(txt: String, f: Callable):
		var b := UI.button(txt, func():
			f.call()
			Sfx.play("pickup")
			Save.save_game()
			_admin_refresh(), 290)
		grid.add_child(b)
	add.call("+1000 gems", func(): Save.d["gems"] = int(Save.d["gems"]) + 1000)
	add.call("+10 of every seed", func():
		for s in Data.CROPS: Save.add_seed(s, 10))
	add.call("+5 of every crop", func():
		for s in Data.CROPS: Save.d["crops"][s] = int(Save.d["crops"].get(s, 0)) + 5)
	add.call("+5 tonics", func(): Save.add_item("tonic", 5))
	add.call("Partner +1 level", func():
		var k := Save.active_kin()
		if not k.is_empty():
			k["level"] = int(k["level"]) + 1
			Game._evolve(k, {}))
	add.call("Partner full trust", func():
		var k := Save.active_kin()
		if not k.is_empty(): k["trust"] = 100.0)
	add.call("Grow every crop now", func():
		for arr in ["plots", "gh_plots"]:
			for p in Save.d.get(arr, []):
				if p["crop"] != "":
					p["stage"] = int(Data.CROPS[p["crop"]]["grow"])
					p["care"] = p["stage"]
		if c == "home": _reload_home())
	add.call("Unlock every building and bridge", func():
		for b in Data.BUILDINGS:
			if not Save.d["buildings"].has(b): Save.d["buildings"].append(b)
		for i in Data.ISLES:
			if not Save.d["bridges"].has(i): Save.d["bridges"].append(i)
		Save.d["extracts"] = maxi(int(Save.d.get("extracts", 0)), 10)
		if c == "home": _reload_home())
	add.call("Unlock every expedition tier", func(): Save.d["extracts"] = maxi(int(Save.d.get("extracts", 0)), 10))
	add.call("Replay the tutorials", func(): Save.d["tutorial"] = {})
	var spawn := UI.button("Spawn a Boki…", open_spawn_kin, 290)
	grid.add_child(spawn)
	if c == "home":
		var h = Game.main.screen_node()
		add.call("Morning", func(): h.day_t = 0.27)
		add.call("Night", func(): h.day_t = 0.95)
		add.call("Rain on / off", func():
			h.raining = not h.raining
			h.weather_t = 999.0 if h.raining else 60.0
			h.rain.emitting = h.raining)
	if c == "match":
		var m = Game.main.screen_node()
		add.call("Ultimate and ability ready", func():
			if m.player:
				m.player.ult = 1.0; m.player.sig_cd = 0.0)
		add.call("Defeat every monster", func():
			for mb in m.mobs:
				if not mb.dead: mb.hurt(99999.0, m.player, {}))
		add.call("Exits ready now", func():
			if m.exits: m.exits.admin_ready())
		add.call("Extract now", func():
			if m.player and not m.player.out:
				close()
				m._extract(m.player))
	var stat := UI.label("", 13, UI.MUTED)
	stat.name = "AdminStat"
	v.add_child(stat)
	_admin_refresh()

var admin_mut := ""            # admin spawn: the rare mutation the next kin comes with
var admin_shimmer := false
## Admin: pick any species to add to your farm.
func open_spawn_kin() -> void:
	if page != "spawn" and page != "":
		stack.append(page)
	var v := _page("spawn", "Spawn a Boki", 640)
	v.add_child(UI.label("Adds a level 8 Boki with a Close bond to your farm (or the Boki Burrow, if it's a repeat or the farm is full).", 13, UI.MUTED))
	var mrow := HFlowContainer.new()
	mrow.add_theme_constant_override("h_separation", 6); mrow.add_theme_constant_override("v_separation", 6)
	mrow.add_child(UI.label("Mutation:", 13, UI.MUTED))
	for mid in [""] + Mutations.ids():
		var mk: String = mid
		mrow.add_child(UI.choice("none" if mk == "" else Mutations.name_of(mk), admin_mut == mk, func(): admin_mut = mk; open_spawn_kin()))
	mrow.add_child(UI.choice("Shimmer", admin_shimmer, func(): admin_shimmer = not admin_shimmer; open_spawn_kin()))
	v.add_child(mrow)
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for sp in Data.KIN:
		var sid: String = sp
		var b := UI.button(String(Data.KIN[sid]["name"]), func():
			var rec := Save.new_kin(sid)
			rec["level"] = 8
			rec["trust"] = 60.0
			Evo.simulate(rec, RandomNumberGenerator.new())
			if admin_mut != "": rec["mutations"] = [admin_mut]
			if admin_shimmer: rec["shimmer"] = true
			Save.d["roster"].append(rec)
			KinBox.route_new(rec)
			Care.dex_got(rec)
			Save.save_game()
			Sfx.play("unlock")
			var s = Game.main.screen_node() if Game.main else null
			if s and s.has_method("_spawn_kin"):
				s._spawn_kin()
			_admin_refresh(), 196)
		b.add_theme_color_override("font_color", Data.KIN[sid]["color"])
		grid.add_child(b)
	var stat := UI.label("", 13, UI.MUTED)
	stat.name = "AdminStat"
	v.add_child(stat)
	_admin_refresh()

func _admin_refresh() -> void:
	var st := root.find_child("AdminStat", true, false)
	if st:
		var k := Save.active_kin()
		(st as Label).text = "%d gems · partner %s level %d, trust %d" % [int(Save.d["gems"]), k.get("name", "none"), int(k.get("level", 0)), int(k.get("trust", 0))]
	var s = Game.main.screen_node() if Game.main else null
	if s and s.has_method("_refresh_top"):
		s._refresh_top()

func _reload_home() -> void:
	close()
	Game.goto("home")
