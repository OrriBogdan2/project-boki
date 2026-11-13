class_name ViewZoom
extends RefCounted
## The zoom of a screen that shows your hunter's model (the Relics page, the look-maker, the results): the mouse
## wheel (up zooms in), or on a pad the right stick (up zooms in) and the triggers (right in, left out). Eased, clamped.
## `k` is the distance factor to scale the camera's distance by: 1 is the screen's own framing, under 1 closer.
## Numbers: content/rules/camera.json "zoom"."preview".

const STICK_DEAD := 0.2         # stick/trigger travel ignored below this
var k := 1.0                    # the factor now (eased)
var want := 1.0                 # where the wheel and stick have set it

static func rules() -> Dictionary:
	return CamRig.RULES["zoom"]["preview"]

## A wheel notch. True when it was one (the caller marks the event handled).
func wheel(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton) or not event.pressed:
		return false
	var b := (event as InputEventMouseButton).button_index
	if b != MOUSE_BUTTON_WHEEL_UP and b != MOUSE_BUTTON_WHEEL_DOWN:
		return false
	var r := rules()
	var notch := float(r["step"]) * (-1.0 if b == MOUSE_BUTTON_WHEEL_UP else 1.0)
	want = clampf(want + notch, float(r["min"]), float(r["max"]))
	return true

## Once a frame: the pad, then the ease toward `want`.
func tick(dt: float) -> void:
	var r := rules()
	if Input.get_connected_joypads().size() > 0:
		var tr := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
		pad(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y), tr, dt)
	k = lerpf(k, want, 1.0 - exp(-float(r["ease"]) * dt))

## The pad for `dt` s: right stick y (up, negative, zooms in) and right-minus-left trigger (positive zooms in).
func pad(stick_y: float, trig: float, dt: float) -> void:
	var r := rules()
	var v := _dead(stick_y) - _dead(trig)
	want = clampf(want + v * float(r["pad_rate"]) * dt, float(r["min"]), float(r["max"]))

func _dead(x: float) -> float:
	return x if absf(x) > STICK_DEAD else 0.0
