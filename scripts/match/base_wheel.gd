class_name BaseWheel
extends RefCounted
## The B wheel: hold B and a ring of slices opens round the cursor, one per teammate still in the match
## (portrait and name; greyed when they can't take you). Move the mouse or the right stick toward one and
## let go to start basing to them (BaseRecall); let go in the middle and nothing happens. One teammate
## left: the wheel still shows them, as one whole ring. Like the G wheel (KinWheel, whose pick, dead zone,
## pop and size it shares) it is a plain overlay: the game keeps running. State lives on h.inp["bwheel"]
## (local UI); the pick waits in h.inp["base_pick"] until apply_pick runs on the fixed step.

const STICK_DEAD := 0.5       # right-stick tilt (0..1) that counts as pointing at a slice


static func is_open(h: Hunter) -> bool:
	return h.inp.has("bwheel")


## The direction of slice `i` of `n` on screen: the first straight up, the rest clockwise.
static func dir(i: int, n: int) -> Vector2:
	return Vector2.UP.rotated(TAU * float(i) / float(maxi(1, n)))


## Polls B every frame for the local player. `blocked`: paused, a duel or the Arena (B does nothing).
static func poll(h: Hunter, dt: float, blocked: bool) -> void:
	var down := Input.is_action_pressed("base") and not blocked
	if down and not is_open(h):
		var mates := BaseRecall.mates(h.m, h)
		if mates.is_empty():
			if Input.is_action_just_pressed("base"):
				BaseRecall.start(h, null)       # solo: the "no teammate" toast
			return
		open(h, h.get_viewport().get_mouse_position(), mates)
	if not is_open(h):
		return
	if down:
		update(h, h.get_viewport().get_mouse_position() + _stick(), dt)
		h.inp["fire"] = false       # a pick is not a shot
	else:
		var to := close(h)
		if to != null:
			h.inp["base_pick"] = to


static func open(h: Hunter, mouse: Vector2, mates: Array) -> void:
	h.inp["bwheel"] = {"o": mouse, "sel": -1, "t": 0.0, "mates": mates}


static func update(h: Hunter, mouse: Vector2, dt: float) -> void:
	var w: Dictionary = h.inp["bwheel"]
	w["t"] = float(w["t"]) + dt
	var n: int = (w["mates"] as Array).size()
	var dirs: Array = []
	for i in n:
		dirs.append(dir(i, n))
	w["sel"] = KinWheel.nearest(mouse - (w["o"] as Vector2), dirs)


## Closes the wheel. Returns the teammate picked (null: let go in the middle, or on one who can't take you).
static func close(h: Hunter) -> Hunter:
	var w: Dictionary = h.inp.get("bwheel", {})
	h.inp.erase("bwheel")
	var sel := int(w.get("sel", -1))
	if sel < 0:
		return null
	var o: Hunter = (w["mates"] as Array)[sel]
	if not BaseRecall.can_take(h, o):
		h._ab_feedback("base", "deny")
		return null
	return o


## On the fixed step: starts the channel to the teammate picked on the wheel, if any.
static func apply_pick(h: Hunter) -> void:
	if h.inp.has("base_pick"):
		BaseRecall.start(h, h.inp["base_pick"])
		h.inp.erase("base_pick")


## The right stick as a flick of the wheel's size (zero when no pad or it's resting).
static func _stick() -> Vector2:
	if Input.get_connected_joypads().is_empty():
		return Vector2.ZERO
	var s := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	return s * float(KinWheel.rules()["radius_px"]) if s.length() > STICK_DEAD else Vector2.ZERO
