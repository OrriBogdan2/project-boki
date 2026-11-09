class_name UI
## The menu kit. Every screen builds its menus in code from these helpers, so they share one look:
## colour roles, corner radii, a type scale, three button tiers, layered cards and panels
## (UiFrame), segmented tabs, chips, keycaps, the panel shell (title, close X, tabs, body, footer),
## confirm boxes, toasts and a blurred backdrop for modals. The Theme itself is UiTheme; install()
## makes it every Control's default. docs/UI_DESIGN.md has the rules and the full API.
## The in-match HUD (HudStyle) shares these colour and font tokens.

# ---------------------------------------------------------------- colour roles
const INK := Color("f3eee2")                        # text
const MUTED := Color("a9b0bf")                      # secondary text
const FAINT := Color(0.66, 0.69, 0.78, 0.55)        # hints, disabled
const BG := Color("110f17")                         # full-screen menu background
const SURFACE := Color(0.094, 0.082, 0.118, 0.98)   # panels: a warm night, not a cold navy
const CARD := Color(0.158, 0.142, 0.19, 1.0)        # a card raised off a panel
const RAISED := Color(0.2, 0.18, 0.235)             # button and tab faces
const RIM := Color(0.0, 0.0, 0.02, 0.6)             # the dark outer edge of every raised box
const WELL := Color(0, 0, 0, 0.24)                  # a recess: tab tracks, bars, inputs
const LINE := Color(1, 1, 1, 0.08)                  # hairlines
const ACCENT := Color("f2a24a")                     # the one action colour: primary buttons, focus, picked tabs
const ACCENT_HI := Color("ffd79a")                  # accent text on dark
const GOOD := Color("8fe0a0")                       # success, owned, ready
const BAD := Color("ff6a5a")                        # danger, loss, locked
const GOLD := Color("f2c84a")                       # currency (gems) and rewards
const TEAL := Color("8fe3c8")                       # info, extraction, the portal
const INFO := Color("7cc4ff")
const DARK_INK := Color(0.13, 0.08, 0.05)           # text on accent fills

# ---------------------------------------------------------------- corner radii (px at 720p)
const R_PANEL := 18      # panels and modals
const R_CARD := 12       # cards, tiles, drop-down lists
const R_CTRL := 10       # buttons, inputs, tooltips
const R_SMALL := 6       # tags, tab segments, keycaps
const R_PILL := 999      # chips and round buttons

# ---------------------------------------------------------------- type scale
const T_TITLE := 30      # one per panel (Lilita One)
const T_HEAD := 19       # card titles, item names (Lilita One)
const T_BODY := 15       # everything you read (Rubik)
const T_SMALL := 13      # secondary lines and hints (Rubik)
const T_CAPS := 12       # section eyebrows (Rubik bold, spaced)
# ---------------------------------------------------------------- spacing
const GAP := 12          # between things in a group
const GAP_BIG := 20      # between groups
const PAD := 26          # inside a panel

static var big: Font = preload("res://fonts/LilitaOne-Regular.ttf")
static var body: Font = preload("res://fonts/Rubik.ttf")
static var _theme: Theme
static var semi: FontVariation       # Rubik at a heavier weight, for buttons and small headers
static var caps: FontVariation       # spaced-out bold, for section headers

static func rarity_col(r: int) -> Color:
	return Data.RARITY[clampi(r, 0, Data.RARITY.size() - 1)]["color"]

## The menus' Theme (built once by UiTheme).
static func theme() -> Theme:
	if _theme:
		return _theme
	semi = FontVariation.new()
	semi.base_font = body
	semi.variation_opentype = {"wght": 560}
	caps = FontVariation.new()
	caps.base_font = body
	caps.variation_opentype = {"wght": 700}
	caps.spacing_glyph = 1
	_theme = UiTheme.build()
	return _theme

## Makes the menu theme every Control's default (merged into the engine's default theme), so no
## screen, popup or tooltip has to set it. Called once at startup.
static func install() -> void:
	ThemeDB.get_default_theme().merge_with(theme())

static func _blank(w: int, h: int) -> ImageTexture:
	var img := Image.create(maxi(1, w), maxi(1, h), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- small pieces

## A key drawn as a little keycap ("F", "Space", "Esc"), so prompts read at a glance instead of as
## letters in brackets.
static func keycap(key: String, size := 13) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiFrame.raised(Color(0.93, 0.9, 0.84, 0.95), R_SMALL - 1)
	sb.lip = 2
	sb.lit = 0.0
	sb.padded(6 if key.length() <= 1 else 7, 1)
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size + 10, size + 7)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = key
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", caps if caps else body)
	l.add_theme_font_size_override("font_size", size - 1 if key.length() > 1 else size)
	l.add_theme_color_override("font_color", Color(0.16, 0.12, 0.14))
	p.add_child(l)
	return p

## A row of "[key] what it does" hints. pairs: [["F", "use"], ["Space", "jump"], ...]; a key string
## with spaces in it ("W S") draws one cap per key.
static func key_hints(pairs: Array, size := 13, col := Color(1, 1, 1, 0.75)) -> HBoxContainer:
	var row := hbox(16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pr in pairs:
		var one := hbox(5)
		one.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in String(pr[0]).split(" "):
			if k != "": one.add_child(keycap(k, size))
		var l := label(String(pr[1]), size + 1, col)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.08, 0.6))
		one.add_child(l)
		row.add_child(one)
	return row

## A small spaced-out heading for a group of things in a menu (the "eyebrow").
static func section(text: String, col := Color("c9a46a")) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", caps if caps else body)
	l.add_theme_font_size_override("font_size", T_CAPS)
	l.add_theme_color_override("font_color", col)
	l.set_meta("pg_head", true)
	return l

