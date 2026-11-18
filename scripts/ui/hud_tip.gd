class_name HudTip
extends RefCounted
## Where a HUD tooltip goes: above the thing you point at if it fits, otherwise beside it (the side
## with more room), always inside the safe area (HudStyle.safe_rect) and never covering the slot itself.

const GAP := 14.0      # px between the slot and the tip

static func place(anchor: Rect2, size: Vector2, screen: Vector2) -> Vector2:
	var safe := HudStyle.safe_rect(screen)
	var x := clampf(anchor.get_center().x - size.x * 0.5, safe.position.x, maxf(safe.position.x, safe.end.x - size.x))
	if anchor.position.y - size.y - GAP >= safe.position.y:
		return Vector2(x, anchor.position.y - size.y - GAP)      # above
	var y := clampf(anchor.get_center().y - size.y * 0.5, safe.position.y, maxf(safe.position.y, safe.end.y - size.y))
	var right := anchor.end.x + GAP
	var left := anchor.position.x - size.x - GAP
	if safe.end.x - right >= size.x and (left < safe.position.x or screen.x - anchor.end.x >= anchor.position.x):
		return Vector2(right, y)
	return Vector2(maxf(safe.position.x, left), y)
