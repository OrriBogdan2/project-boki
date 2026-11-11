class_name UiTorn
extends UiFrame
## The "Void & Masks" box (UI_STYLE.md on ext/agent-briefs): a rough torn outline instead of round
## corners, a painted fill with soft blotches, ink speckle, scratched runes, chalk tally marks and
## black cracks running in from the edges (never under the content), and a chunky neon edge whose
## colour runs from `glow_a` on the left to `glow_b` on the right. The same shape with a parchment
## fill is an info strip or a title banner (nails optional); `ticket` cuts two notches into the
## sides for the one primary button. It is a UiFrame, so it keeps `fill`, `edge` and `shadow` and
## every helper that duplicates a frame (UI.set_card_border) still works.
## Drawn as canvas polygons and lines, recorded only when the control redraws; the shape of each
## rect is cached, so a menu costs no more per frame than with plain boxes.

@export var jag := 4.0                      # px the outline wanders inward (0: a clean rectangle)
@export var glow := 0.0                     # neon edge strength (0 none, 1 normal, ~1.6 hovered)
@export var glow_w := 1.0                   # neon edge thickness (1 buttons, ~2 panels)
@export var glow_a := Color("3fe0d0")       # neon colour on the left
@export var glow_b := Color("ff3fd0")       # neon colour on the right
@export var grain := 0.0                    # speckle, runes, cracks and blotches (0..1)
@export var ticket := false                 # cut a notch into the left and right sides
@export var nails := false                  # two nails pinning the top corners (parchment strips)
@export var tilt := 0                       # varies the tear pattern so boxes side by side differ

const STEP_PX := 18.0                       # spacing of the outline's points
const BAND_PX := 34.0                       # depth of the border band that carries the speckle
const GLOW_PASSES := [[26.0, 0.05], [14.0, 0.12], [7.0, 0.3], [3.0, 1.0]]   # [width px, alpha] outer to inner
const CACHE_MAX := 48                       # shapes kept per box (rects in use on screen)
const RUNE_CELL := Vector2(13.0, 20.0)      # px, one scratched glyph
const TALLY := 5                            # strokes in a chalk tally group
const CRACK_INK := Color(0.0, 0.0, 0.02, 0.62)
const CRACK_LIT := Color(0.85, 0.75, 1.0, 0.1)

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
	if glow > 0.0:
		return rect.grow(8.0 + 18.0 * glow_w)
	return rect.grow(3.0 if edge.a > 0.0 else 0.0)

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
		var off := Transform2D(0.0, Vector2(0.0, float(shadow) * 0.35))
		rs.canvas_item_add_set_transform(to_canvas_item, off)
		rs.canvas_item_add_polygon(to_canvas_item, g.pts, PackedColorArray([Color(0, 0, 0.02, 0.45)]))
		rs.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)
	rs.canvas_item_add_polygon(to_canvas_item, g.pts, g.fill_cols)
	for i in g.specks.size():
		var s: Vector3 = g.specks[i]
		rs.canvas_item_add_circle(to_canvas_item, Vector2(s.x, s.y), s.z, g.speck_cols[i])
	for stroke in g.runes:
		rs.canvas_item_add_polyline(to_canvas_item, stroke, PackedColorArray([g.rune_col]), 1.6, true)
	for stroke in g.chalk:
		rs.canvas_item_add_polyline(to_canvas_item, stroke, PackedColorArray([g.chalk_col]), 2.2, true)
	for crack in g.cracks:
		rs.canvas_item_add_polyline(to_canvas_item, crack, PackedColorArray([CRACK_LIT]), 3.5, true)
		rs.canvas_item_add_polyline(to_canvas_item, crack, PackedColorArray([CRACK_INK]), 1.6, true)
	if glow > 0.0:
		for pass_wa in GLOW_PASSES:
			var cols := PackedColorArray()
			var core: bool = pass_wa[0] <= 3.0
			for c in g.glow_cols:
				var col: Color = c.lerp(Color.WHITE, 0.3) if core else c
				cols.append(Color(col, minf(1.0, pass_wa[1] * glow)))
			rs.canvas_item_add_polyline(to_canvas_item, g.ring, cols, pass_wa[0] * glow_w, true)
	if edge.a > 0.0:
		rs.canvas_item_add_polyline(to_canvas_item, g.ring, PackedColorArray([edge]), float(edge_w) + 0.5, true)
	if nails:
		_draw_nails(to_canvas_item, rect)