static func label(text: String, size := 16, col := INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	# short labels sit on one line; only real sentences wrap (a wrapping label in a row collapses to nothing)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if text.length() > 48 else TextServer.AUTOWRAP_OFF
	return l

## Body text that wraps: the usual muted line under a heading.
static func para(text: String, size := T_SMALL, col := MUTED) -> Label:
	var l := label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func title(text: String, size := 34, col := INK) -> Label:
	var l := label(text, size, col, big)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

# ---------------------------------------------------------------- buttons
## The secondary button (an outline). icon: an Icons id drawn at its left. Hover fills it with the
## theme's hover colour (no growing: a button never spills over its neighbours or the panel edge);
## pressing sinks it a touch, in about 70 ms.
static func button(text: String, cb: Callable, minw := 0.0, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	if cb.is_valid():
		b.pressed.connect(func(): UiSfx.press(text, String(b.get_meta("snd", ""))); cb.call())
	if minw > 0.0:
		b.custom_minimum_size.x = minw
	if icon != "":
		set_icon(b, icon)
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	var to := func(s: float, secs: float) -> void:
		if not is_instance_valid(b) or not b.is_inside_tree(): return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(s, s), secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	b.mouse_entered.connect(func():
		if b.disabled: return
		UiSfx.hover())
	b.mouse_exited.connect(func(): to.call(1.0, 0.11))
	b.button_down.connect(func(): if not b.disabled: to.call(0.97, 0.07))
	b.button_up.connect(func(): to.call(1.0, 0.1))
	b.focus_entered.connect(func():
		# keyboard and pad focus tick and lift like the mouse does
		if not b.is_hovered() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			UiSfx.hover(true))
	b.focus_exited.connect(func(): if not b.is_hovered(): to.call(1.0, 0.11))
	return b

## The main button of a screen: filled accent, dark text. One per screen.
static func primary(text: String, cb: Callable, minw := 0.0, icon := "") -> Button:
	var b := button(text, cb, minw, icon)
	b.set_meta("snd", "ui_confirm")
	b.theme_type_variation = "Primary"
	return b

## A text-only button for small or rare actions.
static func ghost(text: String, cb: Callable, minw := 0.0, icon := "") -> Button:
	var b := button(text, cb, minw, icon)
	b.theme_type_variation = "Ghost"
	return b

## A red-outlined button for things that can't be undone (pair it with confirm()).
static func danger(text: String, cb: Callable, minw := 0.0, icon := "") -> Button:
	var b := button(text, cb, minw, icon)
	b.theme_type_variation = "Danger"
	return b

## One option in a row of choices; the chosen one is lit instead of marked with a symbol.
static func choice(text: String, chosen: bool, cb: Callable, minw := 0.0, icon := "") -> Button:
	var b := button(text, cb, minw, icon)
	if chosen:
		b.theme_type_variation = "Chosen"
	return b

## A round icon-only button (close, back, arrows).
static func icon_button(icon: String, cb: Callable, tip := "", px := 16.0) -> Button:
	var b := button("", cb)
	b.theme_type_variation = "IconBtn"
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(px + 18, px + 18)
	b.draw.connect(func():
		var c := b.get_theme_color("font_hover_color" if b.is_hovered() else "font_color")
		draw_icon(b, icon, b.size * 0.5, px * 0.5, c))
	b.mouse_entered.connect(b.queue_redraw); b.mouse_exited.connect(b.queue_redraw)
	return b

## Draws an Icons glyph at the left of a button's text (keeps room for it with a blank icon).
static func set_icon(b: Button, icon: String, px := 16) -> void:
	b.icon = _blank(px, px)
	b.set_meta("glyph", icon)
	if b.has_meta("glyph_on"):
		b.queue_redraw()
		return
	b.set_meta("glyph_on", true)
	b.draw.connect(func():
		var id := String(b.get_meta("glyph", ""))
		if id == "": return
		var sb := b.get_theme_stylebox("normal")
		var ml := sb.content_margin_left if sb else 16.0
		var mr := sb.content_margin_right if sb else 16.0
		var x := ml
		if b.alignment == HORIZONTAL_ALIGNMENT_CENTER and b.text != "":
			# the icon sits just left of centred text
			var f := b.get_theme_font("font"); var fs := b.get_theme_font_size("font_size")
			var tw := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var gap := float(b.get_theme_constant("h_separation"))
			x = ml + maxf(0.0, (b.size.x - ml - mr - tw - px - gap) * 0.5)
		var col := b.get_theme_color("font_disabled_color" if b.disabled else ("font_hover_color" if b.is_hovered() else "font_color"))
		draw_icon(b, id, Vector2(x + px * 0.5, b.size.y * 0.5), px * 0.5, col))
	b.mouse_entered.connect(b.queue_redraw); b.mouse_exited.connect(b.queue_redraw)

## Draws an icon: one of the Icons ids, or one of the menu's own ("close", "back", "next", "check",
## "lock", "plus", "gear", "home", "bag", "shop", "portal", "hammer", "info").
static func draw_icon(c: CanvasItem, id: String, at: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.8, s * 0.22)
	match id:
		"close":
			c.draw_line(at + Vector2(-s, -s) * 0.62, at + Vector2(s, s) * 0.62, col, w, true)
			c.draw_line(at + Vector2(s, -s) * 0.62, at + Vector2(-s, s) * 0.62, col, w, true)
		"back", "next":
			var d := -1.0 if id == "back" else 1.0
			c.draw_polyline(PackedVector2Array([at + Vector2(0.3 * d * -s, -0.7 * s), at + Vector2(-0.4 * d * -s, 0), at + Vector2(0.3 * d * -s, 0.7 * s)]), col, w, true)
		"check":
			c.draw_polyline(PackedVector2Array([at + Vector2(-0.7, 0.0) * s, at + Vector2(-0.2, 0.5) * s, at + Vector2(0.7, -0.55) * s]), col, w, true)
		"plus":
			c.draw_line(at + Vector2(-0.7, 0) * s, at + Vector2(0.7, 0) * s, col, w, true)
			c.draw_line(at + Vector2(0, -0.7) * s, at + Vector2(0, 0.7) * s, col, w, true)
		"lock":
			c.draw_rect(Rect2(at + Vector2(-0.62, -0.05) * s, Vector2(1.24, 0.9) * s), col)
			c.draw_arc(at + Vector2(0, -0.12) * s, 0.4 * s, PI, TAU, 12, col, w, true)
		"gear":
			c.draw_arc(at, 0.5 * s, 0, TAU, 20, col, w, true)
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_line(at + Vector2(cos(a), sin(a)) * 0.6 * s, at + Vector2(cos(a), sin(a)) * 0.95 * s, col, w * 1.3, true)
			c.draw_circle(at, 0.18 * s, col)
		"home":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -0.85) * s, at + Vector2(0.85, -0.05) * s, at + Vector2(0.6, -0.05) * s, at + Vector2(0.6, 0.75) * s,
				at + Vector2(-0.6, 0.75) * s, at + Vector2(-0.6, -0.05) * s, at + Vector2(-0.85, -0.05) * s]), col)
		"bag":
			c.draw_rect(Rect2(at + Vector2(-0.7, -0.35) * s, Vector2(1.4, 1.1) * s), col)
			c.draw_arc(at + Vector2(0, -0.35) * s, 0.36 * s, PI, TAU, 12, col, w, true)
		"shop":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-0.85, -0.2) * s, at + Vector2(-0.6, -0.75) * s, at + Vector2(0.6, -0.75) * s, at + Vector2(0.85, -0.2) * s]), col)
			c.draw_rect(Rect2(at + Vector2(-0.68, -0.1) * s, Vector2(1.36, 0.85) * s), Color(col, col.a * 0.75))
		"portal":
			c.draw_arc(at, 0.78 * s, 0, TAU, 24, col, w, true)
			c.draw_arc(at, 0.42 * s, 0, TAU, 18, Color(col, col.a * 0.7), w, true)
		"hammer":
			c.draw_line(at + Vector2(-0.6, 0.75) * s, at + Vector2(0.25, -0.15) * s, col, w * 1.4, true)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-0.05, -0.75) * s, at + Vector2(0.75, 0.05) * s, at + Vector2(0.45, 0.35) * s, at + Vector2(-0.35, -0.45) * s]), col)
		"eye":
			c.draw_arc(at + Vector2(0, 0.55) * s, 0.95 * s, -PI * 0.78, -PI * 0.22, 14, col, w, true)
			c.draw_arc(at + Vector2(0, -0.55) * s, 0.95 * s, PI * 0.22, PI * 0.78, 14, col, w, true)
			c.draw_circle(at, 0.28 * s, col)
		"ruler":
			c.draw_line(at + Vector2(-0.85, 0.45) * s, at + Vector2(0.45, -0.85) * s, col, w * 2.2, true)
			for k in 4:
				var p0 := at + Vector2(-0.6 + k * 0.3, 0.2 - k * 0.3) * s
				c.draw_line(p0, p0 + Vector2(0.18, 0.18) * s, Color(0, 0, 0, 0.5), maxf(1.0, w * 0.6), true)
		"pin":
			c.draw_circle(at + Vector2(0, -0.3) * s, 0.5 * s, col)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-0.42, -0.05) * s, at + Vector2(0.42, -0.05) * s, at + Vector2(0, 0.9) * s]), col)
			c.draw_circle(at + Vector2(0, -0.3) * s, 0.2 * s, Color(0, 0, 0, 0.45))
		"female":      # ♀: a ring over a cross
			c.draw_arc(at + Vector2(0, -0.28) * s, 0.46 * s, 0, TAU, 20, col, w, true)
			c.draw_line(at + Vector2(0, 0.18) * s, at + Vector2(0, 0.95) * s, col, w, true)
			c.draw_line(at + Vector2(-0.32, 0.6) * s, at + Vector2(0.32, 0.6) * s, col, w, true)
		"male":        # ♂: a ring with an arrow up and right
			c.draw_arc(at + Vector2(-0.22, 0.22) * s, 0.46 * s, 0, TAU, 20, col, w, true)
			c.draw_line(at + Vector2(0.11, -0.11) * s, at + Vector2(0.78, -0.78) * s, col, w, true)
			c.draw_polyline(PackedVector2Array([at + Vector2(0.28, -0.8) * s, at + Vector2(0.8, -0.8) * s, at + Vector2(0.8, -0.28) * s]), col, w, true)
		"alert":
			c.draw_line(at + Vector2(0, -0.78) * s, at + Vector2(0, 0.22) * s, col, w * 1.5, true)
			c.draw_circle(at + Vector2(0, 0.66) * s, w * 0.85, col)
		"info":
			c.draw_arc(at, 0.85 * s, 0, TAU, 24, col, w, true)
			c.draw_circle(at + Vector2(0, -0.42) * s, 0.12 * s, col)
			c.draw_line(at + Vector2(0, -0.12) * s, at + Vector2(0, 0.5) * s, col, w, true)
		_:
			Icons.draw(c as Control, id, at, s, col)

