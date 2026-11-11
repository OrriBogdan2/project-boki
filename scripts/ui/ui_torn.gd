class_name UiTorn
extends UiFrame
## The "Void & Masks" box (UI_STYLE.md on ext/agent-briefs): a rough torn outline instead of round
## corners, faint ink speckle and scratched runes in the border band (never under the content),
## and a neon edge whose colour runs from `glow_a` on the left to `glow_b` on the right. The same
## shape with a parchment fill is an info strip or a title tab (nails optional); `ticket` cuts two
## notches into the sides for the one primary button. It is a UiFrame, so it keeps `fill`, `edge`
## and `shadow` and every helper that duplicates a frame (UI.set_card_border) still works.
## Drawn as a few canvas polygons and lines, recorded only when the control redraws; the outline
## of each rect is cached, so a menu costs no more per frame than with plain boxes.

@export var jag := 4.0                      # px the outline wanders inward (0: a clean rectangle)
@export var glow := 0.0                     # neon edge strength (0 none, 1 normal, ~1.6 hovered)
@export var glow_a := Color("3fe0d0")       # neon colour on the left
@export var glow_b := Color("ff3fd0")       # neon colour on the right
@export var grain := 0.0                    # speckle and rune density in the border band (0..1)
@export var ticket := false                 # cut a notch into the left and right sides
@export var nails := false                  # two nails pinning the top corners (parchment strips)
@export var tilt := 0                       # varies the tear pattern so boxes side by side differ

const STEP_PX := 16.0                       # spacing of the outline's points
const BAND_PX := 22.0                       # depth of the border band that carries the speckle
const GLOW_PASSES := [[10.0, 0.08], [5.0, 0.2], [2.0, 0.95]]    # [width px, alpha] outer to inner
const CACHE_MAX := 48                       # outlines kept per box (rects in use on screen)

var _cache := {}

## A torn box with this fill; `glow_k` 0 leaves the neon edge off.
static func make(fill_col: Color, jag_px := 4.0, glow_k := 0.0, grain_k := 0.0) -> UiTorn:
	var t := UiTorn.new()
	t.fill = fill_col
	t.jag = jag_px
	t.glow = glow_k
	t.grain = grain_k
	t.lit = 0.0
	return t

## A copy of this box with another fill and glow (hover and pressed states of a button).
func variant(fill_col: Color, glow_k: float) -> UiTorn:
	var t := duplicate() as UiTorn
	t.fill = fill_col
	t.glow = glow_k
	return t

func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(6.0 if glow > 0.0 or edge.a > 0.0 else 0.0)

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x < jag * 6.0 + 8.0 or rect.size.y < jag * 4.0 + 8.0:
		super._draw(to_canvas_item, rect)
		return
	var g: Dictionary = _cache.get(rect, {})
	if g.is_empty():
		if _cache.size() >= CACHE_MAX:
			_cache.clear()
		g = _build_shape(rect)
		_cache[rect] = g
	var rs := RenderingServer
	if shadow > 0:
		var off := Transform2D(0.0, Vector2(0.0, float(shadow) * 0.3))
		rs.canvas_item_add_set_transform(to_canvas_item, off)
		rs.canvas_item_add_polygon(to_canvas_item, g.pts, PackedColorArray([Color(0, 0, 0.02, 0.4)]))
		rs.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)
	rs.canvas_item_add_polygon(to_canvas_item, g.pts, g.fill_cols)
	for i in g.specks.size():
		var s: Vector3 = g.specks[i]
		rs.canvas_item_add_circle(to_canvas_item, Vector2(s.x, s.y), s.z, g.speck_cols[i])
	for stroke in g.runes:
		rs.canvas_item_add_polyline(to_canvas_item, stroke, PackedColorArray([g.rune_col]), 1.3, true)
	if glow > 0.0:
		for pass_wa in GLOW_PASSES:
			var cols := PackedColorArray()
			for c in g.glow_cols:
				cols.append(Color(c, minf(1.0, pass_wa[1] * glow)))
			rs.canvas_item_add_polyline(to_canvas_item, g.ring, cols, pass_wa[0], true)
	if edge.a > 0.0:
		rs.canvas_item_add_polyline(to_canvas_item, g.ring, PackedColorArray([edge]), float(edge_w) + 0.5, true)
	if nails:
		for x in [rect.position.x + 16.0, rect.end.x - 16.0]:
			var at := Vector2(x, rect.position.y + 7.0)
			rs.canvas_item_add_circle(to_canvas_item, at + Vector2(0.6, 1.0), 3.6, Color(0, 0, 0, 0.35))
			rs.canvas_item_add_circle(to_canvas_item, at, 3.2, Color("4a4650"))
			rs.canvas_item_add_circle(to_canvas_item, at - Vector2(1.0, 1.0), 1.2, Color("b4b0bc"))

