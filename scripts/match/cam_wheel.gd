class_name CamWheel
extends RefCounted
## The match camera's zoom range (numbers: content/rules/camera.json "zoom"). CamRig.user_zoom is the wheel's
## factor: it starts at max (spawn and respawn), the mouse wheel steps it in and out between min and max, and
## holding Ctrl (Sneak) eases the view out past max (CamRig.air_zoom asks for `ctrl_zoom`). A first-match hint
## teaches the wheel (hint()).

const HINT := "cam_zoom"  # Save.d["tutorial"] key: the wheel hint was shown or the wheel was used
const HINT_AFTER_S := 8.0  # s into the match before the hint, after the move hint has had its turn


## The zoom rules: the farm's (the default: its camera is untouched) or, with `in_match`, the match's own range.
static func rules(in_match := false) -> Dictionary:
	var r: Dictionary = CamRig.rules["zoom"]
	return r["match"] if in_match else r


## The wheel's furthest-out factor, where the view starts (in a match and on arriving at the farm).
static func far(in_match := false) -> float:
	return float(rules(in_match)["max"])


## The wheel's closest factor.
static func near(in_match := false) -> float:
	return float(rules(in_match)["min"])


## The zoom one notch of `button` moves `z` to (wheel up: in), inside the wheel's range.
static func stepped(z: float, button: int, in_match := false) -> float:
	var step := float(rules(in_match)["step"]) * (-1.0 if button == MOUSE_BUTTON_WHEEL_UP else 1.0)
	return clampf(z + step, near(in_match), far(in_match))


## The wheel button `event` turns: 0 for anything else, or while an Overlay is open or the player's Settings
## put that button on an action (that action wins). The match and the farm both read the wheel here.
static func notch(event: InputEvent) -> int:
	if not event is InputEventMouseButton or not event.pressed:
		return 0
	var button := (event as InputEventMouseButton).button_index
	if button != MOUSE_BUTTON_WHEEL_UP and button != MOUSE_BUTTON_WHEEL_DOWN:
		return 0
	return 0 if Overlay.is_open() or _bound(button) else button


## The factor holding Ctrl reaches: past the wheel's range, wherever the wheel was left.
static func ctrl_zoom(in_match := false) -> float:
	return far(in_match) * float(rules(in_match)["ctrl"])


## The zoom to aim for: the wheel's `base`, or while Ctrl is held on the ground the Ctrl look past it (never
## closer than `base`). The match (CamRig.air_zoom) and the farm both ask here, so they pull out the same.
static func look_zoom(base: float, crouching: bool, in_match := false) -> float:
	return maxf(base, ctrl_zoom(in_match)) if crouching else base


## The widest the view goes with the glider and height stacked on the wheel.
static func cap() -> float:
	return float(rules()["cap"])


## The wheel in a match or practice area: true (and handled) when it zoomed.
static func input(m: Match, event: InputEvent) -> bool:
	var button := notch(event)
	if button == 0 or m.cam == null or m.paused or m.over or _popup_open(m):
		return false
	m.cam.user_zoom = stepped(m.cam.user_zoom, button, true)
	Save.d["tutorial"][HINT] = true  # zoomed: the hint has done its job
	m.get_viewport().set_input_as_handled()
	return true


## The first-match hint for the wheel (Match._tips calls it once the player is on the ground): one line, until
## the wheel has zoomed or the line has shown once. Skipped when the player bound the wheel to an action.
static func hint(m: Match) -> void:
	if _bound(MOUSE_BUTTON_WHEEL_UP) or _bound(MOUSE_BUTTON_WHEEL_DOWN):
		return
	m._tip(HINT, "Mouse wheel zooms the view  ·  hold %s to sneak and see wider" % Settings.key_cap("crouch"))


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
