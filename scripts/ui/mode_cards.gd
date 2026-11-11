class_name ModeCards
extends RefCounted
## The expedition modes as two cards side by side (Data.MODES): a title and one plain line each. Used by the
## expedition panel and the online lobby; the picked mode is Save.d["exp_mode"] (Data.saved_mode).

## Pick a mode: remembers it for next time, then `cb` runs (a rebuild of the page).
static func pick(mode: String, cb: Callable) -> void:
	Save.d["exp_mode"] = mode
	Save.save_game()
	cb.call()

## A row of one card per mode, `cur` lit. A card press calls `cb(mode)`.
static func make(cur: String, cb: Callable) -> HBoxContainer:
	var row := UI.hbox(10)
	for mode in Data.MODES:
		var card := UI.tile_card(mode == cur, func(): if mode != cur: cb.call(mode), 14)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.set_meta("mode", mode)
		var v := UI.vbox(3)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(UI.label(String(mode).capitalize(), UI.T_HEAD, UI.INK if mode == cur else UI.MUTED, UI.big))
		v.add_child(UI.para(String(Data.MODE_LINES[mode]), UI.T_BODY, UI.INK if mode == cur else UI.MUTED))
		card.add_child(v)
		row.add_child(card)
	return row
