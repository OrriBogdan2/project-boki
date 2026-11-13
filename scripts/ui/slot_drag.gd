class_name SlotDrag
extends Node
## Press, hold and move a thing from one slot to another: the shared drag for item windows (the in-match
## inventory, the practice loadout L). The window registers its slots with a key ({inv, i} or its own) and
## one `move` callable; this node carries the picked-up thing and asks `move` on release.
##   mouse   press on a slot, then hold still HOLD_S or move MOVE_PX: it comes up under the pointer; release
##           over another slot drops it there
##   pad     hold A on the focused slot HOLD_S: it comes up; move focus with the stick or d-pad; release A
##   move    move.call(from_key, to_key) -> String: does the move (and rebuilds the window) and returns "",
##           or returns a short reason it can't go there: the thing snaps back, the reason shows by it
## A tap (released before it comes up) passes through, so a slot's buttons and keys still work. Dropping on
## the slot it came from, or on no slot, puts it back without a word.

const HOLD_S := 0.22          # s: how long a still press waits before the thing comes up
const MOVE_PX := 8.0          # px: moving this far while pressed picks it up at once
const SNAP_S := 0.14          # s: the snap back to its slot after a refused drop
const HINT_S := 1.6           # s: how long the refusal stays up
const LAYER := 100            # over the HUD and the menus
const PAD_LIFT := Vector2(18.0, -22.0)    # px: the carried thing sits off the focused slot's centre (pad)

var _move: Callable
var _slots := {}              # Control -> {key: Dictionary, label: String, col: Color} (label "" drop-only)
var _press := {}              # a press not yet picked up: {at: Control, t: s held, pos: Vector2, pad: bool}
var _held := {}               # what is carried: {at: Control, pad: bool}
var _layer: CanvasLayer
var _preview: Control
var _ring: Panel

## Adds a drag to `host` (it goes when the host does).
static func attach(host: Node, move: Callable) -> SlotDrag:
	var d := SlotDrag.new()
	d._move = move
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(d)
	return d

## Registers a slot. `label` names what is in it (shown while carried); "" makes it a drop target only.
func add(c: Control, key: Dictionary, label := "", col := UI.INK) -> void:
	_slots[c] = {"key": key, "label": label, "col": col}
	c.focus_mode = Control.FOCUS_ALL

func carrying() -> bool:
	return not _held.is_empty()

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	_ring = Panel.new()
	_ring.add_theme_stylebox_override("panel", UI.frame(Color(0, 0, 0, 0), 9, Color(UI.INK, 0.85), 2))
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.visible = false
	_layer.add_child(_ring)

func _input(e: InputEvent) -> void:
	var press: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A)
	var eat: bool = press and carrying()      # the release that drops never reaches the slot's own button
	var focus := get_viewport().gui_get_focus_owner()
	if (e is InputEventJoypadButton or e is InputEventJoypadMotion) and focus == null:
		_focus_first()
	elif e is InputEventMouseButton and press:
		_on_button(e.pressed, false, _slot_at(e.position), e.position)
	elif e is InputEventJoypadButton and press:
		_on_button(e.pressed, true, _slot_of(focus), Vector2.ZERO)
	elif e is InputEventMouseMotion:
		if not _press.is_empty() and not _press["pad"] and e.position.distance_to(_press["pos"]) >= MOVE_PX:
			_pick_up()
		if carrying() and not _held["pad"]:
			_preview.position = e.position - _preview.size * 0.5
	if eat:
		get_viewport().set_input_as_handled()

func _on_button(down: bool, pad: bool, at: Control, pos: Vector2) -> void:
	if down:
		if at != null and String(_slots[at]["label"]) != "" and not carrying():
			_press = {"at": at, "t": 0.0, "pos": pos, "pad": pad}
		return
	_press = {}
	if carrying() and _held["pad"] == pad:
		_drop(at)

