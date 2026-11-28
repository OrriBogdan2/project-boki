class_name GroundedRead
extends RefCounted
## What Grounded (KitStatus) looks like on your own bar: the dash slot greys out and the Space hint beside
## you greys out, each with the plate's Grounded icon and a thin ring that empties with the time left. No
## words. The state, its colour and its clock all come from KitStatus through the plate's own status row
## (HudPlate.row), so the bar and the enemy plates show the same thing. docs/HUD.md "Grounded read".

const VEIL := Color(0.16, 0.17, 0.2, 0.72)  # the greyed slot (over the icon, under the ring)
const RING_W := 2.0  # px: the thin time ring
const ICON_K := 0.34  # the status icon's radius as a share of the slot's side
const JUMP_AT := Vector2(-58, -6)  # px from the head: where the Space hint sits (HoldPrompt.air_tap)
const JUMP_R := 15.0  # px: the Space hint's disc
const ICON := "status_grounded"

## host instance id (or "jump") -> what the last draw showed (checks read it): {left, frac}
static var shown := {}


## The Grounded entry of `p`'s status row ({icon, col, left, total, n}), or {} when they are free.
static func item(plates: HudPlate, p: Hunter) -> Dictionary:
	if not KitStatus.grounded(p):
		return {}
	for it in plates.row(p, p, HudPlate.statuses(p)):
		if it["icon"] == ICON:
			return it
	return {}


## The dash slot in `r`: a grey veil, the Grounded icon, a thin ring round the slot's edge.
static func slot(c: CanvasItem, plates: HudPlate, r: Rect2, p: Hunter) -> void:
	var it := item(plates, p)
	if it.is_empty():
		shown.erase("dash")
		return
	c.draw_style_box(HudStyle.box(VEIL, 8, Color(0, 0, 0, 0), 0), r)
	var mid := r.get_center()
	Icons.draw(c, ICON, mid, r.size.x * ICON_K, Color(it["col"], 0.95))
	var frac := _ring(c, mid, r.size.x * 0.5 - RING_W, it)
	shown["dash"] = {"left": float(it["left"]), "frac": frac}


## The Space hint beside `head`: a grey disc and key glyph with the same ring, in place of a tapped Space's
## "Hold" ring while you can't jump or glide.
static func jump(c: CanvasItem, plates: HudPlate, cam: Camera3D, head: Vector3, p: Hunter) -> bool:
	var it := item(plates, p)
	if it.is_empty():
		shown.erase("jump")
		return false
	if cam == null or cam.is_position_behind(head):
		return true
	var at := cam.unproject_position(head) + JUMP_AT
	c.draw_circle(at, JUMP_R, HudStyle.KEY_BG)
	var frac := _ring(c, at, JUMP_R, it)
	Icons.draw(c, ICON, at, JUMP_R * 0.55, Color(it["col"], 0.9))
	shown["jump"] = {"left": float(it["left"]), "frac": frac}
	return true


## The ring: the status's colour, emptying clockwise from the top as the time runs out. Returns what is left (0..1).
static func _ring(c: CanvasItem, at: Vector2, radius: float, it: Dictionary) -> float:
	var frac := clampf(float(it["left"]) / maxf(0.05, float(it["total"])), 0.0, 1.0)
	c.draw_arc(at, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.14), RING_W, true)
	c.draw_arc(at, radius, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, it["col"], RING_W, true)
	return frac
