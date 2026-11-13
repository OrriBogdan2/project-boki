class_name LootHold
## Item rows shared by the item windows (the backpack, the swap window and the deathbox's LootWindow):
## the two-line row, the red "no room" outline and whole-row clicks.

const INK := Color("f3eee2")
const MUTED := Color("a9b0bf")
const GOLD := Color("f2c84a")
const WIDTH := 470.0        # px, the backpack and swap windows

## Outlines a row in red: the "inventory full" cue on an item that doesn't fit.
static func mark_full(row: PanelContainer) -> void:
	var rs := row.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	rs.border_color = LootFull.FULL_COL
	rs.set_border_width_all(2)
	rs.border_width_left = 4
	row.add_theme_stylebox_override("panel", rs)

## One item as a row: icon, name, what it does, its worth, and buttons [[text, callable, primary]].
## The backpack and swap windows use it too.
static func item_row(it: Dictionary, buttons: Array, note := "") -> PanelContainer:
	var rp := PanelContainer.new()
	var col := Loot.col_of(it)
	rp.add_theme_stylebox_override("panel", row_box(col, 5))
	var row := UI.hbox(8)
	rp.add_child(row)
	row.add_child(Icons.Glyph.new(Loot.icon_of(it), col, 24.0))
	var cv := UI.vbox(0)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(Loot.name_of(it) + (("  ·  " + note) if note != "" else ""), 15, col, UI.semi)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	nm.custom_minimum_size.x = 200
	cv.add_child(nm)
	var sub := UI.label(Loot.sub_of(it), 12, MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.clip_text = true
	sub.custom_minimum_size.x = 200
	sub.tooltip_text = Loot.sub_of(it)
	sub.mouse_filter = Control.MOUSE_FILTER_PASS
	cv.add_child(sub)
	row.add_child(cv)
	row.add_child(Icons.Glyph.new("gem", Color(GOLD, 0.8), 12.0))
	var vt := UI.label("%d" % Loot.value(it), 13, GOLD, UI.big)
	vt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vt)
	for bt in buttons:
		var is_primary: bool = bt.size() > 2 and bt[2]
		var b: Button = UI.primary(String(bt[0]), bt[1], 76) if is_primary else UI.button(String(bt[0]), bt[1], 70)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	return rp

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

## Makes a whole item row clickable (as well as its buttons): hovering lights it up.
static func row_click(rp: Control, cb: Callable) -> void:
	rp.mouse_filter = Control.MOUSE_FILTER_STOP
	rp.mouse_entered.connect(func(): rp.modulate = Color(1.12, 1.12, 1.12))
	rp.mouse_exited.connect(func(): rp.modulate = Color.WHITE)
	rp.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			rp.accept_event()
			Sfx.play("click")
			cb.call())
