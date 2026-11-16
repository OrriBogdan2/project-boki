class_name HomeKinFrame
extends RefCounted
## The garden camera leans in on a Boki you're with. Pet it, feed it, toss it a ball or open its card and
## the view eases CLOSER nearer and frames you both over EASE_S; it eases back when you walk off, the
## Boki is too far to fit on screen with you, or (opened by its card) the card closes. Home only: a match
## never ticks it.

const CLOSER := 0.3        # fraction of the camera's distance taken off at full frame (0.3: 30% nearer)
const EASE_S := 0.3        # s to ease in, and again to ease back
const WALK_OFF_M := 2.5    # m you move from where you started with it that counts as walking off
## m apart still framed together, per unit of camera zoom (the home's 1.2: 8.4 m): both of you stay on
## screen at every wheel zoom (--cam-framing-check)
const REACH := 7.0

var kin: Dictionary = {}   # the farm's kin entry being framed (empty: none)
var by_card := false       # framed by opening its card: closing the card lets go
var since := Vector3.ZERO  # where you stood when it started
var at := Vector3.ZERO     # the Boki's last framed spot (kept, so the ease back doesn't jump)
var amt := 0.0             # 0 = the usual view, 1 = fully framed (linear; eased() curves it)

## Called by the paths that pet, feed, toss to or open the card of a farm Boki; `k` may be empty.
## (Too far to frame: the next tick lets go before the view moves.)
func start(k: Dictionary, you: Vector3, card := false) -> void:
	if k.is_empty():
		return
	kin = k
	by_card = card
	since = you
	at = k["pos"]

## `zoom`: the camera's zoom (CamRig.zoom_to), which sets how far apart the two of you still fit.
func tick(d: float, you: Vector3, panel_open: bool, zoom: float) -> void:
	if not kin.is_empty():
		if not is_instance_valid(kin["node"]):
			kin = {}
		else:
			at = kin["pos"]
			var gone := _flat(you, since) > WALK_OFF_M or _flat(at, you) > REACH * zoom
			if gone or (by_card and not panel_open):
				kin = {}
	amt = move_toward(amt, 0.0 if kin.is_empty() else 1.0, d / EASE_S)

func eased() -> float:
	return smoothstep(0.0, 1.0, amt)

## True while the view is (or is still easing back from) framing a Boki.
func framing() -> bool:
	return amt > 0.0

## The camera's distance multiplier for this frame.
func closer() -> float:
	return 1.0 - CLOSER * eased()

## The point to follow: you, moved toward the middle of you and the Boki.
func frame(focus: Vector3) -> Vector3:
	var mid := Vector3((focus.x + at.x) * 0.5, focus.y, (focus.z + at.z) * 0.5)
	return focus.lerp(mid, eased())

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
