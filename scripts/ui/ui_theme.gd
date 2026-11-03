class_name UiTheme
extends RefCounted
## Builds the menus' Theme from UI's colour and size tokens and UiFrame boxes, in the field-kit
## look: panels of tooled leather with a stitched seam and brass corner guards, tan leather buttons
## with a brass trim standing on a lip, an amber primary, recessed wells and tracks, a bone knob.
## UI.install() merges it into the engine's default theme once at startup, so every Control in the
## game (menus, popups, tooltips) gets this look without a screen setting it. docs/UI_DESIGN.md.

const LIP := 3                 # px of the darker face under raised buttons
const PRIMARY_LIP := 4
const KNOB_X0 := 13.0          # px from a switch track's end to its knob's centre
const SWITCH := Vector2i(48, 26)

static var _knobs := {}        # disabled? -> the switch knob texture

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

## The panel frame: saddle leather, grain, a burnished edge, a stitched seam, brass corner guards,
## a long soft shadow. `tint` colours the light along its top (the panel's section colour).
static func panel_frame(tint := Color(1.0, 0.96, 0.88)) -> UiFrame:
	var pc := UiFrame.raised(UI.SURFACE, UI.R_PANEL, 34, UI.RIM).leather(UI.STITCH, 0.06, 8.0)
	pc.lit = 0.1
	pc.tint = tint
	pc.trim = Color(UI.BRASS, 0.22)
	pc.guards = UI.BRASS
	return pc.padded(UI.PAD, 24)

## The focus ring: a warm outline just outside the control with a glow inside it (keyboard and pad
## only).
static func ring(rad := UI.R_CTRL + 3) -> UiFrame:
	var f := UiFrame.raised(Color(0, 0, 0, 0), rad)
	f.lit = 0.0
	f.edge = Color(UI.ACCENT_HI, 0.95)
	f.edge_w = 2
	f.glow = Color(UI.ACCENT, 0.22)
	f.grow = 3.0
	return f

## A raised button face with its lip; `down` is the pressed face (sunk onto the lip, the label
## moving with it, so the button's size never changes).
static func face(fill: Color, edge := Color(0, 0, 0, 0), lip := LIP, down := false, lit := 0.1) -> UiFrame:
	var f := UiFrame.raised(fill, UI.R_CTRL, 0, UI.RIM)
	f.edge = edge
	f.lip = lip
	f.pressed = down
	f.lit = lit
	f.grain = 0.05
	var sink := float(lip - 1) if down else 0.0
	f.padded(18, 8)
	f.content_margin_top = 8.0 + sink
	f.content_margin_bottom = 8.0 + float(lip) - sink
	return f

## A face with a brass trim inside its rim and, when lit, a warm inner glow (hover).
static func trimmed(fill: Color, brass_a: float, glow_a := 0.0, lip := LIP, down := false) -> UiFrame:
	var f := face(fill, Color(0, 0, 0, 0), lip, down)
	f.trim = Color(UI.BRASS, brass_a)
	f.glow = Color(UI.BRASS_HI, glow_a)
	return f

static func _states(t: Theme, type: String, n: StyleBox, h: StyleBox, p: StyleBox, d: StyleBox) -> void:
	if not ClassDB.class_exists(type):
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

## The plain Button is the secondary tier: a tan leather slab with a brass trim, so the one amber
## (primary) button on a screen is obviously the thing to press. OptionButton shares it.
static func _buttons(t: Theme) -> void:
	var n := trimmed(UI.RAISED, 0.32)
	var h := trimmed(UI.RAISED.lightened(0.07), 0.7, 0.14)
	var p := trimmed(UI.RAISED.darkened(0.12), 0.5, 0.0, LIP, true)
	var d := face(Color(UI.RAISED, 0.45), Color(0, 0, 0, 0), LIP, false, 0.0)
	for type in ["Button", "OptionButton"]:
		_states(t, type, n, h, p, d)
		t.set_stylebox("focus", type, ring())
		t.set_font("font", type, UI.semi)
		t.set_font_size("font_size", type, UI.T_LABEL)
		t.set_constant("h_separation", type, 8)
		_font_cols(t, type, UI.INK, Color.WHITE, Color(UI.FAINT, 0.7))
	t.set_color("font_pressed_color", "Button", UI.ACCENT_HI)
	t.set_icon("arrow", "OptionButton", _arrow())

