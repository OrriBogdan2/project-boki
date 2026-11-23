class_name LootHold
## Item rows shared by the item windows (the backpack, the swap window and the deathbox's LootWindow):
## the two-line row, the red "no room" outline and whole-row clicks.

const INK := Color("f3eee2")
const MUTED := Color("a9b0bf")
const GOLD := Color("f2c84a")
const WIDTH := 470.0        # px, the backpack and swap windows
const COMPACT_BTN_H := 24.0 # px, a button on a one-line (compact) row

## Outlines a row in red: the "inventory full" cue on an item that doesn't fit.
static func mark_full(row: PanelContainer) -> void:
	var rs := row.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	rs.border_color = LootFull.FULL_COL
	rs.set_border_width_all(2)
	rs.border_width_left = 4
	row.add_theme_stylebox_override("panel", rs)

## One item as a row: icon, name, what it does, its worth, and buttons [[text, callable, primary, own_cue]]
## (own_cue: the action plays its inventory cue, InvSfx, so the button itself is silent).
## The backpack and swap windows use it too. `compact`: one line (no "what it does" line, that is on the hover
## card), so a full backpack fits a 720p window.
static func item_row(it: Dictionary, buttons: Array, note := "", compact := false) -> PanelContainer:
	var rp := PanelContainer.new()
	var col := Loot.col_of(it)
	rp.add_theme_stylebox_override("panel", row_box(col, 2 if compact else 5))
	var row := UI.hbox(6 if compact else 8)
	rp.add_child(row)
	row.add_child(Icons.Glyph.new(Loot.icon_of(it), col, 18.0 if compact else 24.0))
	var cv := UI.vbox(0)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Loot.name_of(it) + (("  ·  " + note) if note != "" else "")
	var nm := UI.label(title, 13 if compact else 15, col, UI.semi)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size.x = 200
	cv.add_child(nm)
	if compact:
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sub := UI.label(Loot.sub_of(it), 12, MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.custom_minimum_size.x = 200
	sub.tooltip_text = Loot.sub_of(it)
	sub.mouse_filter = Control.MOUSE_FILTER_PASS
	if not compact:
		cv.add_child(sub)
	else:
		sub.free()
	row.add_child(cv)
	row.add_child(Icons.Glyph.new("gem", Color(GOLD, 0.8), 12.0))
	var vt := UI.label("%d" % Loot.value(it), 13, GOLD, UI.big)
	vt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vt)
	for bt in buttons:
		var is_primary: bool = bt.size() > 2 and bt[2]
		var b: Button = UI.primary(String(bt[0]), bt[1], 76) if is_primary else UI.button(String(bt[0]), bt[1], 70)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if compact:
			_compact_button(b)
		if bt.size() > 3 and bt[3]:
			b.set_meta("snd", InvSfx.SILENT)
		row.add_child(b)
	return rp

## Trims a button for a one-line row: smaller text and no theme padding above and below.
static func _compact_button(b: Button) -> void:
	b.custom_minimum_size.y = COMPACT_BTN_H
	b.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:  # theme padding is for full-size buttons
		var box := b.get_theme_stylebox(state).duplicate() as StyleBox
		box.content_margin_top = 1.0
		box.content_margin_bottom = 1.0
		b.add_theme_stylebox_override(state, box)

## An item row's face: a faint wash of its colour with a coloured left edge; `pad_v` px above and below.
static func row_box(col: Color, pad_v: int) -> StyleBoxFlat:
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(col, 0.09)
	rs.set_corner_radius_all(9)
	rs.border_color = Color(col, 0.6)
	rs.border_width_left = 3
	rs.content_margin_left = 8
	rs.content_margin_right = 8
	rs.content_margin_top = pad_v
	rs.content_margin_bottom = pad_v
	return rs

## Makes a whole item row clickable (as well as its buttons): hovering lights it up. `quiet`: the action
## plays its own inventory cue (InvSfx), so the click itself makes no sound.
static func row_click(rp: Control, cb: Callable, quiet := false) -> void:
	rp.mouse_filter = Control.MOUSE_FILTER_STOP
	rp.mouse_entered.connect(func(): rp.modulate = Color(1.12, 1.12, 1.12))
	rp.mouse_exited.connect(func(): rp.modulate = Color.WHITE)
	rp.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			rp.accept_event()
			if not quiet:
				Sfx.play("click")
			cb.call())