## Shows a keycap at the right end of a button ("Enter", "Esc", "1"), so the key that does the same
## thing is right there on it.
static func with_key(b: Button, key: String) -> Button:
	var kc := keycap(key, 12)
	b.add_child(kc)
	# make room for the cap on the right of every state's face (once, as the button joins the tree),
	# then park it 10 px in from the right edge
	var room := func() -> void:
		var w := kc.get_combined_minimum_size().x
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb := b.get_theme_stylebox(st)
			if sb == null:
				continue
			var d := sb.duplicate()
			d.content_margin_right = maxf(sb.content_margin_right, 0.0) + w + 10.0
			b.add_theme_stylebox_override(st, d)
	if b.is_inside_tree():
		room.call()
	else:
		b.tree_entered.connect(room, CONNECT_ONE_SHOT)
	var place := func():
		kc.size = kc.get_combined_minimum_size()
		kc.position = Vector2(b.size.x - 10.0 - kc.size.x, (b.size.y - kc.size.y) * 0.5)
	b.resized.connect(place)
	b.tree_entered.connect(func(): place.call_deferred())
	return b

# ---------------------------------------------------------------- tabs, chips, cards
## A segmented control: names in a dark track, the current one lifted. cb gets the picked name.
## counts (optional): name -> a small number shown after it. Arrow keys move along it.
static func tabs(names: Array, cur: String, cb: Callable, counts := {}, minw := 0.0) -> PanelContainer:
	var track := PanelContainer.new()
	track.add_theme_stylebox_override("panel", UiFrame.sunk(WELL, R_SMALL + 5).padded(3, 3))
	track.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := hbox(2)
	track.add_child(row)
	for n in names:
		var nm := String(n)
		var txt := nm
		if counts.has(nm): txt = "%s  %s" % [nm, str(counts[nm])]
		var b := button(txt, func(): if nm != cur: cb.call(nm), minw)
		b.theme_type_variation = "SegOn" if nm == cur else "Seg"
		b.set_meta("snd", "ui_tab")
		b.set_meta("tab", nm)
		row.add_child(b)
	track.set_meta("pg_keep", true)
	return track

