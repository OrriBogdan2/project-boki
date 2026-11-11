class_name UiTheme
extends RefCounted
## Builds the menus' Theme from UI's colour and size tokens and UiFrame boxes: buttons in their
## tiers, tabs, tiles, text boxes, panels, scroll bars, sliders, toggles, drop-downs and tooltips.
## The look (docs/UI_STYLE.md): ink-navy panels with a hairline rim, quiet raised buttons whose edge
## lights in the one accent (Boki teal) when you point at them, and one solid teal primary button.
## UI.install() merges it into the engine's default theme once at startup, so every Control in the
## game (menus, popups, tooltips) gets this look without a screen setting it. docs/UI_DESIGN.md.

## The whole Theme. Call through UI.theme(), which keeps the one instance.
static func build() -> Theme:
	var t := Theme.new()
	t.default_font = UI.body
	t.default_font_size = 16
	_buttons(t)
	_primary_and_danger(t)
	_quiet_buttons(t)
	_tabs_and_tiles(t)
	_front_menu(t)
	_inputs(t)
	_panels(t)
	_toggles_and_sliders(t)
	return t

## The stock focus ring: a 2 px teal outline just outside the control (keyboard and pad only).
static func ring(rad := UI.R_CTRL + 3) -> StyleBoxFlat:
	var f := UiFrame._flat(Color(0, 0, 0, 0), rad)
	f.draw_center = false
	f.border_color = Color(UI.ACCENT, 0.95)
	f.set_border_width_all(2)
	f.expand_margin_left = 3
	f.expand_margin_right = 3
	f.expand_margin_top = 3
	f.expand_margin_bottom = 3
	return f

## A button face: a raised slab with an optional outline; `down` nudges the label down a pixel
## (the size never changes).
static func slab(fill: Color, edge := Color(0, 0, 0, 0), down := false) -> UiFrame:
	var f := UiFrame.raised(fill, UI.R_CTRL, 0, UI.RIM)
	f.edge = edge
	f.padded(18, 9)
	if down:
		f.content_margin_top = 10.0
		f.content_margin_bottom = 8.0
	return f

static func _states(t: Theme, type: String, n: StyleBox, h: StyleBox, p: StyleBox, d: StyleBox) -> void:
	if type != "Button":
		t.add_type(type)
		t.set_type_variation(type, "Button")
	t.set_stylebox("normal", type, n)
	t.set_stylebox("hover", type, h)
	t.set_stylebox("pressed", type, p)
	t.set_stylebox("hover_pressed", type, p)
	t.set_stylebox("disabled", type, d)

static func _font_cols(t: Theme, type: String, col: Color, hover: Color, off: Color) -> void:
	t.set_color("font_color", type, col)
	t.set_color("font_focus_color", type, col)
	t.set_color("font_hover_color", type, hover)
	t.set_color("font_pressed_color", type, hover)
	t.set_color("font_hover_pressed_color", type, hover)
	t.set_color("font_disabled_color", type, off)

## The plain Button is the secondary tier: a quiet raised slab, so the one filled (primary) button
## on a screen is obviously the thing to press. OptionButton shares it.
static func _buttons(t: Theme) -> void:
	var n := slab(UI.RAISED, Color(1, 1, 1, 0.08))
	var h := slab(UI.RAISED.lightened(0.06), Color(UI.ACCENT, 0.7))
	var p := slab(UI.RAISED.darkened(0.12), UI.ACCENT, true)
	var d := slab(Color(UI.RAISED, 0.45))
	for type in ["Button", "OptionButton"]:
		_states(t, type, n, h, p, d)
		t.set_stylebox("focus", type, ring())
		t.set_font("font", type, UI.semi)
		t.set_font_size("font_size", type, UI.T_BODY)
		t.set_constant("h_separation", type, 8)
		_font_cols(t, type, UI.INK, Color.WHITE, UI.FAINT)
	t.set_color("font_pressed_color", "Button", UI.ACCENT_HI)