static func _primary_and_danger(t: Theme) -> void:
	var a := UI.ACCENT
	var thread := Color(0.42, 0.2, 0.04, 0.55)
	var faces: Array[UiFrame] = [face(a, Color(0, 0, 0, 0), PRIMARY_LIP, false, 0.26),
		face(a.lightened(0.1), Color(0, 0, 0, 0), PRIMARY_LIP, false, 0.3),
		face(a.darkened(0.06), Color(0, 0, 0, 0), PRIMARY_LIP, true, 0.14),
		face(Color(a.darkened(0.5), 0.6), Color(0, 0, 0, 0), PRIMARY_LIP, false, 0.0)]
	for i in 3:
		faces[i].leather(thread, 0.06, 4.0)
		faces[i].burnish = 0.0
		faces[i].trim = Color(1, 0.92, 0.72, 0.45)
	faces[1].glow = Color(1, 0.97, 0.85, 0.3)
	_states(t, "Primary", faces[0], faces[1], faces[2], faces[3])
	_font_cols(t, "Primary", UI.DARK_INK, UI.DARK_INK, Color(1, 1, 1, 0.4))
	var bad := UI.BAD
	_states(t, "Danger", face(bad.darkened(0.64), Color(bad, 0.55)),
		face(bad.darkened(0.5), Color(bad, 0.95)),
		face(bad.darkened(0.58), bad, LIP, true),
		face(Color(bad.darkened(0.7), 0.5), Color(0, 0, 0, 0), LIP, false, 0.0))
	_font_cols(t, "Danger", Color("ffcabf"), Color.WHITE, Color(UI.FAINT, 0.7))
	# the picked option in a row of choices: darker leather with a full brass edge
	_states(t, "Chosen", face(UI.RAISED.darkened(0.2), Color(UI.BRASS, 0.95)),
		face(UI.RAISED.darkened(0.1), UI.BRASS_HI),
		face(UI.RAISED.darkened(0.3), UI.BRASS, LIP, true),
		face(Color(UI.RAISED, 0.4), Color(UI.BRASS, 0.3)))
	_font_cols(t, "Chosen", UI.ACCENT_HI, Color("ffe6c2"), Color(UI.ACCENT_HI, 0.5))
	for type in ["Primary", "Danger", "Chosen"]:
		t.set_stylebox("focus", type, ring())
		t.set_font("font", type, UI.semi)

## Text-only buttons (small or rare actions) and the round brass-trimmed icon button (close, back).
static func _quiet_buttons(t: Theme) -> void:
	var none := StyleBoxEmpty.new()
	none.content_margin_left = 12
	none.content_margin_right = 12
	none.content_margin_top = 8
	none.content_margin_bottom = 8
	_states(t, "Ghost", none, UiFrame.sunk(Color(1, 0.9, 0.75, 0.07), UI.R_CTRL).padded(12, 8),
		UiFrame.sunk(Color(0, 0, 0, 0.22), UI.R_CTRL).padded(12, 8), none)
	_font_cols(t, "Ghost", UI.MUTED, Color.WHITE, Color(UI.FAINT, 0.7))
	t.set_stylebox("focus", "Ghost", ring())
	var round_n := UiFrame.raised(UI.RAISED.darkened(0.15), UI.R_PILL, 0, UI.RIM)
	round_n.trim = Color(UI.BRASS, 0.55)
	var round_h := round_n.duplicate() as UiFrame
	round_h.fill = UI.RAISED.lightened(0.05)
	round_h.trim = UI.BRASS_HI
	round_h.glow = Color(UI.BRASS_HI, 0.18)
	var round_p := UiFrame.sunk(Color(0, 0, 0, 0.3), UI.R_PILL)
	round_p.trim = Color(UI.BRASS, 0.6)
	_states(t, "IconBtn", round_n.padded(8, 8), round_h.padded(8, 8), round_p.padded(8, 8), StyleBoxEmpty.new())
	_font_cols(t, "IconBtn", UI.BRASS_HI, Color.WHITE, Color(UI.FAINT, 0.7))
	t.set_stylebox("focus", "IconBtn", ring(UI.R_PILL))

