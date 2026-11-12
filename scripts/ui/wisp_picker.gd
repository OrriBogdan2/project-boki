class_name WispPicker
extends RefCounted
## The Wisp skins row in the glider rack's panel (Home._open_rack): every skin in
## content/rules/wisp_looks.json as a tile, the one you wear marked; a click wears it (WispLook.equip) and
## saves. All skins are free starters for now: no shop or ownership yet (docs/DEBT.md).

## Adds the "Wisp skins" section to the panel `v`; `reopen` redraws the panel after a pick.
static func add_to(v: Control, reopen: Callable) -> void:
	v.add_child(UI.section("Wisp skins  ·  what you turn into when you're down"))
	var row := UI.hbox(8)
	var looks: Dictionary = WispLook.rules()["looks"]
	for id in looks:
		var sid := String(id)
		var worn := WispLook.equipped() == sid
		var tc := UI.tile_card(worn, func(): _wear(sid, reopen), 8)
		tc.custom_minimum_size = Vector2(150, 0)
		tc.tooltip_text = String(looks[sid]["desc"])
		var tv := UI.vbox(1)
		tc.add_child(tv)
		tv.add_child(UI.label(String(looks[sid]["name"]), UI.T_BODY, UI.INK, UI.semi))
		var state_col := UI.GOOD if worn else UI.MUTED
		tv.add_child(UI.label("Wearing" if worn else "Free", 12, state_col))
		row.add_child(tc)
	v.add_child(row)

static func _wear(id: String, reopen: Callable) -> void:
	WispLook.equip(id)
	Save.save_game()
	reopen.call()
