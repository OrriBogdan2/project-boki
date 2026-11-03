class_name UiIcons
extends RefCounted
## The menus' own icon set (tabs, settings, sections, currencies, buttons), drawn with lines and
## shapes so it stays crisp at any interface size. One family: rounded strokes about a fifth of the
## icon's half-size wide, a filled accent where a shape needs weight. UI.draw_icon tries these first,
## then the game's Icons (abilities, items). Every id here is original art.

## Draws icon `id` centred on `at`, `s` px from the centre to the edge, in `col`. False when the
## id isn't one of the menu's own.
static func draw(c: CanvasItem, id: String, at: Vector2, s: float, col: Color) -> bool:
	var w := maxf(1.8, s * 0.22)
	if _marks(c, id, at, s, col, w):
		return true
	if _things(c, id, at, s, col, w):
		return true
	return _settings(c, id, at, s, col, w)

## Simple marks: close, arrows, check, plus, alert, info, lock, eye, sex signs.
static func _marks(c: CanvasItem, id: String, at: Vector2, s: float, col: Color, w: float) -> bool:
	match id:
		"close":
			c.draw_line(at + Vector2(-s, -s) * 0.62, at + Vector2(s, s) * 0.62, col, w, true)
			c.draw_line(at + Vector2(s, -s) * 0.62, at + Vector2(-s, s) * 0.62, col, w, true)
		"back", "next":
			var d := 1.0 if id == "back" else -1.0
			_poly(c, at, s, [[0.3 * d, -0.7], [-0.4 * d, 0.0], [0.3 * d, 0.7]], col, w)
		"play":
			_fill(c, at, s, [[-0.45, -0.75], [0.75, 0.0], [-0.45, 0.75]], col)
		"check":
			_poly(c, at, s, [[-0.7, 0.0], [-0.2, 0.5], [0.7, -0.55]], col, w)
		"plus":
			c.draw_line(at + Vector2(-0.7, 0) * s, at + Vector2(0.7, 0) * s, col, w, true)
			c.draw_line(at + Vector2(0, -0.7) * s, at + Vector2(0, 0.7) * s, col, w, true)
		"alert":
			c.draw_line(at + Vector2(0, -0.78) * s, at + Vector2(0, 0.22) * s, col, w * 1.5, true)
			c.draw_circle(at + Vector2(0, 0.66) * s, w * 0.85, col)
		"info":
			c.draw_arc(at, 0.85 * s, 0, TAU, 24, col, w, true)
			c.draw_circle(at + Vector2(0, -0.42) * s, 0.12 * s, col)
			c.draw_line(at + Vector2(0, -0.12) * s, at + Vector2(0, 0.5) * s, col, w, true)
		"lock":
			c.draw_rect(Rect2(at + Vector2(-0.62, -0.05) * s, Vector2(1.24, 0.9) * s), col)
			c.draw_arc(at + Vector2(0, -0.12) * s, 0.4 * s, PI, TAU, 12, col, w, true)
		"eye":
			c.draw_arc(at + Vector2(0, 0.55) * s, 0.95 * s, -PI * 0.78, -PI * 0.22, 14, col, w, true)
			c.draw_arc(at + Vector2(0, -0.55) * s, 0.95 * s, PI * 0.22, PI * 0.78, 14, col, w, true)
			c.draw_circle(at, 0.28 * s, col)
		"female":
			c.draw_arc(at + Vector2(0, -0.28) * s, 0.46 * s, 0, TAU, 20, col, w, true)
			c.draw_line(at + Vector2(0, 0.18) * s, at + Vector2(0, 0.95) * s, col, w, true)
			c.draw_line(at + Vector2(-0.32, 0.6) * s, at + Vector2(0.32, 0.6) * s, col, w, true)
		"male":
			c.draw_arc(at + Vector2(-0.22, 0.22) * s, 0.46 * s, 0, TAU, 20, col, w, true)
			c.draw_line(at + Vector2(0.11, -0.11) * s, at + Vector2(0.78, -0.78) * s, col, w, true)
			_poly(c, at, s, [[0.28, -0.8], [0.8, -0.8], [0.8, -0.28]], col, w)
		_:
			return false
	return true

