extends Node
## Title screen: the painted splashes (TitleBackdrop) under the logo, the menu as torn strips on the
## left (one big button, then the rest; no subtext), the build at the bottom, the playtest chip.
##
## Tooling: --title-check runs tools/title_check.gd.

var t := 0.0
var logo: Control
var menu_col: VBoxContainer
var main_btn: Button
var stung := false
var admin_pop: Control         # the owner's corner popover (Test Zone, Demo Match), null without AdminGate

const LOGO_H := 150.0                 # the logo's floor; it grows into the column's spare height
const LOGO_SHORT_H := 80.0            # on a window under SHORT_WIN tall, so Quit stays on screen
const SHORT_WIN := 600.0
const DISCORD := "https://discord.gg/nbeBaU7xt"        # the playtest server (never expires)

func _ready() -> void:
	CursorMode.menu()
	Sfx.play_music(Soundtrack.track("menu", "title"))
	Feedback.flush(self)                # a rating that could not be sent last time
	Sfx.play_ambience("title")          # its own slow drone, not the match wind
	_build_ui()

func _process(delta: float) -> void:
	t += delta
	if not stung and t > 0.7:
		# the logo lands with a low horn under the music
		stung = true
		Sfx.play("horn", null, -15.0, 0.0, 0.62)

func _build_ui() -> void:
	var ui := CanvasLayer.new(); add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.name = "TitleUI"
	ui.add_child(root)
	root.add_child(TitleBackdrop.new())
	root.add_child(VoidSpecks.new())       # void specks drifting over the key art
	# a dark wash on the left so the menu reads over the scene, and a vignette with a little
	# letterbox weight top and bottom
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.03, 0.03, 0.05, 0.86)); gr.set_color(1, Color(0.03, 0.03, 0.05, 0.0))
	gr.set_offset(0, 0.25); gr.set_offset(1, 1.0)
	gt.gradient = gr; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(1, 0); gt.width = 256; gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 760
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var vig := TextureRect.new()
	var vt := GradientTexture2D.new(); var vg := Gradient.new()
	vg.set_color(0, Color(0, 0, 0, 0.0)); vg.set_color(1, Color(0.02, 0.015, 0.03, 0.62)); vg.set_offset(0, 0.5); vg.set_offset(1, 1.0)
	vt.gradient = vg; vt.fill = GradientTexture2D.FILL_RADIAL; vt.fill_from = Vector2(0.55, 0.45); vt.fill_to = Vector2(1.1, 1.1); vt.width = 128; vt.height = 128
	vig.texture = vt; vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)
	# the menu column stays vertically centred and fits any window height
	var col := VBoxContainer.new()
	col.name = "Menu"
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 76; col.offset_right = 600; col.offset_top = 24; col.offset_bottom = -60
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	root.add_child(col)
	menu_col = col
	# the brand wordmark (art/brand/logo_wordmark.png, owner-approved Nov 5)
	var lt := TextureRect.new()
	lt.texture = load("res://art/brand/logo_wordmark.png")
	lt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	lt.custom_minimum_size = Vector2(500, LOGO_H)     # the same for everyone (_fit_logo: only a short window shrinks it)
	lt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo = lt
	logo.name = "Logo"
	col.add_child(logo)
	_fit_logo()
	get_viewport().size_changed.connect(_fit_logo)
	# no tagline under the logo
	var has: bool = not Save.d["roster"].is_empty()
	col.add_child(UI.spacer(30))
	# the one big button: carry on where you left off (into the world), or start a new story
	var b1 := _menu_main(("Continue" if has else "New Game"), _continue if has else func(): Game.goto("prologue"))
	col.add_child(b1)
	main_btn = b1
	# no subtext under the main button
	col.add_child(UI.spacer(18))
	# owner 11-26: a short list. Party folds into Play with Friends, Save Files and Help sit on the Settings
	# page, Play with Your Boki is gone (the minigames are in the garden), and the owner's Test Zone and
	# Demo Match live on a small chip in the corner (_admin_chip)
	var items: Array = []
	# the Training Grounds (the farm opens the same one): every kit against dummies and a sparring bot, no save needed
	var hunter := Arch.of_save() if has else ""
	items.append(["Training Grounds", func(): Game.start_match(Match.arena_opts(hunter)), "knock"])
	if Net.available() or Net.mm.addr != "":
		items.append(["Play with Friends", _friends, "bond"])
	items.append(["Settings", func(): Overlay.ctx = "title"; Overlay.open_settings(), "gear"])
	if not OS.has_feature("web"):
		items.append(["Quit", func(): RateCard.gate(Overlay.root, get_tree().quit), "close"])
	for it in items:
		col.add_child(_menu_item(String(it[0]), it[1], String(it[2])))
	_wrap_focus()
	var i := 0
	for ch in col.get_children():
		if ch == logo: continue
		UI.pop_in(ch, 0.9 + i * 0.07)
		i += 1
	# bottom corners: what this is, and how to drive the menu without a mouse
	# the commit an itch build was made from (itch.yml writes it into project.godot): "is this the latest build?"
	var commit := String(ProjectSettings.get_setting("application/config/version", ""))
	var ver_text := "v" + Net.VERSION + ("  ·  " + commit if commit != "" else "")
	var ver := UI.label(ver_text, 13, Color(1, 1, 1, 0.45))
	ver.autowrap_mode = TextServer.AUTOWRAP_OFF
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 28; ver.offset_top = -40; ver.offset_bottom = -18
	root.add_child(ver)
	# a small playtest chip low in the corner, clear of the splash's hero: the build and the Discord link
	var news := UI.glass(8, 6)
	news.name = "News"
	news.mouse_filter = Control.MOUSE_FILTER_STOP
	news.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	news.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	news.grow_vertical = Control.GROW_DIRECTION_BEGIN
	news.offset_right = -28; news.offset_bottom = -64
	var nv := UI.hbox(10); news.add_child(nv)
	var tag := UI.label("PLAYTEST  ·  %s" % Net.VERSION, 11, Color("e9b48a"), UI.caps)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nv.add_child(tag)
	var nb := UI.ghost("Join the Discord", func(): OS.shell_open(DISCORD), 0, "bond")
	nb.focus_mode = Control.FOCUS_NONE
	nv.add_child(nb)
	root.add_child(news)
	UI.pop_in(news, 1.4)
	var keys := UI.key_hints([["W S", "choose"], ["Enter", "select"], ["Esc", "back"]], 13)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	keys.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	keys.offset_right = -28; keys.offset_top = -44; keys.offset_bottom = -16
	root.add_child(keys)
	if Overlay.admin_allowed():
		_admin_chip(root, has)
	b1.grab_focus()

