class_name OutpostGlyph
extends RefCounted
## An outpost on the minimap and the full map: the structure itself seen from above, a stone footing, a mast
## with a banner and a beacon on top. The banner takes the holder's team colour, the beacon fills with the
## charge (a ring around it while it charges), the rest is the exit colour (grey when it can't be used).

## Draws it centred at `pv`, scaled by `k`. `flag`: the banner colour (grey = nobody holds it), `lit`: 0..1 charge.
static func draw(c: CanvasItem, pv: Vector2, k: float, col: Color, flag: Color, lit: float) -> void:
	var dark := Color(0, 0, 0, 0.7)
	var foot := Rect2(pv + Vector2(-4.5, 3.0) * k, Vector2(9.0, 3.5) * k)
	var top := pv + Vector2(0, -6.0) * k
	c.draw_rect(foot.grow(1.5), dark)
	c.draw_line(pv + Vector2(0, 3.5) * k, top, dark, 4.0 * k)
	c.draw_rect(foot, col)
	c.draw_line(pv + Vector2(0, 3.5) * k, top, col, 2.0 * k)
	var banner := PackedVector2Array([top + Vector2(1, 0) * k, top + Vector2(7, 2.5) * k, top + Vector2(1, 5) * k])
	c.draw_colored_polygon(banner, flag)
	c.draw_circle(top + Vector2(0, -2.5) * k, 2.4 * k, dark)
	c.draw_circle(top + Vector2(0, -2.5) * k, 1.8 * k, Color(col, 0.25 + 0.75 * clampf(lit, 0.0, 1.0)))
