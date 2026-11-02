class_name HudTip
extends RefCounted
## Where a HUD tooltip goes: above the thing you point at if it fits, otherwise beside it (the side
## with more room), always fully on screen and never covering the slot itself.

const GAP := 14.0      # px between the slot and the tip
const EDGE := 8.0      # px kept clear of the screen edge

static func place(anchor: Rect2, size: Vector2, screen: Vector2) -> Vector2:
	var x := clampf(anchor.get_center().x - size.x * 0.5, EDGE, screen.x - size.x - EDGE)
	if anchor.position.y - size.y - GAP >= EDGE:
		return Vector2(x, anchor.position.y - size.y - GAP)      # above
	var y := clampf(anchor.get_center().y - size.y * 0.5, EDGE, maxf(EDGE, screen.y - size.y - EDGE))
	var right := anchor.end.x + GAP
	var left := anchor.position.x - size.x - GAP
	if screen.x - right - EDGE >= size.x and (left < EDGE or screen.x - anchor.end.x >= anchor.position.x):
		return Vector2(right, y)
	return Vector2(maxf(EDGE, left), y)