## A selectable card (a tier, a skin, an item): lights up on hover and focus, the picked one wears
## an accent edge. Add your content to the returned container. Click, Enter or the pad's A pick it.
static func tile_card(on: bool, cb: Callable, pad := 12, col := ACCENT) -> PanelContainer:
	var p := PanelContainer.new()
	var n := _tile_face(on, false, col, pad)
	var h := _tile_face(on, true, col, pad)
	p.add_theme_stylebox_override("panel", n)
	p.focus_mode = Control.FOCUS_ALL
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.resized.connect(func(): p.pivot_offset = p.size * 0.5)
	var lit := func(yes: bool) -> void:
		p.add_theme_stylebox_override("panel", h if yes else n)
		var tw := p.create_tween()
		tw.tween_property(p, "modulate", Color(1.08, 1.08, 1.08) if yes else Color.WHITE, 0.09).set_trans(Tween.TRANS_SINE)      # a brighter fill, never a bigger card
	p.mouse_entered.connect(func(): Sfx.play("hover", null, -14.0, 0.05); lit.call(true))
	p.mouse_exited.connect(func(): if not p.has_focus(): lit.call(false))
	p.focus_entered.connect(func(): lit.call(true))
	p.focus_exited.connect(func(): if not p.get_global_rect().has_point(p.get_global_mouse_position()): lit.call(false))
	var ring := UiTheme.ring(R_CARD + 3)
	p.draw.connect(func():
		if p.has_focus() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and p.get_viewport() and not p.get_global_rect().has_point(p.get_global_mouse_position()):
			p.draw_style_box(ring, Rect2(Vector2.ZERO, p.size)))
	p.focus_entered.connect(p.queue_redraw); p.focus_exited.connect(p.queue_redraw)
	p.gui_input.connect(func(ev):
		var go: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or ev.is_action_pressed("ui_accept")
		if go and cb.is_valid():
			p.accept_event()
			Sfx.play("click")
			cb.call())
	return p

## A box in the menu look for anything that styles its own control (a tile, a chip, a swatch):
## the layered frame in `bg`, an optional `edge` outline and content padding. Raised boxes catch
## the light from the top; flat ones (lit 0) don't.
static func frame(bg: Color, rad := R_CTRL, edge := Color(0, 0, 0, 0), edge_w := 1, pad_h := 0.0, pad_v := 0.0, lit := 0.05) -> UiFrame:
	var f := UiFrame.raised(bg, rad)
	f.lit = lit
	if edge_w > 0:
		f.edge = edge
		f.edge_w = edge_w
	return f.padded(pad_h, pad_v)

## A selectable card's face: raised, lit when hovered, an edge in `col` when picked.
static func _tile_face(on: bool, hover: bool, col: Color, pad: float) -> UiFrame:
	var tint := col if on else Color.WHITE
	var alpha := 0.13 if on else 0.04
	var fill := Color(tint, alpha + (0.05 if hover else 0.0))
	var f := UiFrame.raised(fill, R_CARD)
	f.edge_w = 2 if on else 1
	if on:
		f.edge = Color(col, 0.9)
	else:
		f.edge = Color(1, 1, 1, 0.24 if hover else 0.06)
	return f.padded(pad, pad)

## A pill: an icon and a value with a tooltip (gems, scrap, stored). col tints it.
static func chip(icon: String, txt: String, col := INK, tip := "", size := 14) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", frame(Color(col, 0.11), R_PILL, Color(col, 0.18), 1, 10, 4, 0.0))
	c.tooltip_text = tip
	c.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := hbox(6); c.add_child(h)
	if icon != "":
		var g := IconDot.new(icon, col, size + 2.0)
		h.add_child(g)
	var l := label(txt, size, INK, semi)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	return c

## A small coloured tag ("Rare", "Equipped", "Locked").
static func tag(txt: String, col: Color) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", frame(Color(col, 0.16), R_SMALL, Color(0, 0, 0, 0), 0, 7, 2, 0.0))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(txt.to_upper(), 11, col.lightened(0.15), caps)
	c.add_child(l)
	return c

## Fades and lifts a panel in, so menus open instead of just appearing (about 200 ms).
static func pop_in(c: Control, delay := 0.0) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.965, 0.965)
	var set_pivot := func(): c.pivot_offset = Vector2(c.size.x * 0.5, c.size.y * 0.6)
	c.resized.connect(set_pivot)
	set_pivot.call()
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.14).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_delay(delay).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

## A card raised off a panel: the layered frame (light from the top, a rim, a small shadow when
## it's opaque), no outline unless it's picked (set_card_border).
static func card(col := CARD, pad := 14, rad := R_CARD) -> PanelContainer:
	var p := PanelContainer.new()
	var opaque := col.a > 0.6 and rad < R_PILL
	var sb := UiFrame.raised(col, rad, 6 if opaque else 0, RIM if opaque else Color(0, 0, 0, 0))
	sb.lit = 0.05 if opaque else 0.0
	p.add_theme_stylebox_override("panel", sb.padded(pad, pad))
	return p

## Outlines a card (the picked one, or a warning).
static func set_card_border(p: PanelContainer, col: Color, w := 2) -> void:
	var sb := p.get_theme_stylebox("panel").duplicate() as UiFrame
	sb.edge = col
	sb.edge_w = w
	p.add_theme_stylebox_override("panel", sb)

