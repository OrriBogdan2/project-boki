class_name UiFrame
extends StyleBox
## The one layered frame every menu box is drawn with, in the field-kit look (docs/UI_DESIGN.md):
## tooled leather with a stitched seam and brass corner guards. Layers, back to front: a soft drop
## shadow and a tight contact shadow, a dark rim, the fill, a fine leather grain, light falling from
## the top (tinted by `tint`), a lit bevel line and a shade along the bottom, a darker edge burnish,
## a brass `trim` line just inside the rim, the stitched seam, the brass corner guards, an inner
## `glow` (hover and focus) and a coloured `edge`. A recess (wells, tab tracks, slider tracks)
## flips the light: shade at the top, no drop shadow. A lip is a darker strip under the face (chunky
## buttons); a pressed face sinks onto it. `mark` is an accent line along the bottom inside.
## UiTheme builds every panel, card, tooltip, button and track from these, so they read as one set.
## Properties are exported so duplicate() copies them; the layers are built on first draw and reused.

@export var fill := Color(0.1, 0.1, 0.12)
@export var rad := 10
@export var rim := Color(0.0, 0.0, 0.0, 0.0)
@export var shadow := 0                     # px of the soft drop shadow (0: none)
@export var lit := 0.06                     # alpha of the light falling from the top
@export var tint := Color(1.0, 0.96, 0.88)  # colour of that light (a panel's section colour)
@export var recess := false
@export var lip := 0                        # px of darker face under the button
@export var pressed := false                # sunk onto its lip
@export var edge := Color(0.0, 0.0, 0.0, 0.0)
@export var edge_w := 1
@export var mark := Color(0.0, 0.0, 0.0, 0.0)
@export var grain := 0.0                    # strength of the leather grain (0: smooth)
@export var burnish := 0.0                  # alpha of the darker band round the inside edge
@export var trim := Color(0.0, 0.0, 0.0, 0.0)    # a brass line just inside the rim
@export var stitch := Color(0.0, 0.0, 0.0, 0.0)  # the stitched seam's thread
@export var stitch_in := 7.0                # px from the edge to the seam
@export var guards := Color(0.0, 0.0, 0.0, 0.0)  # brass corner guards
@export var glow := Color(0.0, 0.0, 0.0, 0.0)    # an inner glow (hover, focus)
@export var grow := 0.0                     # px the whole frame reaches past the control (focus rings)

const LIGHT_PX := 26                        # how far down the top light fades out
const SHADE_PX := 4                         # the bottom shade (raised) or top shade (recess)
const SHADOW_DROP := 0.38                   # the soft shadow sits this share of its size below the box
const GRAIN_PX := 128                       # the grain tile, px
const DASH := 6.0                           # px of thread per stitch
const GAP := 4.0                            # px between stitches
const GUARD_REACH := 20.0                   # px a corner guard runs along each edge past the curve

static var _grain_tex: ImageTexture

var _boxes: Array[StyleBoxFlat] = []
var _where: Array[int] = []                 # per box: 0 the whole rect, 1 the face, 2 / 3 the face inset 1 / 2 px
var _grain_after := -1                      # the grain goes on just before this layer (the lighting)
var _seam_size := Vector2.ZERO              # the rect size the cached seam and guards were built for
var _seam := PackedVector2Array()
var _guard_lines: Array[PackedVector2Array] = []

## A raised frame (panels, cards, buttons) with this fill, corner radius and drop shadow.
static func raised(fill_col: Color, radius: int, shadow_px := 0, rim_col := Color(0, 0, 0, 0)) -> UiFrame:
	var f := UiFrame.new()
	f.fill = fill_col
	f.rad = radius
	f.shadow = shadow_px
	f.rim = rim_col
	return f

## A recess (wells, tracks): the light reversed and no drop shadow.
static func sunk(fill_col: Color, radius: int) -> UiFrame:
	var f := raised(fill_col, radius)
	f.recess = true
	f.lit = 0.0
	return f

