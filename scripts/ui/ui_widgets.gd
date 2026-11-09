class_name UiWidgets
## Widgets of the menu kit: buttons, icons, tabs, tiles, chips, tags, keycaps, bars and badges.

# ---------------------------------------------------------------- small pieces

## A key drawn as a little keycap ("F", "Space", "Esc"), so prompts read at a glance instead of as
## letters in brackets.
static func keycap(key: String, size := 13) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiFrame.raised(Color(0.93, 0.9, 0.84, 0.95), UI.R_SMALL - 1)
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
	l.add_theme_font_override("font", UI.caps if UI.caps else UI.body)
	l.add_theme_font_size_override("font_size", size - 1 if key.length() > 1 else size)
	l.add_theme_color_override("font_color", Color(0.16, 0.12, 0.14))
	p.add_child(l)
	return p

## A row of "[key] what it does" hints. pairs: [["F", "use"], ["Space", "jump"], ...]; a key string
## with spaces in it ("W S") draws one cap per key.
static func key_hints(pairs: Array, size := 13, col := Color(1, 1, 1, 0.75)) -> HBoxContainer:
	var row := UI.hbox(16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pr in pairs:
		var one := UI.hbox(5)
		one.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in String(pr[0]).split(" "):
			if k != "": one.add_child(keycap(k, size))
		var l := UiText.label(String(pr[1]), size + 1, col)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.08, 0.6))
		one.add_child(l)
		row.add_child(one)
	return row

# ---------------------------------------------------------------- buttons
## Buttons whose label says "go back" play the falling pair instead of the tap.
const BACK_WORDS := {"Back": "ui_back", "Close": "ui_back", "Cancel": "ui_back", "✕": "ui_back",
	"Leave it  (Esc)": "ui_back"}

## The secondary button (an outline). icon: an Icons id drawn at its left. Hover fills it with the
## theme's hover colour (no growing: a button never spills over its neighbours or the panel edge);
## pressing sinks it a touch, in about 70 ms.
static func button(text: String, cb: Callable, minw := 0.0, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	if cb.is_valid():
		var snd: String = BACK_WORDS.get(text, "click")
		b.pressed.connect(func(): Sfx.play(String(b.get_meta("snd", snd))); cb.call())
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
		Sfx.play("hover", null, -12.0, 0.05))
	b.mouse_exited.connect(func(): to.call(1.0, 0.11))
	b.button_down.connect(func(): if not b.disabled: to.call(0.97, 0.07))
	b.button_up.connect(func(): to.call(1.0, 0.1))
	b.focus_entered.connect(func():
		# keyboard and pad focus tick and lift like the mouse does
		if not b.is_hovered() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			Sfx.play("hover", null, -14.0, 0.05))
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

## A red-outlined button for things that can't be undone (pair it with UiShell.confirm()).
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
	b.icon = UI._blank(px, px)
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
	track.add_theme_stylebox_override("panel", UiFrame.sunk(UI.WELL, UI.R_SMALL + 5).padded(3, 3))
	track.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := UI.hbox(2)
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
static func tile_card(on: bool, cb: Callable, pad := 12, col := UI.ACCENT) -> PanelContainer:
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
	var ring := UiTheme.ring(UI.R_CARD + 3)
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

## A selectable card's face: raised, lit when hovered, an edge in `col` when picked.
static func _tile_face(on: bool, hover: bool, col: Color, pad: float) -> UiFrame:
	var tint := col if on else Color.WHITE
	var alpha := 0.13 if on else 0.04
	var fill := Color(tint, alpha + (0.05 if hover else 0.0))
	var f := UiFrame.raised(fill, UI.R_CARD)
	f.edge_w = 2 if on else 1
	if on:
		f.edge = Color(col, 0.9)
	else:
		f.edge = Color(1, 1, 1, 0.24 if hover else 0.06)
	return f.padded(pad, pad)

## A pill: an icon and a value with a tooltip (gems, scrap, stored). col tints it.
static func chip(icon: String, txt: String, col := UI.INK, tip := "", size := 14) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UI.frame(Color(col, 0.11), UI.R_PILL, Color(col, 0.18), 1, 10, 4, 0.0))
	c.tooltip_text = tip
	c.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := UI.hbox(6); c.add_child(h)
	if icon != "":
		var g := IconDot.new(icon, col, size + 2.0)
		h.add_child(g)
	var l := UiText.label(txt, size, UI.INK, UI.semi)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	return c

## A small coloured tag ("Rare", "Equipped", "Locked").
static func tag(txt: String, col: Color) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UI.frame(Color(col, 0.16), UI.R_SMALL, Color(0, 0, 0, 0), 0, 7, 2, 0.0))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiText.label(txt.to_upper(), 11, col.lightened(0.15), UI.caps)
	c.add_child(l)
	return c

## An icon, a heading and a line: what an empty list shows instead of a bare sentence.
static func empty_state(icon: String, head: String, sub: String) -> Control:
	var v := UI.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := IconDot.new(icon, Color(UI.MUTED, 0.7), 34.0)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(UI.spacer(10))
	v.add_child(g)
	var t := UiText.label(head, UI.T_HEAD, UI.INK, UI.big); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UiText.para(sub, UI.T_SMALL, UI.MUTED); s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.custom_minimum_size.x = 380
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(s)
	v.add_child(UI.spacer(10))
	return v

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

## A round tinted badge with an icon (a confirm box's warning, an empty state's mark).
static func badge(icon: String, col: Color, px := 44.0, rad := UI.R_PILL) -> PanelContainer:
	var b := PanelContainer.new()
	var f := UiFrame.raised(Color(col, 0.16), rad)
	f.edge = Color(col, 0.4)
	f.lit = 0.08
	b.add_theme_stylebox_override("panel", f.padded(px * 0.24, px * 0.24))
	b.add_child(IconDot.new(icon, col, px * 0.52))
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

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
		UiWidgets.draw_icon(self, id, size * 0.5, minf(size.x, size.y) * 0.5, col)

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
static func name_with_sex(rec: Dictionary, txt: String, size := UI.T_BODY, col := UI.INK, font: Font = null, px := 14.0) -> HBoxContainer:
	var h := UI.hbox(6)
	var l := UiText.label(txt, size, col, font if font else UI.semi)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	h.add_child(sex_icon(rec, px))
	return h