## Things: home, bag, shop, portal, hammer, ruler, pin, gear, the armory's and the market's tabs,
## currencies and the section emblems.
static func _things(c: CanvasItem, id: String, at: Vector2, s: float, col: Color, w: float) -> bool:
	match id:
		"home":
			_fill(c, at, s, [[0, -0.85], [0.85, -0.05], [0.6, -0.05], [0.6, 0.75], [-0.6, 0.75], [-0.6, -0.05],
				[-0.85, -0.05]], col)
		"bag":
			c.draw_rect(Rect2(at + Vector2(-0.7, -0.35) * s, Vector2(1.4, 1.1) * s), col)
			c.draw_arc(at + Vector2(0, -0.35) * s, 0.36 * s, PI, TAU, 12, col, w, true)
		"shop":
			_fill(c, at, s, [[-0.85, -0.2], [-0.6, -0.75], [0.6, -0.75], [0.85, -0.2]], col)
			c.draw_rect(Rect2(at + Vector2(-0.68, -0.1) * s, Vector2(1.36, 0.85) * s), Color(col, col.a * 0.75))
		"portal":
			c.draw_arc(at, 0.78 * s, 0, TAU, 24, col, w, true)
			c.draw_arc(at, 0.42 * s, 0, TAU, 18, Color(col, col.a * 0.7), w, true)
		"hammer":
			c.draw_line(at + Vector2(-0.6, 0.75) * s, at + Vector2(0.25, -0.15) * s, col, w * 1.4, true)
			_fill(c, at, s, [[-0.05, -0.75], [0.75, 0.05], [0.45, 0.35], [-0.35, -0.45]], col)
		"ruler":
			c.draw_line(at + Vector2(-0.85, 0.45) * s, at + Vector2(0.45, -0.85) * s, col, w * 2.2, true)
			for k in 4:
				var p0 := at + Vector2(-0.6 + k * 0.3, 0.2 - k * 0.3) * s
				c.draw_line(p0, p0 + Vector2(0.18, 0.18) * s, Color(0, 0, 0, 0.5), maxf(1.0, w * 0.6), true)
		"pin":
			c.draw_circle(at + Vector2(0, -0.3) * s, 0.5 * s, col)
			_fill(c, at, s, [[-0.42, -0.05], [0.42, -0.05], [0, 0.9]], col)
			c.draw_circle(at + Vector2(0, -0.3) * s, 0.2 * s, Color(0, 0, 0, 0.45))
		"gear":
			c.draw_arc(at, 0.5 * s, 0, TAU, 20, col, w, true)
			for i in 8:
				var dir := Vector2.from_angle(TAU * i / 8.0)
				c.draw_line(at + dir * 0.6 * s, at + dir * 0.95 * s, col, w * 1.3, true)
			c.draw_circle(at, 0.18 * s, col)
		"shield":
			_fill(c, at, s, [[-0.72, -0.62], [0, -0.9], [0.72, -0.62], [0.62, 0.15], [0, 0.9], [-0.62, 0.15]], col)
			_poly(c, at, s, [[0, -0.6], [0, 0.55]], Color(0, 0, 0, 0.35), w * 0.8)
		"boot":
			_fill(c, at, s, [[-0.45, -0.85], [0.15, -0.85], [0.15, 0.2], [0.85, 0.42], [0.85, 0.8], [-0.45, 0.8]], col)
			_poly(c, at, s, [[-0.45, -0.35], [0.15, -0.35]], Color(0, 0, 0, 0.35), w * 0.8)
		"glove":
			c.draw_rect(Rect2(at + Vector2(-0.55, -0.1) * s, Vector2(1.05, 0.95) * s), col)
			for k in 4:
				var fx_x := -0.5 + k * 0.27
				var tip := Vector2(fx_x + 0.1, -0.78 + absf(k - 1.5) * 0.12)
				c.draw_line(at + Vector2(fx_x + 0.1, -0.1) * s, at + tip * s, col, w * 1.15, true)
			c.draw_line(at + Vector2(0.5, 0.2) * s, at + Vector2(0.85, -0.25) * s, col, w * 1.15, true)
		"kit":
			c.draw_rect(Rect2(at + Vector2(-0.8, -0.45) * s, Vector2(1.6, 1.2) * s), col)
			c.draw_rect(Rect2(at + Vector2(-0.3, -0.75) * s, Vector2(0.6, 0.3) * s), col, false, w * 0.8)
			c.draw_line(at + Vector2(0, -0.1) * s, at + Vector2(0, 0.45) * s, Color(0, 0, 0, 0.45), w, true)
			c.draw_line(at + Vector2(-0.28, 0.18) * s, at + Vector2(0.28, 0.18) * s, Color(0, 0, 0, 0.45), w, true)
		"chest":
			c.draw_rect(Rect2(at + Vector2(-0.82, -0.1) * s, Vector2(1.64, 0.85) * s), col)
			c.draw_arc(at + Vector2(0, -0.1) * s, 0.82 * s, PI, TAU, 16, col, w * 1.6, true)
			c.draw_rect(Rect2(at + Vector2(-0.14, -0.2) * s, Vector2(0.28, 0.36) * s), Color(0, 0, 0, 0.45))
		"coin":
			c.draw_circle(at, 0.82 * s, col)
			c.draw_arc(at, 0.56 * s, 0, TAU, 20, Color(0, 0, 0, 0.35), w * 0.8, true)
			_fill(c, at, s * 0.5, [[0, -0.8], [0.5, 0], [0, 0.8], [-0.5, 0]], Color(0, 0, 0, 0.35))
		"sprout":
			c.draw_line(at + Vector2(0, 0.85) * s, at + Vector2(0, -0.1) * s, col, w, true)
			_fill(c, at, s, [[0, -0.05], [-0.35, -0.55], [-0.85, -0.6], [-0.6, -0.15]], col)
			_fill(c, at, s, [[0, -0.2], [0.3, -0.75], [0.85, -0.85], [0.6, -0.3]], col)
		"bowl":
			c.draw_arc(at + Vector2(0, -0.15) * s, 0.8 * s, 0, PI, 16, col, w * 1.5, true)
			c.draw_line(at + Vector2(-0.9, -0.15) * s, at + Vector2(0.9, -0.15) * s, col, w, true)
			for k in 3:
				var sx := -0.35 + k * 0.35
				var steam := Color(col, col.a * 0.7)
				c.draw_arc(at + Vector2(sx, -0.62) * s, 0.15 * s, PI * 0.5, PI * 1.5, 6, steam, w * 0.7, true)
		"hat":
			_fill(c, at, s, [[-0.5, 0.2], [-0.35, -0.6], [0.35, -0.6], [0.5, 0.2]], col)
			c.draw_line(at + Vector2(-0.9, 0.35) * s, at + Vector2(0.9, 0.35) * s, col, w * 1.4, true)
		"book":
			c.draw_rect(Rect2(at + Vector2(-0.75, -0.8) * s, Vector2(1.5, 1.6) * s), col)
			c.draw_line(at + Vector2(-0.45, -0.8) * s, at + Vector2(-0.45, 0.8) * s, Color(0, 0, 0, 0.4), w * 0.7, true)
			var ink := Color(0, 0, 0, 0.4)
			c.draw_line(at + Vector2(-0.15, -0.35) * s, at + Vector2(0.5, -0.35) * s, ink, w * 0.6, true)
		"compass":
			c.draw_arc(at, 0.86 * s, 0, TAU, 24, col, w, true)
			_fill(c, at, s, [[0, -0.62], [0.2, 0], [0, 0.62], [-0.2, 0]], col)
		_:
			return false
	return true