func _draw_nails(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	var rad := clampf(rect.size.y * 0.09, 3.2, 5.5)
	for x in [rect.position.x + rad * 4.5, rect.end.x - rad * 4.5]:
		var at := Vector2(x, rect.position.y + rad * 2.1)
		rs.canvas_item_add_circle(to_canvas_item, at + Vector2(1.0, 1.6), rad + 0.8, Color(0, 0, 0, 0.4))
		rs.canvas_item_add_circle(to_canvas_item, at, rad, Color("3e3a46"))
		rs.canvas_item_add_circle(to_canvas_item, at - Vector2(rad * 0.3, rad * 0.3), rad * 0.45, Color("c8c4d0"))

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
		"specks": PackedVector3Array(), "speck_cols": PackedColorArray(), "runes": [], "chalk": [],
		"cracks": [], "rune_col": Color(0.8, 0.65, 1.0, 0.13), "chalk_col": Color(0.95, 0.92, 1.0, 0.3)}
	if grain > 0.0:
		_add_blotches(shape, r, light)
		_add_specks(shape, r, light)
		if not light and r.size.x > 180.0 and r.size.y > 160.0:
			_add_runes(shape, r)
			_add_tally(shape, r)
			_add_cracks(shape, r)
	return shape

## The torn outline, clockwise from the top-left: chipped corners, wobbles every STEP_PX, now and
## then a deep tear, and the ticket notches.
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
		var chip_a := jag * (0.8 + 2.0 * _h(seed_i + side * 13))
		var chip_b := jag * (0.8 + 2.0 * _h(seed_i + side * 13 + 5))
		var steps := maxi(2, int(length / STEP_PX))
		var notch := ticket and side % 2 == 1
		var deepest := minf(r.size.x, r.size.y) * 0.3        # a tear never crosses the box

		for k in steps + 1:
			var d := lerpf(chip_a, length - chip_b, float(k) / steps)
			var h := _h(seed_i + side * 101 + k * 7)
			var depth := jag * h * 0.8
			if h > 0.94 and k > 0 and k < steps:
				depth = jag * (1.8 + 1.4 * _h(seed_i + k))
			if notch:
				var rn := minf(r.size.y * 0.28, 16.0)
				if absf(d - length * 0.5) < rn:
					depth = maxf(depth, sqrt(maxf(0.0, rn * rn - pow(d - length * 0.5, 2.0))) + 1.0)
			pts.append(a + along * d + inward * minf(depth, deepest))
	return pts

## Soft blotches of lighter and darker paint across the face, three fading rings each.
func _add_blotches(shape: Dictionary, r: Rect2, light: bool) -> void:
	var count := mini(12, int(r.get_area() / 16000.0 * grain))
	var specks := PackedVector3Array()
	var cols := PackedColorArray()
	for i in count:
		var at := r.position + Vector2(_h(i * 5 + 70) * r.size.x, _h(i * 5 + 71) * r.size.y)
		var rad := 24.0 + 50.0 * _h(i * 5 + 72)
		var tone := Color(0.3, 0.2, 0.1, 0.025) if light else Color(0.7, 0.5, 1.0, 0.02)
		if _h(i * 5 + 73) > 0.4:
			tone = Color(0, 0, 0.02, 0.03)
		for ring in 4:
			specks.append(Vector3(at.x, at.y, rad * (1.0 - ring * 0.22)))
			cols.append(tone)
	shape.specks.append_array(specks)
	shape.speck_cols.append_array(cols)

func _add_specks(shape: Dictionary, r: Rect2, light: bool) -> void:
	var band := minf(BAND_PX, minf(r.size.x, r.size.y) * 0.22)
	var perimeter := 2.0 * (r.size.x + r.size.y)
	var count := mini(220, int(perimeter / 8.0 * grain))
	var specks := PackedVector3Array()
	var cols := PackedColorArray()
	var dark := Color(0.32, 0.22, 0.14, 0.26) if light else Color(0, 0, 0, 0.6)
	var pale := Color(0.4, 0.3, 0.2, 0.14) if light else Color(0.8, 0.6, 1.0, 0.16)
	for i in count:
		var t := _h(i * 3 + 11) * perimeter
		var depth := jag + 2.0 + pow(_h(i * 3 + 12), 1.6) * band
		var p := _on_perimeter(r, t, depth)
		var rad := 0.7 + 2.2 * pow(_h(i * 3 + 13), 2.0)
		specks.append(Vector3(p.x, p.y, rad))
		cols.append(pale if i % 4 == 0 else dark)
	shape.specks.append_array(specks)
	shape.speck_cols.append_array(cols)

