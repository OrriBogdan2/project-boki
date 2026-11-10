class_name GardenItemRows
extends RefCounted
## The feed menu's rows for shaping items (GardenItems): what is in the bag with its exact effect on this
## Boki, and what it wears now with a Take off button.

## Adds a row for each shaping item in the bag. feed(id) gives the item to the Boki.
static func add_bag(v: VBoxContainer, rec: Dictionary, feed: Callable) -> bool:
	var any := false
	for id in GardenItems.ids():
		var n := int(Save.d["items"].get(id, 0))
		if n <= 0 or not GardenItems.fed(id):
			continue
		any = true
		var title := "%s  ×%d" % [GardenItems.item_name(id), n]
		_row(v, title, String(GardenItems.preview(rec, id)["text"]), "Feed", feed.bind(id))
	return any

## Adds a row for each token and Stayleaf the Boki wears. changed() runs after one comes off.
static func add_worn(v: VBoxContainer, rec: Dictionary, changed: Callable) -> void:
	var on: Array = GardenItems.worn(rec).duplicate()
	if rec.get("stay", false):
		on.append("stayleaf")
	for id in on:
		_row(v, "wearing %s" % GardenItems.item_name(id), "Take it off: it goes back in the bag.", "Take off",
				func():
					GardenItems.take_off(rec, id)
					changed.call())

static func _row(v: VBoxContainer, title: String, desc: String, btn: String, act: Callable) -> void:
	var row := UI.hbox(10)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(title, 16))
	info.add_child(UI.label(desc, 12, UI.MUTED))
	row.add_child(info)
	row.add_child(UI.button(btn, act, 100))
	v.add_child(row)
