class_name ReticleLooks
extends RefCounted
## Each Hunter's own reticle: the strokes of the "default" shape (Reticle) in a small motif of its own, set by
## content/archetypes/<id>.json "reticle". Every look reaches at most 3 px (at size 1) past the default ring, well
## inside the ammo arc, opens with bloom like it (`ring` already holds the spread) and is made only of strokes, so the
## outline pass draws the same strokes wider in dark and reads as a thin edge.

## Look id -> what it shows (and whose it is).
const LOOKS := {
	"stitch": "Lace: six slanted stitches of thread",
	"shackle": "Kael: two heavy shackle arcs and an ember blade tick on top",
	"coin": "Vex: a whole coin rim with four scope ticks inside",
	"aegis": "Albert: a flat-topped hexagon, his aegis plate",
	"frost": "Neve: six snowflake spokes",
	"flame": "Cinder: the alchemist's fire triangle",
	"rune": "Tenzo: a rune ring of three stones with a mark in each gap",
	"spark": "Sparkle: a four-point spark",
	"drop": "Grimble: a drop of Blight goo",
	"sun": "Meeko: her tiny sun, a ring with eight rays",
	"mark": "Sable: the duelist's four corner brackets on her mark",
	"harlequin": "Motley: a jester's harlequin diamond",
	"fin": "Gil: a ring with a swept-back dorsal fin",
}


## True for a look id this file draws.
static func has(look: String) -> bool:
	return LOOKS.has(look)


## Draws the strokes of `look` round `at`: `ring` px is the ring's radius (with bloom), `k` the size factor.
static func strokes(c: CanvasItem, at: Vector2, look: String, ring: float, k: float, col: Color, w: float) -> void:
	match look:
		"stitch":
			for i in 6:
				var a := TAU * i / 6.0
				c.draw_line(at + _polar(a, ring - 1.1 * k), at + _polar(a + 0.3, ring + 1.1 * k), col, w, true)
		"shackle":
			c.draw_arc(at, ring, PI * 0.62, PI * 1.38, 10, col, w * 1.35, true)
			c.draw_arc(at, ring, -PI * 0.38, PI * 0.38, 10, col, w * 1.35, true)
			var tick := at + Vector2(0, -ring - 0.6 * k)
			var wing := Vector2(1.8 * k, -2.4 * k)
			c.draw_polyline(PackedVector2Array([tick + Vector2(-wing.x, wing.y), tick, tick + wing]), col, w, true)
		"coin":
			c.draw_arc(at, ring, 0.0, TAU, 28, col, w, true)
			for i in 4:
				var a := PI * 0.5 * i
				c.draw_line(at + _polar(a, ring - 2.2 * k), at + _polar(a, ring), col, w, true)
		"aegis":
			_ring_poly(c, at, ring + 0.8 * k, 6, 0.0, col, w)
		"frost":
			for i in 6:
				var a := -PI * 0.5 + TAU * i / 6.0
				c.draw_line(at + _polar(a, 2.8 * k), at + _polar(a, ring + 1.6 * k), col, w, true)
		"flame":
			_ring_poly(c, at, ring + 2.0 * k, 3, -PI * 0.5, col, w)
		"rune":
			for i in 3:
				var a := -PI * 0.5 + TAU * i / 3.0
				c.draw_arc(at, ring, a + 0.3, a + TAU / 3.0 - 0.3, 8, col, w, true)
				c.draw_line(at + _polar(a, ring - 1.6 * k), at + _polar(a, ring + 2.2 * k), col, w, true)
		"spark":
			_star(c, at, ring + 2.2 * k, ring * 0.45, col, w)
		"drop":
			_drop(c, at, ring, k, col, w)
		"sun":
			c.draw_arc(at, ring * 0.72, 0.0, TAU, 20, col, w, true)
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_line(at + _polar(a, ring * 0.72 + 1.5 * k), at + _polar(a, ring + 2.0 * k), col, w, true)
		"mark":
			var s := ring + 0.4 * k
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var corner: Vector2 = at + d * s
				var arm := 2.6 * k
				var pts := PackedVector2Array([corner - Vector2(d.x * arm, 0), corner, corner - Vector2(0, d.y * arm)])
				c.draw_polyline(pts, col, w, true)
		"harlequin":
			_ring_poly(c, at, ring + 2.0 * k, 4, -PI * 0.5, col, w)
		"fin":
			var top := -PI * 0.5
			c.draw_arc(at, ring, top + 0.15, top + TAU - 0.75, 24, col, w, true)
			var fin := PackedVector2Array([at + _polar(top - 0.75, ring), at + Vector2(2.8 * k, -ring - 2.6 * k)])
			fin.append(at + _polar(top + 0.15, ring))
			c.draw_polyline(fin, col, w, true)


static func _polar(a: float, r: float) -> Vector2:
	return Vector2(cos(a), sin(a)) * r


## A closed regular polygon of `n` corners on radius `r`, the first corner at angle `rot`.
static func _ring_poly(c: CanvasItem, at: Vector2, r: float, n: int, rot: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(at + _polar(rot + TAU * i / float(n), r))
	c.draw_polyline(pts, col, w, true)


## A closed 4-point star: points on `r`, waist corners on `waist`.
static func _star(c: CanvasItem, at: Vector2, r: float, waist: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := -PI * 0.5 + i * PI * 0.25
		pts.append(at + _polar(a, r if i % 2 == 0 else waist))
	c.draw_polyline(pts, col, w, true)


## A drop hanging point up: most of the ring round the bottom, closing in a tip above it.
static func _drop(c: CanvasItem, at: Vector2, ring: float, k: float, col: Color, w: float) -> void:
	var tip := at + Vector2(0, -ring - 2.6 * k)
	var pts := PackedVector2Array([tip])
	for i in 15:
		pts.append(at + _polar(lerpf(-PI * 0.5 + 0.75, PI * 1.5 - 0.75, i / 14.0), ring))
	pts.append(tip)
	c.draw_polyline(pts, col, w, true)