static func _primary_and_danger(t: Theme) -> void:
	var a := UI.ACCENT
	var pressed := _wide(slab(a.darkened(0.15), Color(0, 0, 0, 0), true))
	_states(t, "Primary", _wide(slab(a)), _wide(slab(a.lightened(0.14))), pressed, _wide(slab(Color(a, 0.3))))
	_font_cols(t, "Primary", UI.DARK_INK, UI.DARK_INK, Color(UI.DARK_INK, 0.55))
	var bad := UI.BAD
	_states(t, "Danger", slab(bad.darkened(0.66), Color(bad, 0.6)), slab(bad.darkened(0.5), Color(bad, 0.95)),
		slab(bad.darkened(0.6), bad, true), slab(Color(bad.darkened(0.7), 0.5)))
	_font_cols(t, "Danger", Color("ffc2b8"), Color.WHITE, UI.FAINT)
	# the picked option in a row of choices: an accent-tinted slab with an accent edge
	var tint := UI.RAISED.lerp(a, 0.16)
	_states(t, "Chosen", slab(tint, Color(a, 0.75)), slab(tint.lightened(0.06), a), slab(tint.darkened(0.15), a, true),
		slab(Color(tint, 0.6), Color(a, 0.3)))
	_font_cols(t, "Chosen", UI.ACCENT_HI, Color.WHITE, Color(UI.ACCENT_HI, 0.5))
	for type in ["Primary", "Danger", "Chosen"]:
		t.set_stylebox("focus", type, ring())

## The primary button's wider face.
static func _wide(f: UiFrame) -> UiFrame:
	f.content_margin_left = 24.0
	f.content_margin_right = 24.0
	return f

## Text-only buttons (small or rare actions) and the round icon button (close, back).
static func _quiet_buttons(t: Theme) -> void:
	var none := StyleBoxEmpty.new()
	none.content_margin_left = 12
	none.content_margin_right = 12
	none.content_margin_top = 8
	none.content_margin_bottom = 8
	var gh := UiFrame.raised(Color(1, 1, 1, 0.05), UI.R_CTRL)
	var gp := UiFrame.sunk(Color(0, 0, 0, 0.2), UI.R_CTRL)
	_states(t, "Ghost", none, gh.padded(12, 8), gp.padded(12, 8), none)
	_font_cols(t, "Ghost", UI.MUTED, Color.WHITE, UI.FAINT)
	t.set_stylebox("focus", "Ghost", ring())
	var round_none := StyleBoxEmpty.new()
	round_none.content_margin_left = 8
	round_none.content_margin_right = 8
	round_none.content_margin_top = 8
	round_none.content_margin_bottom = 8
	_states(t, "IconBtn", round_none, UiFrame.raised(Color(1, 1, 1, 0.1), UI.R_PILL).padded(8, 8),
		UiFrame.sunk(Color(0, 0, 0, 0.25), UI.R_PILL).padded(8, 8), round_none)
	_font_cols(t, "IconBtn", UI.MUTED, Color.WHITE, UI.FAINT)
	t.set_stylebox("focus", "IconBtn", ring(UI.R_PILL))

