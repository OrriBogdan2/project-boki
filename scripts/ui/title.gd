extends Node
## Title screen: the painted splashes (TitleBackdrop) under the logo, the menu as torn strips on the
## left (one big button, then the rest; no subtext), the build at the bottom, the playtest chip.
##
## Tooling: --title-check runs tools/title_check.gd.

var t := 0.0
var logo: Control
var menu_col: VBoxContainer
var stung := false

const DISCORD := "https://discord.gg/nbeBaU7xt"        # the playtest server (never expires)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_music(Soundtrack.track("menu", "title"))
	Feedback.flush(self)                # a rating that could not be sent last time
	Sfx.play_ambience("match")          # the wind
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
	lt.custom_minimum_size = Vector2(500, 150)      # shrinks on a short window; the list below never leaves it
	lt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo = lt
	logo.name = "Logo"
	col.add_child(logo)
	# no tagline under the logo
	var has: bool = not Save.d["roster"].is_empty()
	col.add_child(UI.spacer(12 if has else 30))     # (with a save the menu has one more row: Demo match)
	# the one big button: carry on where you left off, or start a new story
	var b1 := _menu_main(("Continue" if has else "New game"), func(): Game.goto("home" if has else "prologue"))
	col.add_child(b1)
	# no subtext under the main button
	col.add_child(UI.spacer(6 if has else 18))
	var items: Array = []
	# the Training Grounds: every archetype's kit against dummies and a sparring bot, no save needed
	items.append(["Training Grounds", func(): Game.start_match(Match.arena_opts()), "knock"])
	if has:
		# one click to a match made for filming: Duos with a bot squadmate who leads the drop to a boss lair
		# next to an uplink, clear weather, no Blight, the usual rivals (Match.demo_opts)
		items.append(["Demo match", func(): Game.start_match(Match.demo_opts()), "updraft"])
	if has:
		items.append(["Play with your Boki", func(): Game.goto("home", {"play_hub": true}), "bond"])
	if Net.available():
		items.append(["Play with friends", func(): Game.goto("lobby", {}), "bond"])
	if Net.mm.addr != "":
		items.append(["Party", func(): Game.goto("party", {}), "bond"])
	items.append(["Save files", func(): Overlay.ctx = "title"; Overlay.open_saves(), "satchel"])
	items.append(["Settings", func(): Overlay.ctx = "title"; Overlay.open_settings(), "gear"])
	if not OS.has_feature("web"):
		items.append(["Quit", func(): RateCard.gate(Overlay.root, get_tree().quit), "close"])
	for it in items:
		col.add_child(_menu_item(String(it[0]), it[1], String(it[2])))
	var i := 0
	for ch in col.get_children():
		if ch == logo: continue
		UI.pop_in(ch, 0.9 + i * 0.07)
		i += 1
	# bottom corners: what this is, and how to drive the menu without a mouse
	var ver := UI.label("v" + Net.VERSION, 13, Color(1, 1, 1, 0.45))
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
	b1.grab_focus()

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
	if k != KEY_W and k != KEY_S:
		return
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return
	var nxt := f.find_prev_valid_focus() if k == KEY_W else f.find_next_valid_focus()
	if nxt:
		nxt.grab_focus()
		get_viewport().set_input_as_handled()

func _menu_main(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb)
	b.theme_type_variation = "MenuMain"
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 300
	b.mouse_entered.connect(func(): if not b.has_focus(): b.grab_focus())
	return b

func _menu_item(text: String, cb: Callable, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "MenuItem"
	if icon != "": UI.set_icon(b, icon, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 300
	b.pressed.connect(func(): Sfx.play("click"); cb.call())
	# pointing at an item focuses it, so mouse and keyboard always agree on which one is lit
	b.mouse_entered.connect(func(): if not b.has_focus(): b.grab_focus())
	b.focus_entered.connect(func():
		Sfx.play("hover", null, -12.0, 0.05)
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover", "MenuItem"))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.queue_redraw())
	b.focus_exited.connect(func():
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_color_override("font_color")
		b.queue_redraw())
	return b
