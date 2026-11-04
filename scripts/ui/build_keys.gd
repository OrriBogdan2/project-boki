class_name BuildKeys
extends Control
## The controls of build and decorate mode: a strip of buttons with their key caps above the catalog bar, and a
## small tag by the cursor that lists the same keys and says why a spot is refused.

const TAG_OFFSET := Vector2(26, 20)

## Callables to run: rotate, place, store, cancel, sweep (the quick put-away mode).
var actions: Dictionary = {}
var above: Control               # the catalog bar the strip sits on top of
var strip: PanelContainer
var tag: PanelContainer
var _strip_sig := ""
var _tag_sig := ""

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip = UI.glass(6, 12)
	strip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(strip)
	tag = UI.glass(8, 10)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.visible = false
	add_child(tag)

## state: held (bool), item (String), tool (line or brush), can_rotate, can_store, fresh (a new piece from the
## catalog, not one picked up off the ground), ok, reason, sweep (put-away mode), over (a placed piece's name
## under the cursor when nothing is held).
func show_state(state: Dictionary) -> void:
	_set_strip(state)
	_set_tag(state)

func _process(_delta: float) -> void:
	if not tag.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	var at := get_viewport().get_mouse_position() + TAG_OFFSET
	at.x = minf(at.x, vp.x - tag.size.x - 8.0)
	at.y = minf(at.y, vp.y - tag.size.y - _bottom_pad() - 8.0)
	tag.position = at

func _bottom_pad() -> float:
	return above.size.y + 28.0 if is_instance_valid(above) else 214.0

func _call(action: String) -> Callable:
	return actions.get(action, Callable())

func _set_strip(state: Dictionary) -> void:
	var sig := "%s%s%s%s%s%s" % [state.get("held", false), state.get("tool", false), state.get("can_rotate", false),
		state.get("can_store", false), state.get("fresh", false), state.get("sweep", false)]
	strip.offset_bottom = -_bottom_pad()
	strip.offset_top = strip.offset_bottom - 40.0
	if sig == _strip_sig:
		return
	_strip_sig = sig
	for old in strip.get_children():
		old.queue_free()
	var row := UI.hbox(8)
	strip.add_child(row)
	if bool(state.get("held", false)):
		if bool(state.get("can_rotate", false)):
			row.add_child(_button("Rotate  (or RMB)", Settings.key_cap("rotate"), _call("rotate")))
		row.add_child(_button("Place", "LMB", _call("place"), true))
		if bool(state.get("can_store", false)):
			var store_label := "Put back" if bool(state.get("fresh", false)) else "Store"
			row.add_child(_button(store_label, Settings.key_cap("store"), _call("store")))
		row.add_child(_button("Cancel", Settings.key_cap("menu"), _call("cancel")))
		if not bool(state.get("tool", false)):
			row.add_child(UI.label("Hold Shift to place more", 13, UI.MUTED))
	else:
		var sweep := bool(state.get("sweep", false))
		row.add_child(UI.choice("Move", not sweep, _call("sweep_off")))
		row.add_child(UI.choice("Store: click a piece", sweep, _call("sweep_on")))

func _button(label: String, key: String, cb: Callable, primary := false) -> Button:
	var b := UI.primary(label, cb) if primary else UI.button(label, cb)
	b.add_theme_font_size_override("font_size", 15)
	return UI.with_key(b, key)

func _set_tag(state: Dictionary) -> void:
	var held := bool(state.get("held", false))
	var item := String(state.get("item", "")) if held else String(state.get("over", ""))
	tag.visible = item != ""
	if not tag.visible:
		return
	var reason := String(state.get("reason", "")) if held and not bool(state.get("ok", true)) else ""
	var flags := "%s%s%s%s" % [held, state.get("tool", false), state.get("can_rotate", false),
		state.get("sweep", false)]
	var sig := "%s|%s|%s" % [item, reason, flags]
	if sig == _tag_sig:
		return
	_tag_sig = sig
	for old in tag.get_children():
		old.queue_free()
	var col := UI.vbox(4)
	tag.add_child(col)
	col.add_child(UI.label(item, 16, UI.INK, UI.semi))
	if reason != "":
		col.add_child(UI.label(reason, 14, Color("ff9a8a")))
	var store_cap := Settings.key_cap("store")
	var pairs: Array = []
	if not held:
		pairs = [["LMB", "Options"], [store_cap, "Store"]]
		if bool(state.get("sweep", false)):
			pairs = [["LMB", "Store it"]]
	elif bool(state.get("tool", false)):
		pairs = [["LMB", "Drag to paint"], [Settings.key_cap("menu"), "Cancel"]]
	else:
		pairs = [["LMB", "Place"], [Settings.key_cap("menu"), "Cancel"]]
		if bool(state.get("can_rotate", false)):
			pairs.insert(0, ["%s RMB" % Settings.key_cap("rotate"), "Rotate"])
		if bool(state.get("can_store", false)):
			pairs.insert(2, [store_cap, "Store"])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 3)
	col.add_child(grid)
	for pair in pairs:
		grid.add_child(UI.key_hints([pair], 12, Color(1, 1, 1, 0.85)))
	tag.reset_size()
