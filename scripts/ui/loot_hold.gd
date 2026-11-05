class_name LootHold
## The "no room" window beside an open box: your backpack on the left of the loot window, the thing
## you clicked held at the top with a red outline, and for each of your things a Swap (it goes into
## the box) and a Drop (it goes on the ground). The logic is LootFull; this only builds the window.

const INK := Color("f3eee2")
const MUTED := Color("a9b0bf")
const GOLD := Color("f2c84a")
const WIDTH := 470.0

## Builds the window. on_swap / on_drop get the index of the backpack thing; on_close takes no args.
static func build(
		p: Hunter, held: Dictionary, on_swap: Callable, on_drop: Callable, on_close: Callable) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.theme = UI.theme()
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.custom_minimum_size.x = WIDTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.065, 0.1, 0.95)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(LootFull.FULL_COL, 0.8)
	sb.set_border_width_all(2)
	sb.border_width_top = 4
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	pc.add_theme_stylebox_override("panel", sb)
	var v := UI.vbox(6)
	pc.add_child(v)
	var head := UI.hbox(8)
	v.add_child(head)
	var t := UI.title("Backpack full  %d/%d" % [p.pack.size(), p.pack_cap], 20, LootFull.FULL_COL)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var cl := UI.button("✕", on_close, 36)
	cl.flat = true
	head.add_child(cl)
	v.add_child(UI.label("Holding", 12, MUTED, UI.caps))
	var held_row := item_row(held, [])
	mark_full(held_row)
	v.add_child(held_row)
	v.add_child(UI.label("Swap it with one of yours, or drop one", 12, MUTED, UI.caps))
	for i in p.pack.size():
		var idx := i
		var buttons: Array = [["Swap", func(): on_swap.call(idx), true], ["Drop", func(): on_drop.call(idx)]]
		v.add_child(item_row(p.pack[i], buttons))
	return pc

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
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(col, 0.09)
	rs.set_corner_radius_all(9)
	rs.border_color = Color(col, 0.6)
	rs.border_width_left = 3
	rs.content_margin_left = 8
	rs.content_margin_right = 8
	rs.content_margin_top = 5
	rs.content_margin_bottom = 5
	rp.add_theme_stylebox_override("panel", rs)
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
