class_name CamWheel
extends RefCounted
## The match camera's zoom range (numbers: content/rules/camera.json "zoom"). CamRig.user_zoom is the wheel's
## factor: it starts at max (spawn and respawn), the mouse wheel steps it in and out between min and max, and
## holding Ctrl (Sneak) eases the view out past max (CamRig.air_zoom asks for `ctrl_zoom`).


static func rules() -> Dictionary:
	return CamRig.RULES["zoom"]


## The wheel's furthest-out factor, where the view starts.
static func far() -> float:
	return float(rules()["max"])


## The factor holding Ctrl reaches: past the wheel's range, wherever the wheel was left.
static func ctrl_zoom() -> float:
	return far() * float(rules()["ctrl"])


## The widest the view goes with the glider and height stacked on the wheel.
static func cap() -> float:
	return float(rules()["cap"])


## The wheel in a match or practice area: true (and handled) when it zoomed.
static func input(m: Match, event: InputEvent) -> bool:
	if not event is InputEventMouseButton or not event.pressed or m.cam == null:
		return false
	var button := (event as InputEventMouseButton).button_index
	if button != MOUSE_BUTTON_WHEEL_UP and button != MOUSE_BUTTON_WHEEL_DOWN:
		return false
	if m.paused or m.over or Overlay.is_open() or _bound(button) or _popup_open(m):
		return false
	var step := float(rules()["step"]) * (-1.0 if button == MOUSE_BUTTON_WHEEL_UP else 1.0)
	m.cam.user_zoom = clampf(m.cam.user_zoom + step, float(rules()["min"]), far())
	m.get_viewport().set_input_as_handled()
	return true


## A panel that has the wheel for itself: the map, the swap and pack lists, the practice hero picker.
static func _popup_open(m: Match) -> bool:
	var practice := Practice.of(m)
	if practice != null and practice.picker != null:
		return true
	return m.hud != null and (m.hud.map_open() or m.hud.swap_open() or m.hud.pack_open())


## Whether the player's Settings put this mouse button on an action (that action wins).
static func _bound(button: int) -> bool:
	for a in InputMap.get_actions():
		for e in InputMap.action_get_events(a):
			if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == button:
				return true
	return false