## Sets all four content margins and returns the frame (for chaining).
func padded(h: float, v: float) -> UiFrame:
	content_margin_left = h
	content_margin_right = h
	content_margin_top = v
	content_margin_bottom = v
	return self

## Gives the frame the tooled-leather finish: grain, an edge burnish and a stitched seam in `thread`.
func leather(thread: Color, grain_amt := 0.07, seam_in := 7.0) -> UiFrame:
	grain = grain_amt
	burnish = 0.22
	stitch = thread
	stitch_in = seam_in
	return self

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if _boxes.is_empty():
		_build()
	rect = rect.grow(grow)
	var face := _face_rect(rect)
	for i in _boxes.size():
		var r := rect
		if _where[i] == 1:
			r = face
		elif _where[i] == 2:
			r = face.grow(-1.0)
		elif _where[i] == 3:
			r = face.grow(-2.0)
		if i == _grain_after and grain > 0.0:
			_draw_grain(to_canvas_item, face)
		_boxes[i].draw(to_canvas_item, r)
	if _grain_after < 0 and grain > 0.0:
		_draw_grain(to_canvas_item, face)
	if stitch.a > 0.0 or guards.a > 0.0:
		_draw_seam(to_canvas_item, face)

func _get_draw_rect(rect: Rect2) -> Rect2:
	var r := rect.grow(grow)
	return r.grow(float(shadow) * 1.4) if shadow > 0 else r

func _face_rect(rect: Rect2) -> Rect2:
	if lip <= 0:
		return rect
	var sink := float(lip - 1) if pressed else 0.0
	return Rect2(rect.position + Vector2(0, sink), rect.size - Vector2(0, float(lip)))

func _build() -> void:
	if shadow > 0 and fill.a > 0.0:
		_add(_shadow_box(Color(0.02, 0.0, 0.0, 0.46), shadow, float(shadow) * SHADOW_DROP, rad), 3)
		_add(_shadow_box(Color(0.02, 0.0, 0.0, 0.34), 3, 1.0, rad), 3)
	if lip > 0:
		_add(_flat(fill.darkened(0.5), rad), 0)
	var body := _flat(fill, rad)
	if rim.a > 0.0:
		body.border_color = rim
		body.set_border_width_all(1)
	_add(body, 1)
	_grain_after = _boxes.size()
	var inner := maxi(0, rad - 1)
	var light := Color(tint, lit)
	var shade := Color(0.0, 0.0, 0.0, 0.32 if recess else 0.22)
	if recess:
		_add(_band(shade, inner, SHADE_PX + 2, 0), 2)
		_add(_band(Color(1, 0.95, 0.85, 0.06), inner, 0, 1, false), 2)
	elif fill.a > 0.0:
		if lit > 0.0:
			_add(_band(light, inner, LIGHT_PX, 0), 2)
			_add(_band(Color(light, minf(1.0, lit * 2.2)), inner, 1, 0, false), 2)
		_add(_band(shade, inner, 0, SHADE_PX), 2)
	if burnish > 0.0:
		var b := _band(Color(0.05, 0.02, 0.0, burnish), inner, 9, 9)
		b.border_width_left = 9
		b.border_width_right = 9
		_add(b, 2)
	if trim.a > 0.0:
		_add(_ring(trim, inner, 1), 2)
	if mark.a > 0.0:
		_add(_band(mark, inner, 0, 2, false), 2)
	if glow.a > 0.0:
		var g := _band(glow, inner, 10, 10)
		g.border_width_left = 10
		g.border_width_right = 10
		_add(g, 2)
	if edge.a > 0.0:
		_add(_ring(edge, rad, edge_w), 1)
	if _grain_after >= _boxes.size():
		_grain_after = -1

func _add(b: StyleBoxFlat, where: int) -> void:
	_boxes.append(b)
	_where.append(where)