func _fit_logo() -> void:
	var short := get_viewport().get_visible_rect().size.y < SHORT_WIN
	logo.custom_minimum_size.y = LOGO_SHORT_H if short else LOGO_H

## Play with Friends: back to the party when one is up, else the lobby; the party screen when only the
## matchmaker is there (the lobby leads to the party too).
func _friends() -> void:
	var party_up: bool = Net.party != null and Net.party.state != Party.State.NONE
	if party_up or not Net.available():
		Game.goto("party", {})
	else:
		Game.goto("lobby", {"from": "title"})

## Up and down walk the menu and wrap at the ends (W/S, arrows, a d-pad).
func _wrap_focus() -> void:
	var btns: Array = menu_col.get_children().filter(func(c): return c is Button)
	for i in btns.size():
		var b: Button = btns[i]
		var prev: Button = btns[(i - 1 + btns.size()) % btns.size()]
		var nxt: Button = btns[(i + 1) % btns.size()]
		b.focus_neighbor_top = b.get_path_to(prev)
		b.focus_previous = b.focus_neighbor_top
		b.focus_neighbor_bottom = b.get_path_to(nxt)
		b.focus_next = b.focus_neighbor_bottom
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.focus_neighbor_left

## The owner's corner chip (AdminGate only): a small gear above the build line that opens a tiny
## one-row popover right of the menu column with the Test Zone and (with a save) the Demo Match.
## Off the menu, so the list stays short.
func _admin_chip(root: Control, has_save: bool) -> void:
	var pop := UI.glass(8, 10)
	pop.name = "AdminPop"
	pop.visible = false
	pop.mouse_filter = Control.MOUSE_FILTER_STOP
	pop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pop.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pop.offset_bottom = -48    # (a row level with the chip; it opens right of the menu column: toggle)
	var pv := UI.hbox(6)
	pop.add_child(pv)
	var tag := UI.label("OWNER", 11, Color("e9b48a"), UI.caps)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pv.add_child(tag)
	pv.add_child(UI.ghost("Test Zone", TestZone.start, 0, "gear"))
	if has_save:
		# one click to a match made for filming: Duos with a bot squadmate who leads the drop to a boss lair
		# next to an uplink, clear weather, no Blight, the usual rivals (Match.demo_opts)
		pv.add_child(UI.ghost("Demo Match", func(): Game.start_match(Match.demo_opts()), 0, "updraft"))
	var toggle := func():
		pop.visible = not pop.visible
		pop.offset_left = main_btn.get_global_rect().end.x - root.get_global_rect().position.x + 24.0
		var to: Control = pv.get_child(1) if pop.visible else main_btn
		to.grab_focus()
	var chip := UI.icon_button("gear", toggle, "Owner tools", 14.0)
	chip.name = "AdminChip"
	chip.focus_mode = Control.FOCUS_CLICK      # the menu's up/down never lands on it
	chip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chip.offset_left = 24
	chip.offset_bottom = -48
	root.add_child(chip)
	root.add_child(pop)
	admin_pop = pop

