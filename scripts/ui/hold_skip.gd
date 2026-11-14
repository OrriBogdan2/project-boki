class_name HoldSkip
extends Control
## The story player's input: hold to skip, click for next. A tap of any key, mouse button
## or pad button fires `tapped` (the scene moves on one beat); holding one for HOLD_S fires `skipped`.
## It sits in a corner unseen until a press: then a small ring with "Hold to skip" beside it fades in,
## fills while held, and fades away LINGER_S after letting go.
##
##   var hs := HoldSkip.new(); add_child(hs)
##   hs.tapped.connect(...); hs.skipped.connect(...)
##   in _unhandled_input: if hs.feed(event): get_viewport().set_input_as_handled()

signal tapped
signal skipped

const HOLD_S := 1.0        # s held to skip it all
const TAP_S := 0.35        # s: let go sooner and it was a tap; let go later (but short of HOLD_S) and nothing happens
const LINGER_S := 1.5      # s the hint stays up after letting go
const FADE_S := 0.25       # s for the hint to fade in or out
const RING_R := 11.0       # px: the ring's radius
const RING_W := 3.0        # px: its line width
const TEXT := "Hold to skip"
const TEXT_SIZE := 13

var held: InputEvent = null      # the press being held, until its release
var held_s := 0.0
var since_up := LINGER_S         # s since the last release (the hint lingers, then fades)
var done := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RING_R * 2.0 + 110.0, RING_R * 2.0 + 8.0)
	modulate.a = 0.0

## Takes a press or release of a key, mouse button or pad button; true when it used the event.
func feed(event: InputEvent) -> bool:
	var button := event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	if done or not button or event.is_echo():
		return false
	if event.is_pressed():
		if held == null:
			held = event
			held_s = 0.0
		return true
	if held == null or not held.is_match(event):
		return false
	var tap := held_s < TAP_S
	held = null
	since_up = 0.0
	if tap:
		tapped.emit()
	return true

func _process(delta: float) -> void:
	if held != null and not done:
		held_s += delta
		if held_s >= HOLD_S:
			done = true
			held = null
			skipped.emit()
	else:
		since_up += delta
	var up := held != null or done or since_up < LINGER_S
	modulate.a = move_toward(modulate.a, 1.0 if up else 0.0, delta / FADE_S)
	if modulate.a > 0.0:
		queue_redraw()

func _draw() -> void:
	var c := Vector2(RING_R + 2.0, size.y * 0.5)
	var k := 0.0
	if done:
		k = 1.0
	elif held != null:
		k = clampf(held_s / HOLD_S, 0.0, 1.0)
	draw_circle(c, RING_R + 2.0, Color(0, 0, 0, 0.35))
	draw_arc(c, RING_R, 0.0, TAU, 32, Color(1, 1, 1, 0.22), RING_W, true)
	if k > 0.0:
		draw_arc(c, RING_R, -PI / 2.0, -PI / 2.0 + TAU * k, 32, UI.ACCENT, RING_W + 0.5, true)
	var f: Font = UI.semi if UI.semi else UI.body
	draw_string(f, Vector2(c.x + RING_R + 10.0, c.y + TEXT_SIZE * 0.35), TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1,
		TEXT_SIZE, Color(1, 1, 1, 0.8))