## The leather grain: a seamless pebbled tile, drawn tile by tile over the face, kept off the
## rounded corners by insetting it a third of the radius (where the curve has already turned).
func _draw_grain(ci: RID, face: Rect2) -> void:
	var tex := grain_tex()
	var r := face.grow(-maxf(2.0, float(rad) * 0.32))
	var col := Color(1, 1, 1, grain)
	var y := 0.0
	while y < r.size.y:
		var x := 0.0
		var th := minf(float(GRAIN_PX), r.size.y - y)
		while x < r.size.x:
			var tw := minf(float(GRAIN_PX), r.size.x - x)
			var dst := Rect2(r.position + Vector2(x, y), Vector2(tw, th))
			RenderingServer.canvas_item_add_texture_rect_region(ci, dst, tex.get_rid(), Rect2(0, 0, tw, th), col)
			x += float(GRAIN_PX)
		y += float(GRAIN_PX)

## The grain tile (built once): light and dark pebbles from cellular noise over a fine fleck, as
## white and black at low alpha so it reads on any fill.
static func grain_tex() -> ImageTexture:
	if _grain_tex:
		return _grain_tex
	var cells := FastNoiseLite.new()
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cells.frequency = 0.14
	cells.seed = 11
	var fleck := FastNoiseLite.new()
	fleck.noise_type = FastNoiseLite.TYPE_VALUE
	fleck.frequency = 0.22
	fleck.seed = 5
	var a := cells.get_seamless_image(GRAIN_PX, GRAIN_PX)
	var b := fleck.get_seamless_image(GRAIN_PX, GRAIN_PX)
	var img := Image.create(GRAIN_PX, GRAIN_PX, false, Image.FORMAT_RGBA8)
	for y in GRAIN_PX:
		for x in GRAIN_PX:
			var v := a.get_pixel(x, y).r * 0.8 + b.get_pixel(x, y).r * 0.2 - 0.5
			img.set_pixel(x, y, Color(1, 0.95, 0.85, v * 2.0) if v > 0.0 else Color(0, 0, 0, -v * 2.4))
	_grain_tex = ImageTexture.create_from_image(img)
	return _grain_tex

## The stitched seam (a dark groove under each stitch, the thread over it) and the brass corner
## guards, both cached for the rect size.
func _draw_seam(ci: RID, face: Rect2) -> void:
	if face.size != _seam_size:
		_seam_size = face.size
		_build_seam(face.size)
	var at := Transform2D(0.0, face.position)
	RenderingServer.canvas_item_add_set_transform(ci, at.translated(Vector2(0, 1)))
	if stitch.a > 0.0 and _seam.size() > 0:
		RenderingServer.canvas_item_add_multiline(ci, _seam, [Color(0, 0, 0, 0.45 * stitch.a)], 2.4, true)
		RenderingServer.canvas_item_add_set_transform(ci, at)
		RenderingServer.canvas_item_add_multiline(ci, _seam, [stitch], 1.6, true)
	RenderingServer.canvas_item_add_set_transform(ci, at)
	for g in _guard_lines:
		RenderingServer.canvas_item_add_polyline(ci, g, [guards.darkened(0.45)], 5.0, true)
		RenderingServer.canvas_item_add_polyline(ci, g, [guards], 3.2, true)
		RenderingServer.canvas_item_add_polyline(ci, g, [Color(guards.lightened(0.5), 0.8)], 1.0, true)
		for end in [g[0], g[g.size() - 1]]:
			RenderingServer.canvas_item_add_circle(ci, end, 2.6, guards.darkened(0.35), true)
			RenderingServer.canvas_item_add_circle(ci, end - Vector2(0.5, 0.6), 1.5, guards.lightened(0.35), true)
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D())

func _build_seam(sz: Vector2) -> void:
	_seam = PackedVector2Array()
	_guard_lines.clear()
	if stitch.a > 0.0:
		var inset := stitch_in
		var path := _round_path(Rect2(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0), maxf(2.0, rad - inset))
		_seam = _dashes(path)
	if guards.a > 0.0:
		var outer := _round_path(Rect2(Vector2(1.6, 1.6), sz - Vector2(3.2, 3.2)), maxf(3.0, rad - 1.6))
		_guard_lines = _corner_runs(outer, sz)

