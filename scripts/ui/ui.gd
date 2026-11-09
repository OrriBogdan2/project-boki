class_name UI
## Split by kind: UiText (labels, titles), UiWidgets (buttons, tabs, chips, icons), UiShell (panel shell, confirm, toast). This file keeps the tokens, theme, containers and paging.
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

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

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
	var p := UiShell._shell_of(body)
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
