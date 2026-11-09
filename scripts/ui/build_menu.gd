class_name BuildMenu
extends Control
## The small menu that opens when you click a piece you have placed: Move, Rotate, Store and, for pieces that
## have one, a colour row. It opens beside the click and keeps off the rects in `blocked`. Clicking anywhere
## else closes it.

signal closed

## entries: [{label, key, cb}]. colours: hex strings (empty: no row); on_colour gets the picked one.
static func open(host: Control, at: Vector2, title: String, entries: Array, colours := [], current := "",
		on_colour := Callable(), blocked := []) -> BuildMenu:
	var menu := BuildMenu.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			menu.close())
	var card := UI.card(Color(0.07, 0.08, 0.12, 0.96), 10, 12)
	UI.set_card_border(card, Color(1, 1, 1, 0.14), 1)
	var col := UI.vbox(6)
	card.add_child(col)
	col.add_child(UiText.label(title, 16, UI.GOLD, UI.semi))
	for entry in entries:
		var cb: Callable = entry["cb"]
		var b := UiWidgets.button(String(entry["label"]), func():
			menu.close()
			cb.call(), 190)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(UiWidgets.with_key(b, String(entry["key"])) if String(entry.get("key", "")) != "" else b)
	if not colours.is_empty():
		var swatches := UI.hbox(5)
		for hex in colours:
			var chosen := String(hex)
			var sw := Button.new()
			sw.custom_minimum_size = Vector2(26, 26)
			var face := UI.frame(Color(chosen), 13, UI.INK if chosen == current else Color(0, 0, 0, 0), 3)
			for state in ["normal", "hover", "pressed"]:
				sw.add_theme_stylebox_override(state, face)
			sw.tooltip_text = "Colour"
			sw.pressed.connect(func():
				menu.close()
				on_colour.call(chosen))
			swatches.add_child(sw)
		col.add_child(swatches)
	menu.add_child(card)
	host.add_child(menu)
	card.reset_size()
	card.position = BuildKeys.place_card(card.size, at, Vector2(8.0, 0.0), blocked)
	UI.pop_in(card)
	return menu

func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