## Segmented tabs (segments in a recessed track, the picked one raised leather with a brass trim;
## UiMotion.glide draws its underline in the section colour) and selectable tiles.
static func _tabs_and_tiles(t: Theme) -> void:
	var seg := StyleBoxEmpty.new()
	seg.content_margin_left = 14
	seg.content_margin_right = 14
	seg.content_margin_top = 8
	seg.content_margin_bottom = 9
	var seg_h := UiFrame.sunk(Color(1, 0.9, 0.75, 0.07), UI.R_SMALL + 2).padded(14, 8)
	seg_h.content_margin_bottom = 9
	_states(t, "Seg", seg, seg_h, seg_h, seg)
	_font_cols(t, "Seg", UI.MUTED, Color.WHITE, Color(UI.FAINT, 0.7))
	var on := UiFrame.raised(UI.RAISED, UI.R_SMALL + 2, 4, UI.RIM)
	on.lit = 0.12
	on.grain = 0.05
	on.trim = Color(UI.BRASS, 0.45)
	on.padded(14, 8)
	on.content_margin_bottom = 9
	_states(t, "SegOn", on, on, on, on)
	_font_cols(t, "SegOn", Color.WHITE, Color.WHITE, Color(UI.FAINT, 0.7))
	for type in ["Seg", "SegOn"]:
		t.set_font("font", type, UI.semi)
		t.set_stylebox("focus", type, ring(UI.R_SMALL + 4))
	_states(t, "Tile", UI.tile_face(false, false, UI.ACCENT, 10), UI.tile_face(false, true, UI.ACCENT, 10),
		UI.tile_face(false, true, UI.ACCENT, 10), UI.tile_face(false, false, UI.ACCENT, 10))
	_font_cols(t, "Tile", UI.INK, Color.WHITE, Color(UI.FAINT, 0.7))
	var tile_on := UI.tile_face(true, false, UI.ACCENT, 10)
	_states(t, "TileOn", tile_on, tile_on, tile_on, tile_on)
	_font_cols(t, "TileOn", UI.ACCENT_HI, Color.WHITE, Color(UI.FAINT, 0.7))
	for type in ["Tile", "TileOn"]:
		t.set_stylebox("focus", type, ring(UI.R_CARD + 3))

## The title screen: big menu entries (words until you point at one, then a leather strap with a
## brass trim and a stitched seam lies under it) and its one call to action.
static func _front_menu(t: Theme) -> void:
	var item := StyleBoxEmpty.new()
	item.content_margin_left = 20
	item.content_margin_right = 20
	item.content_margin_top = 7
	item.content_margin_bottom = 7
	var item_h := UiFrame.raised(Color(UI.RAISED, 0.94), UI.R_CTRL, 8, UI.RIM).leather(UI.STITCH, 0.07, 4.0)
	item_h.trim = Color(UI.BRASS, 0.5)
	item_h.burnish = 0.0
	item_h.mark = UI.ACCENT
	item_h.padded(28, 7)
	item_h.content_margin_right = 20
	var item_p := item_h.duplicate() as UiFrame
	item_p.fill = UI.RAISED.darkened(0.15)
	_states(t, "MenuItem", item, item_h, item_p, item)
	t.set_stylebox("focus", "MenuItem", StyleBoxEmpty.new())
	t.set_font("font", "MenuItem", UI.big)
	t.set_font_size("font_size", "MenuItem", 25)
	_font_cols(t, "MenuItem", Color(UI.INK, 0.85), Color.WHITE, Color(UI.INK, 0.3))
	t.set_color("font_focus_color", "MenuItem", Color.WHITE)
	t.set_color("font_pressed_color", "MenuItem", UI.ACCENT_HI)
	t.set_constant("outline_size", "MenuItem", 6)
	t.set_color("font_outline_color", "MenuItem", Color(0.08, 0.03, 0.0, 0.6))
	t.set_constant("h_separation", "MenuItem", 12)
	var a := UI.ACCENT
	var main_n := _menu_main(a, 0.26, false)
	var main_h := _menu_main(a.lightened(0.1), 0.3, false)
	main_h.glow = Color(1, 0.97, 0.85, 0.3)
	_states(t, "MenuMain", main_n, main_h, _menu_main(a.darkened(0.06), 0.14, true), main_n)
	var main_f := ring(17)
	main_f.edge = Color(1, 0.95, 0.85, 0.9)
	main_f.grow = 4.0
	t.set_stylebox("focus", "MenuMain", main_f)
	t.set_font("font", "MenuMain", UI.big)
	t.set_font_size("font_size", "MenuMain", 28)
	_font_cols(t, "MenuMain", UI.DARK_INK, UI.DARK_INK, Color(UI.DARK_INK, 0.5))
	t.set_constant("h_separation", "MenuMain", 12)

