class_name UiFrame
extends StyleBox
## The one layered frame every menu box is drawn with: a soft drop shadow and a tight contact
## shadow, a dark rim, the fill, light falling from the top edge, a lit bevel line just inside the
## top and a shade along the bottom. A recess (wells, tab tracks, slider tracks) flips the light: shade at the
## top, no drop shadow. A lip is a darker strip under the face (chunky buttons); a pressed face
## sinks onto it. `edge` draws a coloured outline (selected, focus-free hover, danger) and `mark`
## an accent line along the bottom inside (the picked tab).
## UiTheme builds every panel, card, tooltip, button and track from these, so they read as one set.
## Properties are exported so duplicate() (UiWidgets.with_key, UI.set_card_border) copies them; the layers
## are built on first draw and reused.

@export var fill := Color(0.1, 0.1, 0.12)
@export var rad := 10
@export var rim := Color(0.0, 0.0, 0.0, 0.0)
@export var shadow := 0                     # px of the soft drop shadow (0: none)
@export var lit := 0.06                     # alpha of the light falling from the top
@export var recess := false
@export var lip := 0                        # px of darker face under the button
@export var pressed := false                # sunk onto its lip
@export var edge := Color(0.0, 0.0, 0.0, 0.0)
@export var edge_w := 1
@export var mark := Color(0.0, 0.0, 0.0, 0.0)

const LIGHT_PX := 26                        # how far down the top light fades out
const SHADE_PX := 4                         # the bottom shade (raised) or top shade (recess)
const SHADOW_DROP := 0.38                   # the soft shadow sits this share of its size below the box

var _boxes: Array[StyleBoxFlat] = []
var _where: Array[int] = []                 # per box: 0 the whole rect, 1 the face, 2 / 3 the face inset 1 / 2 px

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

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if _boxes.is_empty():
		_build()
	var face := _face_rect(rect)
	for i in _boxes.size():
		var r := rect
		if _where[i] == 1:
			r = face
		elif _where[i] == 2:
			r = face.grow(-1.0)
		elif _where[i] == 3:
			r = face.grow(-2.0)
		_boxes[i].draw(to_canvas_item, r)

func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(float(shadow) * 1.4) if shadow > 0 else rect

func _face_rect(rect: Rect2) -> Rect2:
	if lip <= 0:
		return rect
	var sink := float(lip - 1) if pressed else 0.0
	return Rect2(rect.position + Vector2(0, sink), rect.size - Vector2(0, float(lip)))

func _build() -> void:
	if shadow > 0 and fill.a > 0.0:
		_add(_shadow_box(Color(0.0, 0.0, 0.02, 0.42), shadow, float(shadow) * SHADOW_DROP, rad), 3)
		_add(_shadow_box(Color(0.0, 0.0, 0.02, 0.32), 3, 1.0, rad), 3)
	if lip > 0:
		_add(_flat(fill.darkened(0.45), rad), 0)
	var body := _flat(fill, rad)
	if rim.a > 0.0:
		body.border_color = rim
		body.set_border_width_all(1)
	_add(body, 1)
	var inner := maxi(0, rad - 1)
	var light := Color(1.0, 0.96, 0.88, lit)
	var shade := Color(0.0, 0.0, 0.0, 0.3 if recess else 0.2)
	if recess:
		_add(_band(shade, inner, SHADE_PX + 2, 0), 2)
		_add(_band(Color(1, 1, 1, 0.05), inner, 0, 1, false), 2)
	else:
		if lit > 0.0:
			_add(_band(light, inner, LIGHT_PX, 0), 2)
			_add(_band(Color(light, minf(1.0, lit * 2.2)), inner, 1, 0, false), 2)
		_add(_band(shade, inner, 0, SHADE_PX), 2)
	if mark.a > 0.0:
		_add(_band(mark, inner, 0, 2, false), 2)
	if edge.a > 0.0:
		var e := _flat(Color(0, 0, 0, 0), rad)
		e.draw_center = false
		e.border_color = edge
		e.set_border_width_all(edge_w)
		_add(e, 1)

func _add(b: StyleBoxFlat, where: int) -> void:
	_boxes.append(b)
	_where.append(where)

static func _flat(col: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = col
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b

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
