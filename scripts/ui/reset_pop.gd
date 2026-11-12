class_name ResetPop
extends RefCounted
## The HUD pop on an ability slot that just came back (the Shift icon after a takedown reset): the icon
## swells and settles, a ring expands off it and four sparkle ticks fly out. Pure drawing, driven by the
## slot's slot_fx time t (0 to LEN seconds); Hud._ab_slot calls scaled() and draw().

const LEN := 0.55            # seconds the pop lasts (the HUD keeps the slot_fx entry this long)
const FLASH := 0.7           # the white over the slot as it pops (0.28 with reduced flashes)

## The slot's rect swelling to 1.18x in the first 90 ms, then settling back.
static func scaled(r: Rect2, t: float) -> Rect2:
	var k := 0.18 * (t / 0.09 if t < 0.09 else maxf(0.0, 1.0 - (t - 0.09) / 0.25))
	return r.grow(r.size.x * k * 0.5)

static func draw(c: CanvasItem, r: Rect2, col: Color, t: float) -> void:
	var k := clampf(t / LEN, 0.0, 1.0)
	var bright := col.lerp(Color.WHITE, 0.6)
	var ctr := r.get_center()
	var fade := 1.0 - k
	var calm: bool = Settings.get_v("reduce_flashes")
	c.draw_rect(Rect2(r.position, r.size), Color(1, 1, 1, (0.28 if calm else FLASH) * fade * fade), true)
	if calm:
		return
	c.draw_arc(ctr, r.size.x * (0.55 + 0.7 * k), 0.0, TAU, 40, Color(bright, fade), 3.0 * fade + 1.0, true)
	for i in 4:
		var a := PI * 0.25 + float(i) * PI * 0.5
		var d := Vector2(cos(a), sin(a))
		c.draw_line(ctr + d * r.size.x * (0.62 + 0.55 * k), ctr + d * r.size.x * (0.74 + 0.8 * k), Color(1, 1, 1, fade), 2.0, true)
