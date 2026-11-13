class_name CreatorView
extends RefCounted
## The creator's preview controls (hatch.gd, making yourself): drag to turn the model, scroll or the
## Closer button to go from the whole body to the face and back, and Surprise me, a seeded random
## look that one Back undoes.

const TURN_PER_PX := 0.012    # rad of turn per pixel dragged
const ZOOM_STEP := 0.25       # one wheel notch, of the way from the whole body (0) to the face (1)
const ZOOM_RATE := 6.0        # 1/s: how fast the shot eases to the wanted zoom
const FACE_DIST := 1.5        # m: camera to face, fully zoomed in (head and shoulders)
const FACE_UP := 0.12         # m: the face's middle, above the neck pivot
const AIM_ABOVE := 0.1        # m: the close-up aims this far over the face, so it sits below the title
const BODY_CAM := Vector3(0.05, 1.2, 4.75)    # m: the whole body in frame, clear of the card on the left
const BODY_AIM := Vector3(0.2, 0.98, 1.6)

var zoom := 0.0               # the shot now, 0 whole body .. 1 face
var want := 0.0               # the shot it eases to
var before: Dictionary = {}   # the look before the last Surprise me ({} once Back has been used)
var button: Button            # See your face / See all of you, kept in step with the wheel
var _turning := false
var _face := BODY_AIM         # where the face is, measured at rest on each new model
var _aim_off := Vector3.ZERO  # keeps the face where the body stood in frame, right of the card

## Turns and zooms on mouse input; true if it used the event.
func handle(event: InputEvent, model: Node3D) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT: _turning = mb.pressed
			MOUSE_BUTTON_WHEEL_UP: return _nudge(mb.pressed, 1.0)
			MOUSE_BUTTON_WHEEL_DOWN: return _nudge(mb.pressed, -1.0)
	elif event is InputEventMouseMotion and _turning:
		model.rotation.y += (event as InputEventMouseMotion).relative.x * TURN_PER_PX
		return true
	return false

func _nudge(pressed: bool, dir: float) -> bool:
	if pressed:
		want = clampf(want + dir * ZOOM_STEP, 0.0, 1.0)
		_relabel()
	return true

## Closer (to the face) if you're further than halfway, else back to the whole body.
func toggle() -> void:
	want = 1.0 if want < 0.5 else 0.0
	_relabel()

## The zoom button for this creator card, labelled for where it would take you.
func zoom_button() -> Button:
	button = UI.ghost("", toggle, 150)
	_relabel()
	return button

func _relabel() -> void:
	if is_instance_valid(button):
		button.text = "See your face" if want < 0.5 else "See all of you"

## Measures a freshly built model (standing at rest) so the close-up finds its face.
func fit(model: Node3D) -> void:
	var neck := model.find_child("HeadPivot", true, false) as Node3D
	var y := neck.global_position.y + FACE_UP if neck else BODY_AIM.y + 0.6
	var at := model.global_position
	_face = Vector3(at.x, y, at.z)
	_aim_off = (BODY_AIM - Vector3(at.x, BODY_AIM.y, at.z)) * FACE_DIST / BODY_CAM.distance_to(BODY_AIM)

## Eases the shot; the camera's wanted spot and aim for this frame.
func step(delta: float) -> Array:
	zoom = lerpf(zoom, want, minf(1.0, delta * ZOOM_RATE))
	var face_aim := _face + _aim_off + Vector3(0, AIM_ABOVE, 0)
	var face_cam := face_aim + (BODY_CAM - BODY_AIM).normalized() * FACE_DIST
	return [BODY_CAM.lerp(face_cam, zoom), BODY_AIM.lerp(face_aim, zoom)]

## A whole new random look from every row's range, the same one for the same seed. Keeps the keys
## that aren't about the body (the glider). Back undoes it.
func surprise(look: Dictionary, seed_val: int) -> Dictionary:
	before = look.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var out := look.duplicate(true)
	out.merge(Unmasked.random_look(rng), true)
	return out

## The look before the last Surprise me; one step only.
func back() -> Dictionary:
	var out := before
	before = {}
	return out