## Scratched glyphs in columns down the left and right bands, as on the refs: a stem with a
## branch, a bar, now and then a cross.
func _add_runes(shape: Dictionary, r: Rect2) -> void:
	var cell := RUNE_CELL
	var pitch := cell.y + 18.0
	var rows := int((r.size.y - 90.0) / pitch)
	for col in 2:
		var x := r.position.x + jag + 10.0 if col == 0 else r.end.x - jag - 10.0 - cell.x
		for row in rows:
			var k := row * 5 + col
			var o := Vector2(x, r.position.y + 50.0 + row * pitch)
			var top := o + Vector2(_h(k) * cell.x, 0.0)
			var foot := o + Vector2(cell.x * _h(k + 2), cell.y)
			shape.runes.append(PackedVector2Array([top, o + Vector2(cell.x * 0.4, cell.y * 0.5), foot]))
			if _h(k + 3) > 0.5:
				var bar_end := o + Vector2(cell.x, cell.y * _h(k + 4))
				shape.runes.append(PackedVector2Array([o + Vector2(0.0, cell.y * 0.35), bar_end]))
			else:
				var cx := o + Vector2(cell.x * 0.5, cell.y * 0.55)
				shape.runes.append(PackedVector2Array([cx + Vector2(-5.0, -5.0), cx + Vector2(5.0, 5.0)]))
				shape.runes.append(PackedVector2Array([cx + Vector2(5.0, -5.0), cx + Vector2(-5.0, 5.0)]))

## Chalk tally marks: four strokes and a slash, in the bottom-left and top-right corners.
func _add_tally(shape: Dictionary, r: Rect2) -> void:
	var spots := [Vector2(r.position.x + jag + 12.0, r.end.y - jag - 24.0),
		Vector2(r.end.x - jag - 48.0, r.position.y + jag + 4.0)]
	for s in spots.size():
		var o: Vector2 = spots[s]
		for i in TALLY - 1:
			var x := o.x + i * 8.0 + _h(s * 9 + i) * 2.0
			var top := Vector2(x, o.y + _h(s * 9 + i + 3) * 2.0)
			shape.chalk.append(PackedVector2Array([top, Vector2(x + 1.5, o.y + 18.0)]))
		shape.chalk.append(PackedVector2Array([Vector2(o.x - 4.0, o.y + 15.0), Vector2(o.x + 30.0, o.y + 2.0)]))

## Black cracks running in from the edge: a few jointed lines with one short branch each.
func _add_cracks(shape: Dictionary, r: Rect2) -> void:
	var count := 3 + int(r.size.x / 400.0)
	var perimeter := 2.0 * (r.size.x + r.size.y)
	var reach := minf(90.0, minf(r.size.x, r.size.y) * 0.25)
	for i in count:
		var k := i * 11 + 200 + tilt
		var t := (float(i) + 0.3 + 0.4 * _h(k)) / count * perimeter
		var p := _on_perimeter(r, t, jag)
		var centre := r.get_center()
		var dir := (centre - p).normalized()
		var line := PackedVector2Array([p])
		var steps := 3 + int(_h(k + 1) * 3.0)
		for s in steps:
			dir = dir.rotated((_h(k + s * 3) - 0.5) * 1.1)
			p += dir * reach / steps * (0.6 + 0.8 * _h(k + s * 3 + 1))
			line.append(p)
		shape.cracks.append(line)
		var mid: Vector2 = line[1 + int(_h(k + 2) * (line.size() - 2))]
		var branch := PackedVector2Array([mid, mid + dir.rotated(1.2 * signf(_h(k + 5) - 0.5)) * reach * 0.3])
		shape.cracks.append(branch)

## The point `t` px along the rect's edge (clockwise from the top-left), moved `depth` px inside.
static func _on_perimeter(r: Rect2, t: float, depth: float) -> Vector2:
	var w := r.size.x
	var hgt := r.size.y
	t = fposmod(t, 2.0 * (w + hgt))
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
