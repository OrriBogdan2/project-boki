class_name HubBar
extends RefCounted
## The row of icon buttons along the bottom: the farm's hub (Expedition, Kin, Bag, Market...) and the
## practice areas' bar (Hero, loadout, Leave). One look, built here, so both screens match.

const BUTTON := Vector2(62, 58)      # px, one entry

## items: [id, label, icon, open Callable, optional key cap text]. With no cap text the entry gets its
## 1-based position (the farm opens them with the number keys); pass "" for none. `go` is called as
## go.call(open, id) when one is clicked. `btns` (if given) is filled id -> Button.
static func build(items: Array, go: Callable, btns := {}) -> PanelContainer:
	var bar := UI.glass(6, 16)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := UI.hbox(4); bar.add_child(row)
	for i in items.size():
		var it: Array = items[i]
		var cb: Callable = it[3]
		var cap := String(it[4]) if it.size() > 4 else str(i + 1)
		var b := UiWidgets.button("", func(): go.call(cb, String(it[0])))
		b.theme_type_variation = "Ghost"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = BUTTON
		b.tooltip_text = "%s  (%s)" % [it[1], cap] if cap != "" else String(it[1])
		var ic := UiWidgets.IconDot.new(String(it[2]), UI.INK, 22.0)
		ic.position = Vector2(23, 9)
		b.add_child(ic)
		var lb := UiText.label(String(it[1]), 11, UI.MUTED, UI.semi)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		lb.offset_top = -19; lb.offset_bottom = -4
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lb)
		if cap != "":
			var kc := UiWidgets.keycap(cap, 10)
			kc.position = Vector2(2, 2)
			kc.modulate.a = 0.75
			b.add_child(kc)
		b.mouse_entered.connect(func(): ic.col = UI.ACCENT_HI; ic.queue_redraw(); lb.add_theme_color_override("font_color", UI.INK))
		b.mouse_exited.connect(func(): ic.col = UI.INK; ic.queue_redraw(); lb.add_theme_color_override("font_color", UI.MUTED))
		btns[String(it[0])] = b
		row.add_child(b)
	return bar
