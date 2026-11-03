class_name DashStrip
extends RefCounted
## The dash charges under your health bar (see Hud._draw_overhead). Per-segment flash state lives on Hud.

## Dash charges as one slim segmented strip tucked under the health bar: a segment per short dash,
## then a shorter pale-blue one for the long dash (when the kit has one). The one recharging fills
## smoothly left to right; a segment that comes back flashes white for a moment.
static func draw(hud, r: Rect2, p: Hunter) -> void:
	var c: Control = hud.c
	var nshort := int(p.max_dashes())
	var has_long := p.ak == null or p.ak.has_long_dash()
	var n := nshort + (1 if has_long else 0)
	var gap := 3.0
	var long_w := 12.0 if has_long else 0.0
	var seg_w := (r.size.x - long_w - gap * float(n - 1)) / float(maxi(1, nshort))
	if hud.dash_seen.size() != n:
		hud.dash_seen.resize(n)
		hud.dash_seen.fill(true)
		hud.dash_flash.resize(n)
		hud.dash_flash.fill(0.0)
	var dt: float = hud.get_process_delta_time()
	var x := r.position.x
	for i in n:
		var is_long := has_long and i == n - 1
		var sw := long_w if is_long else seg_w
		var sr := Rect2(Vector2(x, r.position.y), Vector2(sw, r.size.y))
		var long_fill := clampf(1.0 - p.ex_cd / maxf(0.01, Hunter.EX_DASH_CD), 0.0, 1.0)
		var fill := long_fill if is_long else clampf(p.dashes - float(i), 0.0, 1.0)
		var col: Color = Color("bfe6ff") if is_long else hud.STAMINA_COL
		var full := fill >= 0.999
		if full and not bool(hud.dash_seen[i]):
			hud.dash_flash[i] = 0.28
		hud.dash_seen[i] = full
		hud.dash_flash[i] = maxf(0.0, float(hud.dash_flash[i]) - dt)
		c.draw_rect(sr.grow(1.5), Color(0.03, 0.03, 0.05, 0.82))
		if full:
			c.draw_rect(sr, col)
			c.draw_rect(Rect2(sr.position, Vector2(sw, 1.0)), Color(1, 1, 1, 0.35))
		else:
			c.draw_rect(sr, Color(col, 0.16))
			if fill > 0.0:
				c.draw_rect(Rect2(sr.position, Vector2(sw * fill, r.size.y)), Color(col, 0.6))
				var edge := Rect2(Vector2(sr.position.x + sw * fill - 1.0, sr.position.y), Vector2(1.0, r.size.y))
				c.draw_rect(edge, Color(1, 1, 1, 0.7))
		var fl := float(hud.dash_flash[i]) / 0.28
		if fl > 0.0:
			c.draw_rect(sr.grow(1.0 * fl), Color(1, 1, 1, 0.85 * fl))
		x += sw + gap
