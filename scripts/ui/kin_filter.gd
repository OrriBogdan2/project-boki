class_name KinFilter
extends HFlowContainer
## The type filter and sort the Field Book and the Boki Burrow share: an "All" chip, one chip per type
## in its own colour (DexView.TYPES), and the sort choices (KinBox.SORTS: number, level, trust, newest
## ...). The two picks live for the session only (never in the save), the same in both places. Legendary
## kin stay last under every sort (KinBox.sorted does that).

static var type := ""           # the type id picked, "" = every type
static var sort := "number"     # a KinBox.SORTS key

var _changed: Callable

## on_change runs after any pick (the owner rebuilds what it lists).
func _init(on_change: Callable) -> void:
	_changed = on_change
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 6)
	_build()

## Does a species pass the type pick?
static func type_ok(species: String) -> bool:
	return type == "" or DexView.type_of(species) == type

func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	add_child(UI.choice("All", type == "", _pick_type.bind("")))
	for t in DexView.TYPES:
		var b := UI.choice("", type == t, _pick_type.bind(t), 28.0)
		b.tooltip_text = DexView.type_name(t)
		var middle := CenterContainer.new()
		middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon := DexView.TypeIcon.new(t, 18.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		middle.add_child(icon)
		b.add_child(middle)
		add_child(b)
	var so := OptionButton.new()
	for s in KinBox.SORTS:
		if s[0] == "slot":
			continue
		so.add_item("By " + String(s[1]).to_lower())
		so.set_item_metadata(so.item_count - 1, s[0])
		if s[0] == sort:
			so.select(so.item_count - 1)
	so.item_selected.connect(func(i: int):
		sort = String(so.get_item_metadata(i))
		_changed.call())
	so.tooltip_text = "The order Boki are listed in (legendaries always last)"
	add_child(so)

func _pick_type(t: String) -> void:
	type = t
	_build()
	_changed.call()