static func _menu_main(fill: Color, lit: float, down: bool) -> UiFrame:
	var f := face(fill, Color(0, 0, 0, 0), 5, down, lit)
	f.leather(Color(0.42, 0.2, 0.04, 0.55), 0.06, 5.0)
	f.burnish = 0.0
	f.trim = Color(1, 0.92, 0.72, 0.5)
	f.rad = 14
	f.shadow = 14
	f.content_margin_left = 30
	f.content_margin_right = 34
	f.content_margin_top += 3.0
	f.content_margin_bottom += 3.0
	return f

## Text boxes, labels, drop-down lists, tooltips and separators.
static func _inputs(t: Theme) -> void:
	var le := UiFrame.sunk(UI.WELL, UI.R_CTRL).padded(12, 9)
	le.rim = Color(1, 0.9, 0.75, 0.1)
	var lf := le.duplicate() as UiFrame
	lf.edge = Color(UI.ACCENT, 0.9)
	lf.edge_w = 2
	lf.glow = Color(UI.ACCENT, 0.16)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", lf)
	t.set_color("font_placeholder_color", "LineEdit", UI.FAINT)
	t.set_color("caret_color", "LineEdit", UI.ACCENT)
	t.set_color("selection_color", "LineEdit", Color(UI.ACCENT, 0.35))
	t.set_color("font_color", "Label", UI.INK)
	var pm := UiFrame.raised(UI.CARD, UI.R_CARD, 14, UI.RIM).leather(UI.STITCH, 0.06, 5.0).padded(8, 8)
	pm.trim = Color(UI.BRASS, 0.3)
	t.set_stylebox("panel", "PopupMenu", pm)
	var pm_h := UiFrame.raised(Color(UI.ACCENT, 0.26), UI.R_SMALL)
	pm_h.edge = Color(UI.ACCENT, 0.5)
	t.set_stylebox("hover", "PopupMenu", pm_h)
	t.set_color("font_color", "PopupMenu", UI.INK)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_font_size("font_size", "PopupMenu", UI.T_BODY)
	t.set_constant("v_separation", "PopupMenu", 8)
	var tp := UiFrame.raised(UI.CARD, UI.R_CTRL, 12, UI.RIM)
	tp.trim = Color(UI.BRASS, 0.5)
	tp.grain = 0.05
	tp.padded(12, 8)
	t.set_stylebox("panel", "TooltipPanel", tp)
	t.set_color("font_color", "TooltipLabel", UI.INK)
	t.set_font_size("font_size", "TooltipLabel", UI.T_SMALL)
	t.set_stylebox("separator", "HSeparator", UiFrame._flat(UI.LINE, 1))
	t.set_constant("separation", "HSeparator", 6)

