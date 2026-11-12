class_name CamWheel
extends RefCounted
## The match camera's zoom range and what widens the view, in one place (numbers: content/rules/camera.json "zoom").
## The mouse wheel sets CamRig.user_zoom between "min" and "max". Gliding and sneaking (hold Ctrl) widen the view on
## top of it, and sneaking always reaches past the wheel's max; CamRig eases back when they end. An aimed cast
## widens in CamRig.cast_wide (Vex's Longneedle, the only ability that does). The wheel is bound to nothing else in
## a match, and where the player left it is kept (Settings "cam_zoom"); if a player binds it to an action in
## Settings, that action wins and the wheel stops zooming.

static func rules() -> Dictionary:
	return CamRig.RULES["zoom"]

## The wheel in a match. True when it zoomed (the caller marks the event handled).
static func input(m: Match, event: InputEvent) -> bool:
	if not (event is InputEventMouseButton) or not event.pressed:
		return false
	if m.cam == null or m.paused or m.over or Overlay.is_open():
		return false
	var button := (event as InputEventMouseButton).button_index
	var step := 0.0
	match button:
		MOUSE_BUTTON_WHEEL_UP: step = -1.0
		MOUSE_BUTTON_WHEEL_DOWN: step = 1.0
		_: return false
	var popup: bool = m.hud != null and (m.hud.map_open() or m.hud.swap_open() or m.hud.pack_open())
	if popup or _bound(button):
		return false
	var r: Dictionary = rules()["match"]
	m.cam.user_zoom = clampf(m.cam.user_zoom + step * float(r["step"]), float(r["min"]), float(r["max"]))
	Settings.set_v("cam_zoom", m.cam.user_zoom, false)
	return true

## The zoom a match starts at: where the player left the wheel (Settings "cam_zoom"), inside the range; until
## they first turn it, the widest for an expedition (`host` is its Match) and the style's own framing elsewhere.
static func saved(host: Node) -> float:
	var r: Dictionary = rules()["match"]
	var z := float(Settings.get_v("cam_zoom"))
	if z <= 0.0:
		z = float(r["max"]) if host is Match and Prematch.expedition((host as Match).opts) else 1.0
	return clampf(z, float(r["min"]), float(r["max"]))

## Whether a player's Settings put this mouse button on an action.
static func _bound(button: int) -> bool:
	for a in InputMap.get_actions():
		for e in InputMap.action_get_events(a):
			if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == button:
				return true
	return false

## The widening for what the player is doing (1 = none): gliding, or sneaking on the ground.
static func widen(p: Hunter) -> float:
	var w: Dictionary = rules()["widen"]
	if p.gliding:
		return float(w["glide"])
	return float(w["ctrl"]) if p.crouch and p.grounded else 1.0

## The camera zoom for a base zoom: the wheel's factor on top, and sneaking never less than "ctrl_floor" x the max.
static func final(base: float, user_zoom: float, p: Hunter) -> float:
	var z := base * user_zoom
	if p.crouch and p.grounded and not p.gliding:
		z = maxf(z, float(rules()["match"]["max"]) * float(rules()["widen"]["ctrl_floor"]))
	return z
