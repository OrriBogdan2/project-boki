class_name HomeCrouchLook
extends RefCounted
## Holding crouch (Ctrl, Settings "crouch") at home pulls the camera out to look further, the same as in a match:
## the target zoom is CamWheel.look_zoom, the one rule CamRig.air_zoom uses, and CamRig.follow eases it in and
## out at the match's own rate. The zoom you had (the wheel's) is kept and comes back on release.

var base := -1.0  # the zoom before the look (-1: not looking)
var set_to := 0.0  # what the look put on the camera: if something else moved it since, it keeps that


## Once a frame, after the walk has set crouching: `crouching` is the farm's crouch state (on the ground), `free`
## whether you are walking (no panel, talk or build mode, which set the camera themselves).
func tick(cam: CamRig, crouching: bool, free: bool) -> void:
	var on := crouching and free
	if on and base < 0.0:
		base = cam.zoom_to
	if base < 0.0:
		return
	if on:
		set_to = CamWheel.look_zoom(base, true)
		cam.zoom_to = set_to
	else:
		if is_equal_approx(cam.zoom_to, set_to):
			cam.zoom_to = base
		base = -1.0


## The mouse wheel while looking changes the zoom you come back to, not the look. True when it did.
func wheel(step: float) -> bool:
	if base < 0.0:
		return false
	base = clampf(base + step, 0.55, 1.6)
	return true