func _build_shape(r: Rect2) -> Dictionary:
	var pts := _outline(r)
	var light := fill.get_luminance() > 0.5
	var fill_cols := PackedColorArray()
	var glow_cols := PackedColorArray()
	for p in pts:
		var down := (p.y - r.position.y) / r.size.y
		fill_cols.append(fill.lightened(0.06 * (1.0 - down)) if not light else fill.darkened(0.08 * down))
		var across := clampf((p.x - r.position.x) / r.size.x * 0.85 + down * 0.15, 0.0, 1.0)
		glow_cols.append(glow_a.lerp(glow_b, across))
	var ring := pts.duplicate()
	ring.append(pts[0])
	glow_cols.append(glow_cols[0])
	var shape := {"pts": pts, "fill_cols": fill_cols, "ring": ring, "glow_cols": glow_cols,
		"specks": PackedVector3Array(), "speck_cols": PackedColorArray(), "runes": [],
		"rune_col": Color(0.78, 0.62, 1.0, 0.09)}
	if grain > 0.0:
		_add_specks(shape, r, light)
		if not light and r.size.x > 180.0 and r.size.y > 160.0:
			_add_runes(shape, r)
	return shape

## The torn outline, clockwise from the top-left: chipped corners, small inward wobbles every
## STEP_PX, now and then a deeper tear, and the ticket notches.
func _outline(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var seed_i := tilt * 977 + int(r.size.x) * 31 + int(r.size.y) * 7
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var along := (b - a).normalized()
		var inward := Vector2(-along.y, along.x)
		var length := a.distance_to(b)
		var chip_a := jag * (0.6 + 1.6 * _h(seed_i + side * 13))
		var chip_b := jag * (0.6 + 1.6 * _h(seed_i + side * 13 + 5))
		var steps := maxi(2, int(length / STEP_PX))
		var notch := ticket and side % 2 == 1
		for k in steps + 1:
			var d := lerpf(chip_a, length - chip_b, float(k) / steps)
			var h := _h(seed_i + side * 101 + k * 7)
			var depth := jag * h
			if h > 0.94 and k > 0 and k < steps:
				depth = jag * 2.4
			if notch and absf(d - length * 0.5) < minf(r.size.y * 0.2, 11.0):
				var rn := minf(r.size.y * 0.2, 11.0)
				depth = maxf(depth, sqrt(maxf(0.0, rn * rn - pow(d - length * 0.5, 2.0))) + 1.0)
			pts.append(a + along * d + inward * depth)
	return pts

func _add_specks(shape: Dictionary, r: Rect2, light: bool) -> void:
	var band := minf(BAND_PX, minf(r.size.x, r.size.y) * 0.2)
	var perimeter := 2.0 * (r.size.x + r.size.y)
	var count := mini(160, int(perimeter / 11.0 * grain))
	var specks := PackedVector3Array()
	var cols := PackedColorArray()
	var dark := Color(0.32, 0.22, 0.14, 0.22) if light else Color(0, 0, 0, 0.5)
	var pale := Color(0.4, 0.3, 0.2, 0.12) if light else Color(0.8, 0.6, 1.0, 0.14)
	for i in count:
		var t := _h(i * 3 + 11) * perimeter
		var depth := jag + 2.0 + _h(i * 3 + 12) * band
		var p := _on_perimeter(r, t, depth)
		var rad := 0.6 + 1.5 * pow(_h(i * 3 + 13), 2.0)
		specks.append(Vector3(p.x, p.y, rad))
		cols.append(pale if i % 4 == 0 else dark)
	shape.specks = specks
	shape.speck_cols = cols

## Faint scratched glyphs in columns down the left and right bands, as on the refs.
func _add_runes(shape: Dictionary, r: Rect2) -> void:
	var cell := Vector2(9.0, 13.0)
	var rows := int((r.size.y - 60.0) / 30.0)
	for col in 2:
		var x := r.position.x + jag + 7.0 if col == 0 else r.end.x - jag - 7.0 - cell.x
		for row in rows:
			var o := Vector2(x, r.position.y + 34.0 + row * 30.0)
			var top := o + Vector2(_h(row * 5 + col) * cell.x, 0.0)
			var stroke := PackedVector2Array([top, o + Vector2(0.0, cell.y * 0.5)])
			stroke.append(o + Vector2(cell.x * _h(row * 5 + col + 2), cell.y))
			shape.runes.append(stroke)
			var bar_end := o + Vector2(cell.x, cell.y * _h(row * 9 + col))
			var bar := PackedVector2Array([o + Vector2(0.0, cell.y * 0.3), bar_end])
			shape.runes.append(bar)

## The point `t` px along the rect's edge (clockwise from the top-left), moved `depth` px inside.
static func _on_perimeter(r: Rect2, t: float, depth: float) -> Vector2:
	var w := r.size.x
	var hgt := r.size.y
	if t < w:
		return r.position + Vector2(t, depth)
	if t < w + hgt:
		return r.position + Vector2(w - depth, t - w)
	if t < 2.0 * w + hgt:
		return r.position + Vector2(2.0 * w + hgt - t, hgt - depth)
	return r.position + Vector2(depth, 2.0 * (w + hgt) - t)

## A stable pseudo-random number in 0..1 for an integer key.
func _h(i: int) -> float:
	return fposmod(sin(float(i + tilt * 131) * 12.9898) * 43758.5453, 1.0)