## Points round a rounded rect, clockwise from the top-left corner's end.
static func _round_path(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var centres := [Vector2(r.end.x - radius, r.position.y + radius), Vector2(r.end.x - radius, r.end.y - radius),
		Vector2(r.position.x + radius, r.end.y - radius), Vector2(r.position.x + radius, r.position.y + radius)]
	for i in 4:
		var a0 := -PI * 0.5 + PI * 0.5 * i
		for k in 7:
			var a := a0 + PI * 0.5 * k / 6.0
			pts.append(centres[i] + Vector2(cos(a), sin(a)) * radius)
	pts.append(pts[0])
	return pts

## The path cut into stitches: pairs of points for a multiline.
static func _dashes(path: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var on := true
	var left := DASH
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var seg := a.distance_to(b)
		var t := 0.0
		while seg - t > 0.001:
			var step := minf(left, seg - t)
			if on:
				out.append(a.lerp(b, t / seg))
				out.append(a.lerp(b, (t + step) / seg))
			t += step
			left -= step
			if left <= 0.001:
				on = not on
				left = DASH if on else GAP
	return out

## For each corner, the stretch of the outline within GUARD_REACH of it plus the curve.
func _corner_runs(path: PackedVector2Array, sz: Vector2) -> Array[PackedVector2Array]:
	var reach := float(rad) + GUARD_REACH
	var corners := [Vector2(sz.x, 0), sz, Vector2(0, sz.y), Vector2.ZERO]
	var out: Array[PackedVector2Array] = []
	for c in corners:
		var run := PackedVector2Array()
		for i in path.size() - 1:
			var p := path[i]
			if absf(p.x - c.x) < reach and absf(p.y - c.y) < reach and (absf(p.x - c.x) < 4.0 + rad
					or absf(p.y - c.y) < 4.0 + rad):
				run.append(p)
		if run.size() >= 2:
			out.append(_extend(run, c, reach))
	return out

## Stretches the corner run's two ends along their edges to `reach` from the corner.
static func _extend(run: PackedVector2Array, c: Vector2, reach: float) -> PackedVector2Array:
	var first := run[0]
	var last := run[run.size() - 1]
	var out := PackedVector2Array()
	out.append(_toward(first, c, reach))
	out.append_array(run)
	out.append(_toward(last, c, reach))
	return out

## A point on the same edge as `p`, `reach` from the corner `c`.
static func _toward(p: Vector2, c: Vector2, reach: float) -> Vector2:
	if absf(p.x - c.x) > absf(p.y - c.y):
		return Vector2(c.x + signf(p.x - c.x) * reach, p.y)
	return Vector2(p.x, c.y + signf(p.y - c.y) * reach)

static func _flat(col: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = col
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b

## A coloured outline of width w (no fill).
static func _ring(col: Color, radius: int, w: int) -> StyleBoxFlat:
	var e := _flat(Color(0, 0, 0, 0), radius)
	e.draw_center = false
	e.border_color = col
	e.set_border_width_all(w)
	return e

## A soft shadow under the face: a solid core (hidden under the face, drawn just inside it) that
## casts the blurred shadow, so there is no gap between the box and its shadow.
static func _shadow_box(col: Color, size_px: int, drop: float, radius: int) -> StyleBoxFlat:
	var b := _flat(col, radius)
	b.shadow_color = col
	b.shadow_size = size_px
	b.shadow_offset = Vector2(0, drop)
	return b

## A band along the top and/or bottom inside edge that fades inward (blend), or a hard line.
static func _band(col: Color, radius: int, top: int, bottom: int, blend := true) -> StyleBoxFlat:
	var b := _flat(Color(col, 0.0), radius)
	b.draw_center = false
	b.border_color = col
	b.border_width_top = top
	b.border_width_bottom = bottom
	b.border_blend = blend
	return b