## Segmented tabs (segments in a recessed track, the picked one raised with an accent line) and
## selectable tiles.
static func _tabs_and_tiles(t: Theme) -> void:
	var seg := StyleBoxEmpty.new()
	seg.content_margin_left = 14
	seg.content_margin_right = 14
	seg.content_margin_top = 7
	seg.content_margin_bottom = 7
	var seg_h := UiFrame.sunk(Color(1, 1, 1, 0.06), UI.R_SMALL + 2).padded(14, 7)
	_states(t, "Seg", seg, seg_h, seg_h, seg)
	_font_cols(t, "Seg", UI.MUTED, Color.WHITE, UI.FAINT)
	var on := UiFrame.raised(UI.RAISED.lightened(0.08), UI.R_SMALL + 2)
	on.mark = UI.ACCENT
	on.padded(14, 7)
	_states(t, "SegOn", on, on, on, on)
	_font_cols(t, "SegOn", Color.WHITE, Color.WHITE, UI.FAINT)
	var tile := UiFrame.raised(Color(1, 1, 1, 0.04), UI.R_CARD).padded(10, 10)
	var tile_h := UiFrame.raised(Color(1, 1, 1, 0.08), UI.R_CARD)
	tile_h.edge = Color(1, 1, 1, 0.22)
	tile_h.padded(10, 10)
	var tile_on := UiFrame.raised(Color(UI.ACCENT, 0.14), UI.R_CARD)
	tile_on.edge = Color(UI.ACCENT, 0.9)
	tile_on.edge_w = 2
	tile_on.padded(10, 10)
	_states(t, "Tile", tile, tile_h, tile_h, tile)
	_font_cols(t, "Tile", UI.INK, Color.WHITE, UI.FAINT)
	_states(t, "TileOn", tile_on, tile_on, tile_on, tile_on)
	_font_cols(t, "TileOn", UI.ACCENT_HI, Color.WHITE, UI.FAINT)
	for type in ["Seg", "SegOn"]:
		t.set_stylebox("focus", type, ring(UI.R_SMALL + 4))
	for type in ["Tile", "TileOn"]:
		t.set_stylebox("focus", type, ring(UI.R_CARD + 3))

## The title screen: big menu entries (words until you point at one, then a dark strip with an
## accent line lights under it) and its one call to action, the solid accent button.
static func _front_menu(t: Theme) -> void:
	var item := StyleBoxEmpty.new()
	item.content_margin_left = 20
	item.content_margin_right = 20
	item.content_margin_top = 6
	item.content_margin_bottom = 6
	var item_h := UiFrame.raised(Color(UI.NIGHT, 0.86), UI.R_CTRL)
	item_h.mark = UI.ACCENT
	item_h.content_margin_left = 28
	item_h.content_margin_right = 20
	item_h.content_margin_top = 6
	item_h.content_margin_bottom = 6
	var item_p := item_h.duplicate() as UiFrame
	item_p.fill = Color(UI.NIGHT_HI, 0.9)
	_states(t, "MenuItem", item, item_h, item_p, item)
	t.set_stylebox("focus", "MenuItem", StyleBoxEmpty.new())
	t.set_font("font", "MenuItem", UI.big)
	t.set_font_size("font_size", "MenuItem", 25)
	_font_cols(t, "MenuItem", Color(UI.INK, 0.8), Color.WHITE, Color(UI.INK, 0.3))
	t.set_color("font_focus_color", "MenuItem", Color.WHITE)
	t.set_color("font_pressed_color", "MenuItem", UI.ACCENT_HI)
	t.set_constant("outline_size", "MenuItem", 6)
	t.set_color("font_outline_color", "MenuItem", Color(0.05, 0.03, 0.1, 0.55))
	t.set_constant("h_separation", "MenuItem", 12)
	var main_n := _menu_main(UI.ACCENT, false)
	var main_h := _menu_main(UI.ACCENT.lightened(0.14), false)
	_states(t, "MenuMain", main_n, main_h, _menu_main(UI.ACCENT.darkened(0.15), true), main_n)
	var main_f := ring(UI.R_CTRL + 4)
	main_f.expand_margin_left = 4
	main_f.expand_margin_right = 4
	main_f.expand_margin_top = 4
	main_f.expand_margin_bottom = 4
	t.set_stylebox("focus", "MenuMain", main_f)
	t.set_font("font", "MenuMain", UI.big)
	t.set_font_size("font_size", "MenuMain", 28)
	_font_cols(t, "MenuMain", UI.DARK_INK, UI.DARK_INK, Color(UI.DARK_INK, 0.5))
	t.set_constant("h_separation", "MenuMain", 12)

static func _menu_main(fill: Color, down: bool) -> UiFrame:
	var f := slab(fill, Color(0, 0, 0, 0), down)
	f.shadow = 14
	f.content_margin_left = 34
	f.content_margin_right = 38
	f.content_margin_top += 5.0
	f.content_margin_bottom += 5.0
	return f