## Dark glass for things that float over the world (prompts, hint rows, the hub bar, hover cards).
static func glass(pad := 10, rad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiFrame.raised(Color(0.05, 0.045, 0.07, 0.82), rad, 10)
	sb.edge = Color(1, 0.95, 0.85, 0.08)
	sb.lit = 0.04
	sb.padded(pad + 2, pad)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## An icon, a heading and a line: what an empty list shows instead of a bare sentence.
static func empty_state(icon: String, head: String, sub: String) -> Control:
	var v := vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := IconDot.new(icon, Color(MUTED, 0.7), 34.0)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(spacer(10))
	v.add_child(g)
	var t := label(head, T_HEAD, INK, big); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := para(sub, T_SMALL, MUTED); s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.custom_minimum_size.x = 380
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(s)
	v.add_child(spacer(10))
	return v

## A label: value row (settings rows, item stats): the label muted on the left, the value right.
static func kv(k: String, val: String, col := INK) -> HBoxContainer:
	var r := hbox(8)
	var kl := label(k, T_SMALL, MUTED); kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(kl)
	r.add_child(label(val, T_SMALL, col, semi))
	return r

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func bar(frac: float, col: Color, w := 120.0, h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func(): draw_bar(c, Rect2(Vector2.ZERO, c.size), frac, col))
	return c

static var _bar_boxes := {}
## Draws a rounded progress bar into any canvas item: a dark track and the filled share in `col`
## (the boxes are cached per colour, nothing is allocated per frame).
static func draw_bar(c: CanvasItem, r: Rect2, frac: float, col: Color, track := Color(0, 0, 0, 0.35),
		rad := -1) -> void:
	var radius := int(minf(r.size.y * 0.5, 4.0)) if rad < 0 else rad
	c.draw_style_box(bar_box(track, radius), r)
	var fw := r.size.x * clampf(frac, 0.0, 1.0)
	if fw > 1.0:
		c.draw_style_box(bar_box(col, radius), Rect2(r.position, Vector2(maxf(fw, radius * 2.0), r.size.y)))

## A cached flat rounded box for bars drawn every frame (one per colour and radius).
static func bar_box(col: Color, radius: int) -> StyleBoxFlat:
	var key := [col, radius]
	if not _bar_boxes.has(key):
		if _bar_boxes.size() > 128:
			_bar_boxes.clear()
		_bar_boxes[key] = UiFrame._flat(col, radius)
	return _bar_boxes[key]

static func spacer(h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Something that takes up the free width in a row (pushes what follows to the right).
static func fill() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Moves focus to the first button inside c (or c itself), so keyboard and pad users land somewhere.
static func focus_first(c: Control) -> void:
	var go := func():
		if not is_instance_valid(c) or not c.is_inside_tree(): return
		var vp := c.get_viewport()
		if vp and vp.gui_get_focus_owner() and c.is_ancestor_of(vp.gui_get_focus_owner()): return
		# the panel's primary first, then the first button that isn't a tab
		if c.has_meta("primary") and is_instance_valid(c.get_meta("primary")):
			var pb: Button = c.get_meta("primary")
			if not pb.disabled and pb.is_visible_in_tree():
				pb.grab_focus()
				return
		var f := _first_focusable(c)
		if f: f.grab_focus()
	go.call_deferred()

static func _first_focusable(n: Node) -> Control:
	if n is Control:
		var c := n as Control
		if not c.is_visible_in_tree(): return null
		if c.focus_mode != Control.FOCUS_NONE and (c is BaseButton) and not (c as BaseButton).disabled and not (c.theme_type_variation in ["IconBtn", "Seg", "SegOn"]):
			return c
	for ch in n.get_children():
		var f := _first_focusable(ch)
		if f: return f
	return null

# ---------------------------------------------------------------- the modal backdrop
static var _bd_shader: Shader = null

## A full-screen layer that blurs and darkens whatever is behind a modal menu. Starts hidden;
## show_backdrop() fades it in and out.
static func backdrop() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.03, 0.035, 0.06, 1.0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	if _bd_shader == null:
		_bd_shader = load("res://shaders/ui_backdrop.gdshader")
	var m := ShaderMaterial.new(); m.shader = _bd_shader
	r.material = m
	r.visible = false
	r.modulate.a = 0.0
	return r

static func show_backdrop(r: ColorRect, on: bool) -> void:
	if not is_instance_valid(r): return
	if r.has_meta("tw"):
		var old: Tween = r.get_meta("tw")
		if old and old.is_valid(): old.kill()
	if on:
		r.visible = true
		var tw := r.create_tween()
		tw.tween_property(r, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
		r.set_meta("tw", tw)
	elif r.visible:
		var tw := r.create_tween()
		tw.tween_property(r, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func(): r.visible = false)
		r.set_meta("tw", tw)

## Panel bodies. The rules (every menu): content fits on one page, with no "Page 1 of 2" pagers;
## anything with more to show opens a sub-page when clicked; a panel never changes size while it's
## open, whatever tab or item you switch to; and it only scrolls when there's truly no other way
## (a window too small for the content), which this wrapper handles as a last resort.
static var _page_of := {}       # (kept for callers that reset it; nothing pages any more)
static var _tall := {}          # menu key -> tallest the menu has been, so it never jumps around
static var _live := {}          # menu key -> how many of it are open
static var _hold := {}          # menu key -> a fixed body height asked for with hold()

## Fixes a menu's body height (its tallest tab or item), so switching tabs or items never resizes
## the panel. Call it each time the menu is built, with the same height.
static func hold(body: Control, h: float) -> void:
	var p := _shell_of(body)
	var key := String(p.get_meta("key", "")) if p else ""
	if key != "":
		_hold[key] = h

## Wraps a VBox of content: it sits at a steady height (the menu's held height, or the tallest it
## has been while open) and, only if the window is too small for it, scrolls. margin: room left for
## the rest of the screen. Returns the wrapper to add where the content would have gone.
static func paged(content: VBoxContainer, margin: float, key: String, head: Control = null, width_hint := 600.0, foot: Control = null) -> VBoxContainer:
	var wrap := vbox(8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	wrap.add_child(sc)
	var state := {"busy": false, "t0": 0}
	var fit := func() -> void:
		if state["busy"] or not is_instance_valid(content) or not content.is_inside_tree():
			return
		state["busy"] = true
		var vp := content.get_viewport_rect().size
		var maxh := maxf(160.0, vp.y - margin - (head.get_combined_minimum_size().y if head else 0.0) - (foot.get_combined_minimum_size().y + float(GAP_BIG) if foot and foot.visible else 0.0))
		var h := content.get_combined_minimum_size().y
		# never shrink while it's open, so the menu doesn't hop as its contents change. Sizes are
		# only trusted once the layout has settled (wrapped text measures tall at first).
		if _hold.has(key):
			# a held menu is exactly its held height on every tab and item (it scrolls only if
			# something truly can't fit)
			sc.custom_minimum_size.y = minf(float(_hold[key]), maxh)
		else:
			if Time.get_ticks_msec() - int(state["t0"]) > 300:
				_tall[key] = maxf(float(_tall.get(key, 0.0)), h)
			sc.custom_minimum_size.y = minf(maxf(h, float(_tall.get(key, 0.0))), maxh)
		state["busy"] = false
	var refit := func() -> void:
		if not state["busy"]: fit.call_deferred()
	content.minimum_size_changed.connect(refit)
	content.child_entered_tree.connect(func(_c): refit.call())
	if foot: foot.visibility_changed.connect(refit)
	wrap.tree_entered.connect(func():
		_live[key] = int(_live.get(key, 0)) + 1
		state["t0"] = Time.get_ticks_msec()
		refit.call()
		# (by instance id: a lambda that captured the wrapper itself errors when it's freed first,
		# "Lambda capture at index 0 was freed", e.g. a menu closed within the 0.35 s)
		var wid := wrap.get_instance_id()
		wrap.get_tree().create_timer(0.35).timeout.connect(func(): if is_instance_id_valid(wid): refit.call())
		var vpt := wrap.get_viewport()
		if vpt and not vpt.size_changed.is_connected(refit): vpt.size_changed.connect(refit))
	wrap.tree_exiting.connect(func():
		_live[key] = int(_live.get(key, 1)) - 1
		# closed for good (not just rebuilt this frame): forget its size
		var ml := Engine.get_main_loop() as SceneTree
		if ml: ml.process_frame.connect(func():
			if int(_live.get(key, 0)) <= 0:
				_tall.erase(key); _page_of.erase(key); _hold.erase(key), CONNECT_ONE_SHOT)
		var vpt := wrap.get_viewport()
		if vpt and vpt.size_changed.is_connected(refit): vpt.size_changed.disconnect(refit))
	return wrap

## How tall a control will be at a given width, worked out from the text itself so wrapped labels
## measure right before the layout has run (they report huge heights until then).
static func est_h(c: Control, w: float) -> float:
	if c == null or (not c.visible and not c.has_meta("pg_off")):
		return 0.0
	var own := c.custom_minimum_size.y
	if c is Label:
		var l := c as Label
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			return l.get_combined_minimum_size().y
		var f := l.get_theme_font("font")
		var fs := l.get_theme_font_size("font_size")
		var ls := float(l.get_theme_constant("line_spacing"))
		var lines := 0
		for para in l.text.split("\n"):
			var tw := f.get_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			lines += maxi(1, int(ceil(tw / maxf(20.0, w - 4.0) + 0.0001)))
		return maxf(own, lines * (f.get_height(fs) + ls))
	if c is GridContainer:
		var g := c as GridContainer
		var cols := maxi(1, g.columns)
		var cw := (w - (cols - 1) * float(g.get_theme_constant("h_separation"))) / cols
		var items: Array = g.get_children().filter(func(x): return x is Control and (x.visible or x.has_meta("pg_off")))
		var total := 0.0
		for i in range(0, items.size(), cols):
			var rh := 0.0
			for it in items.slice(i, i + cols): rh = maxf(rh, est_h(it, cw))
			total += rh + (float(g.get_theme_constant("v_separation")) if i > 0 else 0.0)
		return maxf(own, total)
	if c is VBoxContainer:
		var sep := float(c.get_theme_constant("separation"))
		var total := 0.0; var n := 0
		for ch in c.get_children():
			if ch is Control and ch.visible:
				total += est_h(ch, w); n += 1
		return maxf(own, total + sep * maxi(0, n - 1))
	if c is HBoxContainer:
		var sep := float(c.get_theme_constant("separation"))
		var kids: Array = c.get_children().filter(func(x): return x is Control and x.visible)
		var fixed := 0.0; var expanders := 0
		for ch in kids:
			if (ch as Control).size_flags_horizontal & Control.SIZE_EXPAND: expanders += 1
			else: fixed += (ch as Control).get_combined_minimum_size().x
		var free := maxf(40.0, w - fixed - sep * maxi(0, kids.size() - 1))
		var hmax := 0.0
		for ch in kids:
			var cw: float = free / maxi(1, expanders) if (ch as Control).size_flags_horizontal & Control.SIZE_EXPAND else (ch as Control).get_combined_minimum_size().x
			hmax = maxf(hmax, est_h(ch, cw))
		return maxf(own, hmax)
	if c is PanelContainer or c is MarginContainer:
		var pad := Vector2.ZERO
		if c is PanelContainer:
			var sb := c.get_theme_stylebox("panel")
			if sb: pad = sb.get_minimum_size()
		var hmax := 0.0
		for ch in c.get_children():
			if ch is Control and ch.visible: hmax = maxf(hmax, est_h(ch, w - pad.x))
		return maxf(own, hmax + pad.y)
	if c is HFlowContainer:
		var hs := float(c.get_theme_constant("h_separation")); var vs := float(c.get_theme_constant("v_separation"))
		var x := 0.0; var rows := 1; var rh := 0.0; var total := 0.0
		for ch in c.get_children():
			if not (ch is Control and ch.visible): continue
			var ms := (ch as Control).get_combined_minimum_size()
			if x > 0.0 and x + ms.x > w:
				total += rh + vs; rows += 1; x = 0.0; rh = 0.0
			x += ms.x + hs
			rh = maxf(rh, ms.y)
		return maxf(own, total + rh)
	return c.get_combined_minimum_size().y


## Old name, kept for the results screen: the content, paged rather than scrolled.
static func scroll_box(content: Control, margin := 120.0) -> Control:
	if content is VBoxContainer:
		return paged(content as VBoxContainer, margin, "box")
	return content

# ---------------------------------------------------------------- the panel shell
## A menu panel, the same everywhere: a title (and an optional subtitle) with a close X at the top
## right, an optional row of tabs, the body, and an optional footer of actions at the bottom right.
## The body pages (or, with scroll, scrolls) whenever it's taller than the window, so nothing ends up
## off screen. Returns [panel, body]; use subtitle(body, ...), shell_tabs(body, ...), footer(body)
## and head_extra(body) to fill the rest.
static func scroll_panel(title_txt: String, width: float, on_close: Callable, close_txt := "Close", scroll := false) -> Array:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.theme_type_variation = ""
	var outer := vbox(GAP_BIG - 4)
	p.add_child(outer)
	var top := vbox(GAP)
	outer.add_child(top)
	var head := hbox(GAP)
	if on_close.is_valid() and close_txt == "Back":
		# a sub-page: the way back sits before the title
		var bb := icon_button("back", on_close, "Back  (Esc)", 14.0)
		bb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bb.focus_mode = Control.FOCUS_NONE
		bb.name = "Close"
		head.add_child(bb)
	var tcol := vbox(2); tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := title(title_txt, T_TITLE, INK)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tcol.add_child(t)
	var sub := label("", T_SMALL + 1, MUTED)
	sub.visible = false
	tcol.add_child(sub)
	head.add_child(tcol)
	var extra := hbox(8)
	extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(extra)
	if on_close.is_valid() and close_txt != "Back":
		var xb := icon_button("close", on_close, close_txt + "  (Esc)", 14.0)
		xb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		xb.focus_mode = Control.FOCUS_NONE     # Esc does it; keep it out of the keyboard path
		xb.name = "Close"
		head.add_child(xb)
	top.add_child(head)
	var tabs_slot := vbox(0)
	tabs_slot.visible = false
	top.add_child(tabs_slot)
	var body := vbox(GAP)
	var foot := hbox(10)
	foot.visible = false
	foot.alignment = BoxContainer.ALIGNMENT_END
	var foot_left := hbox(12)
	foot_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(foot_left)
	var foot_right := hbox(10)
	foot.add_child(foot_right)
	if scroll:
		# a real scroll for long lists like Settings: grows with its content up to the window height
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_right", 14)
		pad.add_theme_constant_override("margin_left", 3); pad.add_theme_constant_override("margin_top", 3); pad.add_theme_constant_override("margin_bottom", 3)
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pad.add_child(body)
		sc.add_child(pad)
		outer.add_child(sc)
		var fit := func() -> void:
			if is_instance_valid(sc) and sc.is_inside_tree():
				var chrome := top.get_combined_minimum_size().y + (foot.get_combined_minimum_size().y + GAP_BIG if foot.visible else 0.0)
				sc.custom_minimum_size.y = minf(pad.get_combined_minimum_size().y, sc.get_viewport_rect().size.y - 110.0 - chrome)
		body.minimum_size_changed.connect(func(): fit.call_deferred())
		top.minimum_size_changed.connect(func(): fit.call_deferred())
		foot.visibility_changed.connect(func(): fit.call_deferred())
		sc.tree_entered.connect(func(): fit.call_deferred())
		body.set_meta("scroll", sc)
	else:
		outer.add_child(paged(body, 110.0, title_txt, top, width - PAD * 2.0, foot))
	outer.add_child(foot)
	body.set_meta("shell", p)
	p.set_meta("key", title_txt)
	p.set_meta("title", t); p.set_meta("sub", sub); p.set_meta("extra", extra)
	p.set_meta("tabs", tabs_slot); p.set_meta("foot", foot); p.set_meta("foot_left", foot_left); p.set_meta("foot_right", foot_right)
	var fitw := func():
		if is_instance_valid(p) and p.is_inside_tree():
			p.custom_minimum_size.x = minf(width, p.get_viewport_rect().size.x - 32.0)
	p.tree_entered.connect(func(): fitw.call_deferred())
	p.custom_minimum_size.x = width
	# keyboard and pad users start on the first thing they can press
	p.tree_entered.connect(func(): focus_first(p))
	return [p, body]

static func _shell_of(body: Control) -> PanelContainer:
	var n: Node = body
	while n:
		if n.has_meta("shell"): return n.get_meta("shell")
		if n.has_meta("foot"): return n as PanelContainer
		n = n.get_parent()
	return null

## A short line under a panel's title.
static func subtitle(body: Control, txt: String) -> void:
	var p := _shell_of(body)
	if p == null: return
	var s: Label = p.get_meta("sub")
	s.text = txt
	s.visible = txt != ""

## Changes a panel's title.
static func set_title(body: Control, txt: String) -> void:
	var p := _shell_of(body)
	if p: (p.get_meta("title") as Label).text = txt

## Puts a small control (a Boki's sex icon) right after the panel's title.
static func title_icon(body: Control, c: Control) -> void:
	var p := _shell_of(body)
	if p == null: return
	var t: Label = p.get_meta("title")
	var row: HBoxContainer = p.get_meta("title_row") if p.has_meta("title_row") else null
	if row == null:
		row = hbox(10)
		var par := t.get_parent()
		var at := t.get_index()
		par.remove_child(t)
		row.add_child(t)
		par.add_child(row)
		par.move_child(row, at)
		t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		t.clip_text = false          # (a clipped or trimmed label in a row collapses to nothing)
		t.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		p.set_meta("title_row", row)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)

## A row next to the close X for chips and small things (gems, stored count).
static func head_extra(body: Control) -> HBoxContainer:
	var p := _shell_of(body)
	return p.get_meta("extra") if p else hbox()

## Tabs under the title (a segmented control). Returns the tabs control.
static func shell_tabs(body: Control, names: Array, cur: String, cb: Callable, counts := {}) -> Control:
	var p := _shell_of(body)
	var tb := tabs(names, cur, cb, counts)
	if p == null:
		body.add_child(tb)
		return tb
	var slot: VBoxContainer = p.get_meta("tabs")
	for ch in slot.get_children(): ch.queue_free()
	slot.add_child(tb)
	slot.visible = true
	return tb

## The footer's action row (bottom right). Add buttons to it; the primary goes last.
static func footer(body: Control) -> HBoxContainer:
	var p := _shell_of(body)
	if p == null:
		var h := hbox(10); h.alignment = BoxContainer.ALIGNMENT_END
		body.add_child(h)
		return h
	(p.get_meta("foot") as Control).visible = true
	return p.get_meta("foot_right")

## The footer's main button: primary, with an Enter keycap. Hosts press it on Enter when nothing
## else has focus (press_primary).
static func footer_primary(body: Control, text: String, cb: Callable, minw := 0.0, icon := "") -> Button:
	var b := with_key(primary(text, cb, minw, icon), "Enter")
	footer(body).add_child(b)
	var p := _shell_of(body)
	if p: p.set_meta("primary", b)
	return b

## Presses the primary footer button of the panel under host, if it has one. True when it did.
static func press_primary(host: Node) -> bool:
	for ch in host.get_children():
		if ch.has_meta("primary"):
			var b = ch.get_meta("primary")
			if is_instance_valid(b) and not (b as Button).disabled and (b as Button).is_visible_in_tree():
				(b as Button).pressed.emit()
				return true
	return false

## The footer's left side: hints and notes that go with the actions.
static func footer_left(body: Control) -> HBoxContainer:
	var p := _shell_of(body)
	if p == null: return hbox()
	(p.get_meta("foot") as Control).visible = true
	return p.get_meta("foot_left")

## A plain sheet (a panel without the shell), for full-screen menus like results or the lobby.
static func sheet(width := 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	if width > 0.0:
		p.custom_minimum_size.x = width
	return p

## A small modal on top of a panel host: a badge, a question, Cancel, and a danger (or primary)
## button. Only for things that can't be undone.
static func confirm(host: Control, head: String, text: String, yes_txt: String, on_yes: Callable, dangerous := true) -> Control:
	var layer := Modal.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.04, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cc)
	var p := sheet(460)
	cc.add_child(p)
	var v := vbox(GAP_BIG)
	p.add_child(v)
	var top := hbox(16)
	top.add_child(badge("alert", BAD if dangerous else ACCENT))
	var words := vbox(6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(title(head, 24))
	words.add_child(para(text, T_BODY, MUTED))
	top.add_child(words)
	v.add_child(top)
	var row := hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var no := ghost("Cancel", layer.queue_free)
	row.add_child(no)
	var yes_cb := func():
		layer.queue_free()
		on_yes.call()
	row.add_child(danger(yes_txt, yes_cb) if dangerous else primary(yes_txt, yes_cb))
	v.add_child(row)
	layer.set_meta("modal", true)
	host.add_child(layer)
	pop_in(p)
	no.grab_focus.call_deferred()
	return layer

## A round tinted badge with an icon (a confirm box's warning, an empty state's mark).
static func badge(icon: String, col: Color, px := 44.0, rad := R_PILL) -> PanelContainer:
	var b := PanelContainer.new()
	var f := UiFrame.raised(Color(col, 0.16), rad)
	f.edge = Color(col, 0.4)
	f.lit = 0.08
	b.add_theme_stylebox_override("panel", f.padded(px * 0.24, px * 0.24))
	b.add_child(IconDot.new(icon, col, px * 0.52))
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

## A short note at the top centre of `host` ("Bramble Isle is open"), in the host's message lane
## (MsgLane: stacked, repeats merged, a few at a time). `y` is where the lane starts.
static func toast(host: Control, txt: String, col := GOLD, y := 100.0) -> void:
	var lane := MsgLane.of(host)
	lane.top = y
	lane.push(txt, col)

## True while a toast is on show (or waiting) over `host`.
static func toast_busy(host: Control) -> bool:
	return MsgLane.of(host).count() > 0

## The layer under confirm(): Esc (or the pad's B) cancels it before anything else sees the key.
class Modal extends Control:
	func _input(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_cancel") or (InputMap.has_action("menu") and ev.is_action_pressed("menu")):
			get_viewport().set_input_as_handled()
			queue_free()

## A glyph that knows the menu's own icons too (close, back, gear, home, ...).
class IconDot extends Control:
	var id := ""
	var col := Color.WHITE
	func _init(icon_id := "", c := Color.WHITE, px := 18.0) -> void:
		id = icon_id; col = c
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		UI.draw_icon(self, id, size * 0.5, minf(size.x, size.y) * 0.5, col)

## A Boki's sex as a small ♀ / ♂ icon in its colour (nothing for a record without rolls).
static func sex_icon(rec: Dictionary, px := 14.0) -> Control:
	var sx := Unique.sex(rec)
	if sx == "":
		return Control.new()
	var ic := IconDot.new("female" if sx == "f" else "male", SEX_COL[sx], px)
	ic.tooltip_text = Unique.sex_name(rec)
	ic.mouse_filter = Control.MOUSE_FILTER_PASS
	return ic
const SEX_COL := {"f": Color("ff8fbf"), "m": Color("7cc4ff")}

## A name label with the Boki's sex icon right after it.
static func name_with_sex(rec: Dictionary, txt: String, size := T_BODY, col := INK, font: Font = null, px := 14.0) -> HBoxContainer:
	var h := hbox(6)
	var l := label(txt, size, col, font if font else semi)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	h.add_child(sex_icon(rec, px))
	return h
