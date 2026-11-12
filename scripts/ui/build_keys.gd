class_name BuildKeys
extends Control
## The controls of build and decorate mode: one card by the cursor that names the piece, lists its action keys and
## says why a spot is refused. It keeps clear of the catalog bar, the top of the screen and any card in `avoid`.

const TAG_OFFSET := Vector2(26, 20)
const TOP_BAND := 56.0
const MARGIN := 8.0

var above: Control               # the catalog bar the card keeps off
var avoid: Array = []            # more Controls (the Goals card) the card and the piece menu keep off
var tag: PanelContainer
var _tag_sig := ""

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag = UI.glass(8, 10)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.visible = false
	add_child(tag)

## state: held (bool), item (String), tool (line or brush), can_rotate, can_store, reason, ok, sweep (put-away
## mode), over (a placed piece's name under the cursor when nothing is held).
func show_state(state: Dictionary) -> void:
	_set_tag(state)

func _process(_delta: float) -> void:
	if tag.visible:
		var cursor := get_viewport().get_mouse_position()
		tag.position = place_card(tag.size, cursor, TAG_OFFSET, blocked_rects(above, avoid))

## Screen rects a floating card must not cover: the top band, the catalog bar and each visible control in `others`.
static func blocked_rects(bar: Control, others: Array) -> Array:
	var rects: Array = []
	var width := 4096.0
	if is_instance_valid(bar):
		width = bar.get_viewport().get_visible_rect().size.x
		rects.append(bar.get_global_rect())
	rects.append(Rect2(0.0, 0.0, width, TOP_BAND))
	for ctl in others:
		if is_instance_valid(ctl) and (ctl as Control).is_visible_in_tree():
			rects.append((ctl as Control).get_global_rect())
	return rects

## Where a card of `card_size` goes next to `cursor`: below-right first, then flipped across the cursor, so it never
## covers a rect in `blocked` or leaves the screen. The cursor itself stays clear of it.
static func place_card(card_size: Vector2, cursor: Vector2, offset: Vector2, blocked: Array,
		vp := Vector2.ZERO) -> Vector2:
	if vp == Vector2.ZERO:
		vp = Engine.get_main_loop().root.get_visible_rect().size
	var xs := [cursor.x + offset.x, cursor.x - offset.x - card_size.x]
	var ys := [cursor.y + offset.y, cursor.y - offset.y - card_size.y]
	for y in ys:
		for x in xs:
			var rect := Rect2(x, y, card_size.x, card_size.y)
			if rect.position.x < MARGIN or rect.position.y < MARGIN:
				continue
			if rect.end.x > vp.x - MARGIN or rect.end.y > vp.y - MARGIN:
				continue
			if not blocked.any(func(r: Rect2) -> bool: return r.intersects(rect)):
				return rect.position
	var low := MARGIN
	for r in blocked:
		if (r as Rect2).position.y <= MARGIN + 1.0:
			low = maxf(low, (r as Rect2).end.y + MARGIN)
	var high := vp.y - card_size.y - MARGIN
	for r in blocked:
		if (r as Rect2).end.y >= vp.y - 1.0 or (r as Rect2).position.y > vp.y * 0.5:
			high = minf(high, (r as Rect2).position.y - card_size.y - MARGIN)
	var left := clampf(xs[0], MARGIN, maxf(MARGIN, vp.x - card_size.x - MARGIN))
	return Vector2(left, clampf(ys[0], low, maxf(low, high)))

func _set_tag(state: Dictionary) -> void:
	var held := bool(state.get("held", false))
	var item := String(state.get("item", "")) if held else String(state.get("over", ""))
	tag.visible = item != ""
	if not tag.visible:
		return
	var reason := String(state.get("reason", "")) if held and not bool(state.get("ok", true)) else ""
	var flags := "%s%s%s%s%s" % [held, state.get("tool", false), state.get("can_rotate", false),
		state.get("can_store", false), state.get("sweep", false)]
	var sig := "%s|%s|%s" % [item, reason, flags]
	if sig == _tag_sig:
		return
	_tag_sig = sig
	for old in tag.get_children():
		tag.remove_child(old)
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