## Text boxes, labels, drop-down lists, tooltips and separators.
static func _inputs(t: Theme) -> void:
	var le := UiFrame.sunk(UI.WELL, UI.R_CTRL).padded(12, 9)
	le.rim = Color(1, 1, 1, 0.08)
	var lf := UiFrame.sunk(UI.WELL, UI.R_CTRL).padded(12, 9)
	lf.edge = Color(UI.ACCENT, 0.9)
	lf.edge_w = 2
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", lf)
	t.set_color("font_placeholder_color", "LineEdit", UI.FAINT)
	t.set_color("caret_color", "LineEdit", UI.ACCENT)
	t.set_color("selection_color", "LineEdit", Color(UI.ACCENT, 0.35))
	t.set_color("font_color", "Label", UI.INK)
	var pm := UiFrame.raised(UI.SURFACE.lightened(0.04), UI.R_CARD, 14, UI.RIM)
	pm.edge = UI.LINE
	t.set_stylebox("panel", "PopupMenu", pm.padded(8, 8))
	t.set_stylebox("hover", "PopupMenu", UiFrame.raised(Color(UI.ACCENT, 0.24), UI.R_SMALL))
	t.set_color("font_color", "PopupMenu", UI.INK)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_font_size("font_size", "PopupMenu", UI.T_BODY)
	t.set_constant("v_separation", "PopupMenu", 8)
	var tp := UiFrame.raised(UI.SURFACE.lightened(0.02), UI.R_CTRL, 10, UI.RIM)
	tp.edge = UI.LINE
	tp.padded(12, 8)
	t.set_stylebox("panel", "TooltipPanel", tp)
	t.set_color("font_color", "TooltipLabel", UI.INK)
	t.set_font_size("font_size", "TooltipLabel", UI.T_SMALL)
	t.set_stylebox("separator", "HSeparator", UiFrame._flat(UI.LINE, 1))
	t.set_constant("separation", "HSeparator", 6)

## Panels: an ink-navy sheet with a hairline rim and a deep soft shadow. Scroll bars stay thin and
## quiet; progress bars are a recess with a lit fill.
static func _panels(t: Theme) -> void:
	var pc := UiFrame.raised(UI.SURFACE, UI.R_PANEL, 34, UI.RIM)
	pc.edge = Color(1, 1, 1, 0.1)
	pc.padded(UI.PAD, 22)
	t.set_stylebox("panel", "PanelContainer", pc)
	for sb_t in ["VScrollBar", "HScrollBar"]:
		var gr := UiFrame._flat(Color(UI.INK, 0.22), 4)
		gr.content_margin_left = 3
		gr.content_margin_right = 3
		t.set_stylebox("grabber", sb_t, gr)
		t.set_stylebox("grabber_highlight", sb_t, UiFrame._flat(Color(UI.INK, 0.4), 4))
		t.set_stylebox("grabber_pressed", sb_t, UiFrame._flat(Color(UI.ACCENT, 0.6), 4))
		var tr := UiFrame._flat(Color(0, 0, 0, 0.14), 4)
		tr.content_margin_left = 3
		tr.content_margin_right = 3
		t.set_stylebox("scroll", sb_t, tr)
	var pbg := UiFrame.sunk(UI.WELL, 5)
	pbg.content_margin_top = 4
	pbg.content_margin_bottom = 4
	t.set_stylebox("background", "ProgressBar", pbg)
	var pfill := UiFrame.raised(UI.ACCENT, 5)
	pfill.lit = 0.25
	t.set_stylebox("fill", "ProgressBar", pfill)