func _process(dt: float) -> void:
	if not _press.is_empty():
		_press["t"] = float(_press["t"]) + dt
		if float(_press["t"]) >= HOLD_S:
			_pick_up()
	var over: Control = null
	if carrying():
		if _held["pad"]:
			over = _slot_of(get_viewport().gui_get_focus_owner())
		else:
			over = _slot_at(get_viewport().get_mouse_position())
		if _held["pad"] and over != null:
			_preview.position = _rect(over).get_center() + PAD_LIFT
	else:
		var f := _slot_of(get_viewport().gui_get_focus_owner())
		if f != null and not (f is BaseButton):
			over = f      # a slot that draws no focus of its own (the pad needs to see where it is)
	_ring.visible = over != null
	if over != null:
		var r := _rect(over).grow(3.0)
		_ring.position = r.position
		_ring.size = r.size

# ------------------------------------------------------------------ carrying
func _pick_up() -> void:
	var at: Control = _press["at"]
	var pad: bool = _press["pad"]
	_press = {}
	if not is_instance_valid(at):
		return
	_held = {"at": at, "pad": pad}
	var s: Dictionary = _slots[at]
	_preview = UI.card(Color(UI.SURFACE, 0.92), 8, 7)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(UI.label(String(s["label"]), 15, s["col"], UI.semi))
	_layer.add_child(_preview)
	_preview.reset_size()
	_preview.position = get_viewport().get_mouse_position() - _preview.size * 0.5
	if pad:
		_preview.position = _rect(at).get_center() + PAD_LIFT
	Sfx.play("ui_click", null, -10.0)

func _drop(to: Control) -> void:
	var from: Control = _held["at"]
	_held = {}
	if to == null or to == from or not is_instance_valid(from):
		_snap_back(from, "")
		return
	var why := String(_move.call(_slots[from]["key"], _slots[to]["key"]))
	if why != "":
		_snap_back(from, why)
	elif is_instance_valid(_preview):
		_preview.queue_free()

## A refused drop: the thing flies back to its slot and the reason shows beside it for a moment.
func _snap_back(from: Control, why: String) -> void:
	var pv := _preview
	if not is_instance_valid(from):
		pv.queue_free()
		return
	var home := _rect(from).get_center() - pv.size * 0.5
	var tw := pv.create_tween()
	tw.tween_property(pv, "position", home, SNAP_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(pv.queue_free)
	if why == "":
		return
	Sfx.play("ui_deny", null, PressDeny.VOL_DB)
	var hint := UI.card(Color(UI.SURFACE, 0.95), 8, 6)
	hint.name = "drag_hint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(UI.label(why, 13, UI.BAD, UI.semi))
	_layer.add_child(hint)
	hint.reset_size()
	hint.position = Vector2(_rect(from).get_center().x - hint.size.x * 0.5, _rect(from).end.y + 4.0)
	var ht := hint.create_tween()
	ht.tween_interval(HINT_S)
	ht.tween_property(hint, "modulate:a", 0.0, 0.25)
	ht.tween_callback(hint.queue_free)

# ------------------------------------------------------------------ finding slots
## The registered slot `c` is or sits in.
func _slot_of(c: Control) -> Control:
	while c != null:
		if _slots.has(c):
			return c
		c = c.get_parent() as Control
	return null

## The innermost registered slot under a point (one scrolled out of its list is not under anything).
func _slot_at(pos: Vector2) -> Control:
	var best: Control = null
	for c in _slots:
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		var r: Rect2 = _rect(c)
		if r.has_point(pos) and _unclipped(c, pos) and (best == null or r.get_area() < _rect(best).get_area()):
			best = c
	return best

## False when a clipping parent (a scroll list) hides the point of `c`.
static func _unclipped(c: Control, pos: Vector2) -> bool:
	var up := c.get_parent() as Control
	while up != null:
		if up.clip_contents and not _rect(up).has_point(pos):
			return false
		up = up.get_parent() as Control
	return true

## A slot's rect on screen (the layer it sits on may be scaled), in the preview layer's space.
static func _rect(c: Control) -> Rect2:
	var xf := c.get_global_transform_with_canvas()
	return Rect2(xf.origin, c.size * xf.get_scale())

func _focus_first() -> void:
	for c in _slots:
		if is_instance_valid(c) and c.is_visible_in_tree():
			c.grab_focus()
			return
