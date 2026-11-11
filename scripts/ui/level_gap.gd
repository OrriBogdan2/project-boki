class_name LevelGap
extends RefCounted
## How a rival's run level compares with yours, shown on their plate's level badge (HudPlate): warm
## and an up triangle when they are `level_gap` (content/rules/xp.json) or more levels above you,
## cool and a down triangle when that far below, plain within one. The colours are Okabe-Ito
## entries (orange, blue) and the triangle carries the same meaning, so hue is never the only cue.

const WARM := Color("e69f00")    # Okabe-Ito orange: they out-level you
const COOL := Color("0072b2")    # Okabe-Ito blue: you out-level them
const TRI := 4.5                 # px half-width of the triangle cue

## Their level minus yours, signed, for a rival; 0 for yourself, a teammate or no viewer.
static func of(viewer: Hunter, h: Hunter) -> int:
	if viewer == null or h.team == viewer.team:
		return 0
	return h.lvl - viewer.lvl

## +1 warm, -1 cool, 0 plain.
static func band(gap: int) -> int:
	return signi(gap) if absi(gap) >= int(XpRules.rules()["level_gap"]) else 0

static func tint(gap: int) -> Color:
	return WARM if band(gap) > 0 else COOL

## The triangle cue left of the badge `r`: points up for warm, down for cool.
static func draw_cue(c: CanvasItem, r: Rect2, gap: int) -> void:
	var up := band(gap) > 0
	var at := Vector2(r.position.x - TRI - 3.0, r.get_center().y)
	var d := -1.0 if up else 1.0
	var tri := PackedVector2Array([at + Vector2(0, -d * TRI), at + Vector2(-TRI, d * TRI), at + Vector2(TRI, d * TRI)])
	c.draw_colored_polygon(tri, tint(gap))
	c.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), HudStyle.SHADE_EDGE, 1.5, true)
