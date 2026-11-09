class_name InvTip
extends Node
## The hover tooltip of an item window (backpack, deathbox): point at a thing and a card appears
## beside the window with [[text, colour, size?]] lines, the first one being the title. It lives under
## the window it serves, so it goes when the window does. Compare lines come from InvText.

const WIDTH := 300.0
const GAP := 10.0          # px between the window and the card
const EDGE := 8.0          # px kept clear of the screen edge
const TIP_FONT := 13
const TITLE_FONT := 17

var _window: Control
var _card: PanelContainer
var _owner_ctrl: Control

func _init(window: Control) -> void:
	_window = window

## Shows `lines_of.call()` while the pointer is over `ctrl`. `on_enter` / `on_exit` are optional hooks.
func attach(ctrl: Control, lines_of: Callable, on_enter := Callable(), on_exit := Callable()) -> void:
	ctrl.mouse_entered.connect(func():
		_show(ctrl, lines_of.call())
		if on_enter.is_valid():
			on_enter.call())
	ctrl.mouse_exited.connect(func():
		if is_instance_valid(ctrl) and ctrl.get_global_rect().has_point(ctrl.get_global_mouse_position()):
			return      # the pointer only moved onto a button inside it
		_hide(ctrl)
		if on_exit.is_valid():
			on_exit.call())

## Shows a card for `ctrl` at once (the screenshot tool uses it).
func show_for(ctrl: Control, lines: Array) -> void:
	_show(ctrl, lines)

func _show(ctrl: Control, lines: Array) -> void:
	_hide(null)
	if lines.is_empty() or not is_instance_valid(ctrl):
		return
	_owner_ctrl = ctrl
	var col: Color = lines[0][1]
	var pc := PanelContainer.new()
	pc.theme = UI.theme()
	pc.top_level = true
	pc.z_index = 50
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.96)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(col, 0.7)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size.x = WIDTH
	var v := UI.vbox(3)
	pc.add_child(v)
	for i in lines.size():
		var ln: Array = lines[i]
		var font_size: int = int(ln[2]) if ln.size() > 2 else TIP_FONT
		var l := UI.label(String(ln[0]), font_size, ln[1])
		if i == 0:
			l.add_theme_font_override("font", UI.big)
			l.add_theme_font_size_override("font_size", TITLE_FONT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	for ctrl_in_card in pc.find_children("*", "Control", true, false):
		(ctrl_in_card as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE      # a card never catches the pointer
	pc.modulate.a = 0.0
	_card = pc
	add_child(pc)
	_place.call_deferred(pc, ctrl)

## Beside the window (the left when there is room), level with the thing pointed at.
func _place(pc: PanelContainer, ctrl: Control) -> void:
	if not is_instance_valid(pc) or not is_instance_valid(ctrl) or not is_instance_valid(_window):
		return
	pc.reset_size()
	var screen := pc.get_viewport_rect().size
	var win := _window.get_global_rect()
	var x := win.position.x - pc.size.x - GAP
	if x < EDGE:
		x = minf(win.end.x + GAP, screen.x - pc.size.x - EDGE)
	var y := clampf(ctrl.get_global_rect().position.y, EDGE, maxf(EDGE, screen.y - pc.size.y - EDGE))
	pc.global_position = Vector2(x, y)
	pc.modulate.a = 1.0

func _hide(ctrl) -> void:
	if ctrl != null and ctrl != _owner_ctrl:
		return      # a stale exit from a thing that is no longer the one shown
	if _card and is_instance_valid(_card):
		_card.queue_free()
	_card = null
	_owner_ctrl = null