## The owner's popover entries (empty when the chip is not there): read by --title-check.
func admin_labels() -> Array:
	if admin_pop == null:
		return []
	return admin_pop.find_children("*", "Button", true, false).map(func(b): return String((b as Button).text))

## The menu's item labels in order (the main button first): read by --title-check.
func menu_labels() -> Array:
	var out: Array = []
	if menu_col == null:
		return out
	for ch in menu_col.get_children():
		if ch is Button: out.append(String((ch as Button).text))
	return out

## W and S move through the menu as well as the arrow keys and a gamepad's d-pad.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := (event as InputEventKey).physical_keycode
	if k == KEY_ESCAPE and admin_pop and admin_pop.visible:
		admin_pop.visible = false
		main_btn.grab_focus.call_deferred()
		get_viewport().set_input_as_handled()
		return
	if k != KEY_W and k != KEY_S:
		return
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return
	if admin_pop and admin_pop.is_ancestor_of(f):
		return      # (the popover is two buttons: the arrows move there, W/S stay off the menu)
	var nxt := f.find_prev_valid_focus() if k == KEY_W else f.find_next_valid_focus()
	if nxt:
		nxt.grab_focus()
		get_viewport().set_input_as_handled()

## Continue: back into the tutorial when it was left part-way, else to the farm.
func _continue() -> void:
	if TutorialResume.pending():
		Game.start_match(TutorialResume.opts())
	else:
		Game.goto("home")

func _menu_main(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb)
	b.theme_type_variation = "MenuMain"
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 300
	_lit_on_focus(b, "MenuMain")
	return b

func _menu_item(text: String, cb: Callable, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "MenuItem"
	if icon != "": UI.set_icon(b, icon, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 300
	b.set_meta(UI.SFX_META, true)
	b.pressed.connect(func(): Sfx.play("click"); cb.call())
	b.focus_entered.connect(func(): Sfx.play("hover", null, -12.0, 0.05))
	_lit_on_focus(b, "MenuItem")
	return b

## Pointing at a menu button focuses it, and a focused one wears its hover look, so mouse and keyboard
## always agree on which one is lit (no separate focus ring).
func _lit_on_focus(b: Button, kind: String) -> void:
	b.mouse_entered.connect(func(): if not b.has_focus(): b.grab_focus())
	b.focus_entered.connect(func():
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover", kind))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.queue_redraw())
	b.focus_exited.connect(func():
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_color_override("font_color")
		b.queue_redraw())