## Sliders (a recessed track, a lit accent fill, a cream knob with a ring) and the on/off switch.
static func _toggles_and_sliders(t: Theme) -> void:
	var sl := UiFrame.sunk(Color(0, 0, 0, 0.4), 4)
	sl.content_margin_top = 3
	sl.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", sl)
	var ga := UiFrame.raised(UI.ACCENT.darkened(0.05), 4)
	ga.lit = 0.3
	ga.content_margin_top = 3
	ga.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", ga)
	t.set_stylebox("grabber_area_highlight", "HSlider", ga)
	t.set_stylebox("focus", "HSlider", ring(8))
	t.set_icon("grabber", "HSlider", _knob(20, Color("fff7e8"), UI.ACCENT))
	t.set_icon("grabber_highlight", "HSlider", _knob(20, Color.WHITE, UI.ACCENT_HI))
	t.set_icon("grabber_disabled", "HSlider", _knob(20, Color("8a8590"), Color("5a5560")))
	t.set_icon("checked", "CheckButton", _switch(true))
	t.set_icon("unchecked", "CheckButton", _switch(false))
	t.set_icon("checked_disabled", "CheckButton", _switch(true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch(false, true))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckButton", empty)
	t.set_stylebox("focus", "CheckButton", ring(14))
	t.set_font("font", "CheckButton", UI.body)
	t.set_font_size("font_size", "CheckButton", UI.T_BODY)
	_font_cols(t, "CheckButton", UI.INK, Color.WHITE, UI.FAINT)
	t.set_color("font_pressed_color", "CheckButton", UI.INK)

## A slider knob: a cream disc with a coloured ring and a soft shadow under it.
static func _knob(d: int, col: Color, ring_col: Color) -> ImageTexture:
	var img := Image.create(d, d + 2, false, Image.FORMAT_RGBA8)
	var c := Vector2((d - 1) * 0.5, (d - 1) * 0.5)
	var r := d * 0.5 - 1.0
	for y in d + 2:
		for x in d:
			var p := Vector2(x, y)
			var shade := clampf(r + 1.5 - p.distance_to(c + Vector2(0, 1.6)), 0.0, 1.5) / 1.5 * 0.35
			var px := Color(0, 0, 0, shade)
			var dist := p.distance_to(c)
			var cover := clampf(r - dist + 0.5, 0.0, 1.0)
			if cover > 0.0:
				var face_col := col.lerp(Color.WHITE, clampf((c.y - y) / r, 0.0, 1.0) * 0.4)
				if dist > r - 2.6:
					face_col = ring_col
				px = px.blend(Color(face_col, cover))
			img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)

## The on/off switch: a recessed capsule (accent and lit when on) and a knob that sits on it.
static func _switch(on: bool, off_state := false) -> ImageTexture:
	var w := 46
	var h := 26
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := UI.ACCENT if on else Color(0.2, 0.18, 0.24)
	var knob := Color("fff7e8") if on else Color("cfcad4")
	var mid := (h - 1) * 0.5
	var kr := 8.5
	var kx := (w - 13.0) if on else 12.0
	var fade := 0.45 if off_state else 1.0
	for y in h:
		for x in w:
			var cx := clampf(float(x), mid, w - 1 - mid)
			var d_track := Vector2(x - cx, y - mid).length()
			var cover := clampf(mid - d_track + 0.5, 0.0, 1.0)
			# the track: shade along its top inside edge, a lighter floor
			var depth := clampf((float(y) - 2.0) / 6.0, 0.0, 1.0)
			var px := Color(track.darkened(0.35 * (1.0 - depth)), cover)
			var shadow := clampf(kr + 1.6 - Vector2(x - kx, y - mid - 1.4).length(), 0.0, 1.6) / 1.6 * 0.4
			px = px.blend(Color(0, 0, 0, shadow * cover))
			var dk := Vector2(x - kx, y - mid).length()
			var kc := clampf(kr - dk + 0.5, 0.0, 1.0)
			if kc > 0.0:
				var lit := clampf((mid - float(y)) / kr, 0.0, 1.0) * 0.5
				px = px.blend(Color(knob.lerp(Color.WHITE, lit), kc))
			img.set_pixel(x, y, Color(px, px.a * fade))
	return ImageTexture.create_from_image(img)
