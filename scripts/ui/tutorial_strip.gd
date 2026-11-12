class_name TutorialStrip
extends RefCounted
## The one objective banner of every tutorial (match steps, the first-match guide, the farm steps): a slim
## one-line strip at the top-centre, inside the title-safe margin, never taller than HEIGHT_FRAC of the
## screen. It glows softly and pulses for PULSE_T when the objective changes, then calms to a steady rim.
## The match HUD draws it on its canvas (TutorialHud); the farm adds a StripView Control (FarmGuide).
## Both call paint() with the same numbers, so the two look the same.

const MINT := Color("8fe3c8")
const GOLD := Color("f2c84a")
const PANEL := Color(0.03, 0.04, 0.07, 0.94)
const HEIGHT_FRAC := 0.06       # of the screen height: the tallest the strip gets
const WIDTH_FRAC := 0.42        # of the screen width: the widest it gets (the message lane starts at 0.72)
const PULSE_T := 1.6            # s the glow and the pulse take to calm after the objective changes
const PULSE_HZ := 2.5           # beats a second while it pulses
const POP_T := 0.25             # s the strip takes to drop in on a new objective
const GLOW_PX := 10.0           # how far the soft glow reaches past the rim at its brightest

const GAP := 8.0                # px kept under whatever already sits at the top-centre (`below`)

## Where the strip sits for a screen size: under the safe margin, and under `below` (the bottom of the
## Ways Out strip in a real match, WaysOutHud.bottom) when that is lower, so it never covers the zone clocks.
static func rect(sz: Vector2, below := 0.0) -> Rect2:
	var w := sz.x * WIDTH_FRAC
	var top := maxf(HudStyle.safe_pad(sz).y, below + GAP if below > 0.0 else 0.0)
	return Rect2(Vector2((sz.x - w) * 0.5, top), Vector2(w, sz.y * HEIGHT_FRAC))

## 1 the moment the objective changes, easing to 0 over PULSE_T.
static func glow(age: float) -> float:
	return 1.0 - clampf(age / PULSE_T, 0.0, 1.0)

## The strip's rect this frame: dropping in from above for POP_T, then still.
static func shown(sz: Vector2, age: float, below := 0.0) -> Rect2:
	var r := rect(sz, below)
	var k := clampf(age / POP_T, 0.0, 1.0)
	r.position.y -= pow(1.0 - k, 3.0) * (r.end.y + 4.0)
	return r

## Draws the strip on any CanvasItem. `line` has: text, key_cap, count ("1/3" or ""), dist ("12m" or "") and
## dir (a Vector2 for the arrow, ZERO for none). `age` is the seconds since the objective changed;
## `alpha` fades the whole strip.
static func paint(ci: CanvasItem, font: Font, r: Rect2, line: Dictionary, age: float, alpha := 1.0) -> void:
	var g := glow(age)
	var beat := 0.5 + 0.5 * sin(age * TAU * PULSE_HZ) if g > 0.0 else 0.0
	var lit := g * (0.55 + 0.45 * beat)
	# soft glow: a few wide rims fading outward, only while it is lit
	for i in 3:
		var grow := GLOW_PX * lit * float(3 - i) / 3.0
		if grow > 0.5:
			var halo := _box(Color(MINT, 0.07 * lit * alpha), r.size.y * 0.5 + grow, Color(0, 0, 0, 0), 0)
			ci.draw_style_box(halo, r.grow(grow))
	var rim := Color(MINT, (0.5 + 0.5 * lit) * alpha)
	ci.draw_style_box(_box(Color(PANEL, PANEL.a * alpha), r.size.y * 0.5, rim, int(2.0 + 1.5 * lit)), r)
	var mid := r.get_center().y
	var px := int(r.size.y * 0.5)
	var left := r.position.x + r.size.y * 0.5
	var right := r.end.x - r.size.y * 0.5
	var count := String(line.get("count", ""))
	var dist := String(line.get("dist", ""))
	var tail := (dist + "  " + count).strip_edges()
	if tail != "":
		var tw := font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		_text(ci, font, Vector2(right - tw, mid + px * 0.36), tail, px, Color(MINT, alpha))
		right -= tw + 10.0
	var dir: Vector2 = line.get("dir", Vector2.ZERO)
	if dir != Vector2.ZERO:
		right = _arrow(ci, Vector2(right, mid), r.size.y, dir, alpha) - 8.0
	var cap := String(line.get("key_cap", ""))
	if cap != "":
		var kw := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var cw := maxf(r.size.y * 0.7, kw + 16.0)
		var cr := Rect2(Vector2(left, mid - r.size.y * 0.3), Vector2(cw, r.size.y * 0.6))
		ci.draw_style_box(_box(Color(0.93, 0.95, 0.98, alpha), 8, Color(0, 0, 0, 0), 0), cr)
		var ink := Color(0.06, 0.08, 0.12, alpha)
		_text(ci, font, Vector2(cr.get_center().x - kw * 0.5, mid + px * 0.36), cap, px, ink, false)
		left += cw + 12.0
	var text := String(line.get("text", ""))
	var tpx := px
	while tpx > 12 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > right - left:
		tpx -= 1
	_text(ci, font, Vector2(left, mid + tpx * 0.36), text, tpx, Color(GOLD, alpha))

## The way-to-go arrow ending at `end` (right edge, row middle); returns the x where it starts.
static func _arrow(ci: CanvasItem, end: Vector2, row: float, dir: Vector2, alpha: float) -> float:
	var s := row * 0.2
	var at := Vector2(end.x - s * 1.4, end.y)
	var perp := Vector2(-dir.y, dir.x)
	ci.draw_circle(at, s * 1.25, Color(MINT, 0.18 * alpha))
	ci.draw_colored_polygon(PackedVector2Array([at + dir * s, at - dir * s * 0.6 + perp * s * 0.75,
		at - dir * s * 0.6 - perp * s * 0.75]), Color(MINT, alpha))
	return at.x - s * 1.25

static func _box(col: Color, rad: float, border: Color, bw: int) -> StyleBoxFlat:
	return HudStyle.box(col, int(rad), border, bw)

static func _text(ci: CanvasItem, font: Font, p: Vector2, s: String, px: int, col: Color, outline := true) -> void:
	if outline:
		ci.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, Color(0, 0, 0, 0.55 * col.a))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
