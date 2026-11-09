class_name CreatorCam
extends RefCounted
## The creator's camera: fixed on the whole body, and the mouse wheel zooms in to the face (zoom 0 to 1).
## The model stands right of the card, so both shots keep it in the free part of the screen.

const FAR_CAM := Vector3(0.05, 1.2, 4.75)      # m: the whole body in frame
const FAR_LOOK := Vector3(0.2, 0.98, 1.6)
const NEAR_CAM := Vector3(0.45, 1.62, 3.05)    # m: the face fills the frame
const NEAR_LOOK := Vector3(0.5, 1.58, 1.6)
const HEAD_Y := 1.6                            # m: eye height of an average hunter (taller ones scale it)
const WHEEL_STEP := 0.15                       # zoom per wheel notch

## Where the camera stands at this zoom, for a hunter this tall (Unmasked.HEIGHT_SCALE).
static func cam_pos(zoom: float, height_scale: float) -> Vector3:
	return FAR_CAM.lerp(NEAR_CAM, zoom) + Vector3(0, (height_scale - 1.0) * HEAD_Y * zoom, 0)

## What it looks at.
static func focus(zoom: float, height_scale: float) -> Vector3:
	return FAR_LOOK.lerp(NEAR_LOOK, zoom) + Vector3(0, (height_scale - 1.0) * HEAD_Y * zoom, 0)

## The zoom after this input event: a wheel notch up zooms in, down zooms out.
static func wheel(zoom: float, event: InputEvent) -> float:
	if not (event is InputEventMouseButton and event.pressed):
		return zoom
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP: return minf(1.0, zoom + WHEEL_STEP)
		MOUSE_BUTTON_WHEEL_DOWN: return maxf(0.0, zoom - WHEEL_STEP)
	return zoom
