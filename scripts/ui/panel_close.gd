class_name PanelClose
extends Node
## One closing rule for every menu and panel: Esc (or the pad's B) closes the top one only, a right
## click outside it closes it too, and the press that closed it never reaches the game (a right click
## doesn't also cast, a held button doesn't fire), so play picks up the same frame. UI.scroll_panel
## and UI.confirm attach it; a hand-built card (the Dash's result) calls attach() itself.

## Open panels in the order they opened. The top one is on the highest canvas layer, newest first.
static var _open: Array[PanelClose] = []

var panel: Control
var on_close: Callable

static func attach(p: Control, close: Callable) -> void:
	var pc := PanelClose.new()
	pc.panel = p
	pc.on_close = close
	p.add_child(pc)

static func top() -> PanelClose:
	var best: PanelClose = null
	var best_layer := 0
	for pc in _open:
		if pc.panel.is_queued_for_deletion() or not pc.panel.is_visible_in_tree():
			continue
		var cl := pc.panel.get_canvas_layer_node()
		var layer := cl.layer if cl else 0
		if best == null or layer >= best_layer:
			best = pc
			best_layer = layer
	return best

## Lets go of every action `ev` pressed, so the game never sees the press that closed a menu.
static func release(ev: InputEvent) -> void:
	for a in InputMap.get_actions():
		if ev.is_action(a):
			Input.action_release(a)

func _enter_tree() -> void:
	_open.append(self)

func _exit_tree() -> void:
	_open.erase(self)

## The right click, before anything else sees it (the match would cast with it).
func _input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_RIGHT or top() != self:
		return
	if Overlay.listening != "":
		return      # (a right click being bound to an action in Settings > Controls)
	if not panel.get_global_rect().has_point(panel.get_global_mouse_position()):
		_close(ev)

## Esc and the pad's B, after the screens' own uses of them (a key being rebound, a confirm box).
func _unhandled_input(ev: InputEvent) -> void:
	if top() == self and (ev.is_action_pressed("menu") or ev.is_action_pressed("ui_cancel")):
		_close(ev)

func _close(ev: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	release(ev)
	on_close.call()