## The settings tabs: pad, camera, speaker, monitor, accessibility, film.
static func _settings(c: CanvasItem, id: String, at: Vector2, s: float, col: Color, w: float) -> bool:
	match id:
		"pad":
			var body := PackedVector2Array()
			for p in [[-0.9, -0.1], [-0.7, -0.5], [0.7, -0.5], [0.9, -0.1], [0.8, 0.55], [0.45, 0.6], [0.25, 0.25],
					[-0.25, 0.25], [-0.45, 0.6], [-0.8, 0.55]]:
				body.append(at + Vector2(p[0], p[1]) * s)
			c.draw_colored_polygon(body, col)
			var hole := Color(0, 0, 0, 0.45)
			c.draw_line(at + Vector2(-0.6, -0.12) * s, at + Vector2(-0.24, -0.12) * s, hole, w * 0.7, true)
			c.draw_line(at + Vector2(-0.42, -0.3) * s, at + Vector2(-0.42, 0.06) * s, hole, w * 0.7, true)
			c.draw_circle(at + Vector2(0.4, -0.2) * s, 0.1 * s, hole)
			c.draw_circle(at + Vector2(0.55, 0.0) * s, 0.1 * s, hole)
		"camera":
			c.draw_rect(Rect2(at + Vector2(-0.85, -0.45) * s, Vector2(1.7, 1.15) * s), col)
			c.draw_rect(Rect2(at + Vector2(-0.35, -0.7) * s, Vector2(0.7, 0.3) * s), col)
			c.draw_circle(at + Vector2(0, 0.12) * s, 0.38 * s, Color(0, 0, 0, 0.45))
			c.draw_circle(at + Vector2(0, 0.12) * s, 0.2 * s, col)
		"speaker":
			_fill(c, at, s, [[-0.85, -0.3], [-0.45, -0.3], [0.05, -0.75], [0.05, 0.75], [-0.45, 0.3],
				[-0.85, 0.3]], col)
			c.draw_arc(at + Vector2(0.1, 0) * s, 0.4 * s, -PI * 0.3, PI * 0.3, 8, col, w * 0.9, true)
			c.draw_arc(at + Vector2(0.1, 0) * s, 0.72 * s, -PI * 0.3, PI * 0.3, 10, col, w * 0.9, true)
		"monitor":
			c.draw_rect(Rect2(at + Vector2(-0.88, -0.7) * s, Vector2(1.76, 1.1) * s), col, false, w)
			c.draw_line(at + Vector2(0, 0.42) * s, at + Vector2(0, 0.72) * s, col, w, true)
			c.draw_line(at + Vector2(-0.42, 0.78) * s, at + Vector2(0.42, 0.78) * s, col, w, true)
		"access":
			c.draw_arc(at, 0.88 * s, 0, TAU, 24, col, w * 0.8, true)
			c.draw_circle(at + Vector2(0, -0.48) * s, 0.15 * s, col)
			c.draw_line(at + Vector2(-0.5, -0.22) * s, at + Vector2(0.5, -0.22) * s, col, w * 0.9, true)
			_poly(c, at, s, [[-0.3, 0.6], [0, 0.0], [0.3, 0.6]], col, w * 0.9)
			c.draw_line(at + Vector2(0, -0.22) * s, at + Vector2(0, 0.05) * s, col, w * 0.9, true)
		"film":
			c.draw_rect(Rect2(at + Vector2(-0.8, -0.6) * s, Vector2(1.6, 1.2) * s), col)
			for k in 4:
				var fx_x := -0.6 + k * 0.4
				c.draw_rect(Rect2(at + Vector2(fx_x - 0.07, -0.5) * s, Vector2(0.14, 0.14) * s), Color(0, 0, 0, 0.45))
				c.draw_rect(Rect2(at + Vector2(fx_x - 0.07, 0.36) * s, Vector2(0.14, 0.14) * s), Color(0, 0, 0, 0.45))
		_:
			return false
	return true

## A filled polygon from unit points (scaled by s around at).
static func _fill(c: CanvasItem, at: Vector2, s: float, pts: Array, col: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(at + Vector2(p[0], p[1]) * s)
	c.draw_colored_polygon(out, col)

## A stroked polyline from unit points.
static func _poly(c: CanvasItem, at: Vector2, s: float, pts: Array, col: Color, w: float) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(at + Vector2(p[0], p[1]) * s)
	c.draw_polyline(out, col, w, true)