## Panels (panel_frame), scroll bars (a brass grabber in a recess) and progress bars (a recess with
## a lit amber fill).
static func _panels(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", panel_frame())
	for sb_t in ["VScrollBar", "HScrollBar"]:
		var gr := UiFrame._flat(Color(UI.BRASS, 0.42), 4)
		gr.content_margin_left = 3
		gr.content_margin_right = 3
		t.set_stylebox("grabber", sb_t, gr)
		t.set_stylebox("grabber_highlight", sb_t, UiFrame._flat(Color(UI.BRASS_HI, 0.65), 4))
		t.set_stylebox("grabber_pressed", sb_t, UiFrame._flat(UI.ACCENT, 4))
		var tr := UiFrame._flat(Color(0, 0, 0, 0.2), 4)
		tr.content_margin_left = 3
		tr.content_margin_right = 3
		t.set_stylebox("scroll", sb_t, tr)
	var pbg := UiFrame.sunk(UI.WELL, 5)
	pbg.content_margin_top = 4
	pbg.content_margin_bottom = 4
	t.set_stylebox("background", "ProgressBar", pbg)
	var pfill := UiFrame.raised(UI.ACCENT, 5)
	pfill.lit = 0.3
	t.set_stylebox("fill", "ProgressBar", pfill)

## Sliders (a recessed track, a lit amber fill, a bone knob with a brass ring) and the on/off
## switch (its track here; UiMotion.knob draws the knob so it can ease across).
static func _toggles_and_sliders(t: Theme) -> void:
	var sl := UiFrame.sunk(Color(0.05, 0.02, 0.0, 0.5), 4)
	sl.content_margin_top = 3
	sl.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", sl)
	var ga := UiFrame.raised(UI.ACCENT.darkened(0.05), 4)
	ga.lit = 0.32
	ga.content_margin_top = 3
	ga.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", ga)
	t.set_stylebox("grabber_area_highlight", "HSlider", ga)
	t.set_stylebox("focus", "HSlider", ring(8))
	t.set_icon("grabber", "HSlider", _disc(22, Color("fbf0dc"), UI.BRASS))
	t.set_icon("grabber_highlight", "HSlider", _disc(22, Color.WHITE, UI.BRASS_HI))
	t.set_icon("grabber_disabled", "HSlider", _disc(22, Color("8a8072"), Color("5a5046")))
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
	_font_cols(t, "CheckButton", UI.INK, Color.WHITE, Color(UI.FAINT, 0.7))
	t.set_color("font_pressed_color", "CheckButton", UI.INK)

## The switch's knob (bone with a brass ring), drawn by UiMotion.knob.
static func knob_tex(disabled := false) -> ImageTexture:
	if not _knobs.has(disabled):
		var ring_col := Color("5a5046") if disabled else UI.BRASS
		_knobs[disabled] = _disc(20, Color("cfc6b8") if disabled else Color("fbf0dc"), ring_col)
	return _knobs[disabled]

## A round knob: a bone disc lit from the top, a coloured ring and a soft shadow under it.
static func _disc(d: int, col: Color, ring_col: Color) -> ImageTexture:
	var img := Image.create(d, d + 2, false, Image.FORMAT_RGBA8)
	var c := Vector2((d - 1) * 0.5, (d - 1) * 0.5)
	var r := d * 0.5 - 1.0
	for y in d + 2:
		for x in d:
			var p := Vector2(x, y)
			var shade := clampf(r + 1.5 - p.distance_to(c + Vector2(0, 1.6)), 0.0, 1.5) / 1.5 * 0.4
			var px := Color(0.03, 0.01, 0, shade)
			var dist := p.distance_to(c)
			var cover := clampf(r - dist + 0.5, 0.0, 1.0)
			if cover > 0.0:
				var face_col := col.lerp(Color.WHITE, clampf((c.y - y) / r, 0.0, 1.0) * 0.4)
				if dist > r - 2.4:
					face_col = ring_col.lerp(Color.WHITE, clampf((c.y - y) / r, 0.0, 1.0) * 0.3)
				px = px.blend(Color(face_col, cover))
			img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)

## The switch's track: a recessed capsule, amber and lit when on (the knob is drawn over it).
static func _switch(on: bool, off_state := false) -> ImageTexture:
	var w := SWITCH.x
	var h := SWITCH.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := UI.ACCENT if on else Color(0.12, 0.07, 0.04)
	var mid := (h - 1) * 0.5
	var fade := 0.45 if off_state else 1.0
	for y in h:
		for x in w:
			var cx := clampf(float(x), mid, w - 1 - mid)
			var d_track := Vector2(x - cx, y - mid).length()
			var cover := clampf(mid - d_track + 0.5, 0.0, 1.0)
			var depth := clampf((float(y) - 2.0) / 7.0, 0.0, 1.0)
			var px := Color(track.darkened(0.4 * (1.0 - depth)), cover)
			if d_track > mid - 1.4:
				px = Color(UI.BRASS.darkened(0.25 if on else 0.5), cover)
			img.set_pixel(x, y, Color(px, px.a * fade))
	return ImageTexture.create_from_image(img)

## The drop-down arrow: a small brass chevron.
static func _arrow() -> ImageTexture:
	var img := Image.create(14, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 14:
			var dist := absf(float(y) - 2.0 - (5.0 - absf(float(x) - 6.5)) * 0.95)
			img.set_pixel(x, y, Color(UI.BRASS_HI, clampf(1.6 - dist, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
