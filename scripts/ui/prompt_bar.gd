class_name PromptBar
extends RefCounted
## The prompt over the bottom of the screen ("Reviving Kael · stay in the ring"), in the same bar style
## as the plates and slots: a dark soft-cornered backing with a hairline edge in the prompt's colour, the
## words crisp on it, and for a hold a rounded track with a rounded fill and a top gloss under them.

const PAD_X := 20.0            # px of backing each side of the words
const MIN_W := 240.0           # px: a short word still gets a bar worth reading
const TEXT_H := 30.0           # px: the backing's height with only words
const BAR_H := 8.0             # px: the progress bar's thickness
const BAR_ROOM := 16.0         # px the backing grows by to hold the bar
const FONT_SIZE := 16

## Draws the prompt centred on `mid` (the words' baseline). `prog` is the hold's progress 0..1, or
## negative for a prompt with nothing to hold (no bar).
static func draw(c: CanvasItem, mid: Vector2, text: String, col: Color, prog: float) -> void:
	var w := maxf(MIN_W, TextCache.width(HudStyle.BODY, text, FONT_SIZE) + PAD_X * 2.0)
	var h := TEXT_H + (BAR_ROOM if prog >= 0.0 else 0.0)
	var r := Rect2((mid + Vector2(-w * 0.5, -22.0)).round(), Vector2(roundf(w), h))
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 9, Color(col, 0.6), 1), r)
	var tw := TextCache.width(HudStyle.BODY, text, FONT_SIZE)
	HudStyle.text(c, Vector2(roundf(mid.x - tw * 0.5), roundf(mid.y)), text, FONT_SIZE, col, 2, HudStyle.BODY)
	if prog >= 0.0:
		var bar := Rect2(r.position + Vector2(PAD_X * 0.7, TEXT_H + 1.0), Vector2(r.size.x - PAD_X * 1.4, BAR_H))
		_bar(c, bar, prog, col)

## A rounded track, the rounded fill over it (never thinner than its own caps) and a gloss along its top.
static func _bar(c: CanvasItem, r: Rect2, prog: float, col: Color) -> void:
	c.draw_style_box(HudStyle.box(Color(col.darkened(0.72), 0.92), 4, Color(0, 0, 0, 0), 0), r)
	var f := clampf(prog, 0.0, 1.0)
	if f <= 0.0:
		return
	var fill := Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * f), r.size.y))
	c.draw_style_box(HudStyle.box(col, 4, Color(0, 0, 0, 0), 0), fill)
	c.draw_style_box(HudStyle.box(Color(1, 1, 1, 0.25), 1, Color(0, 0, 0, 0), 0),
			Rect2(fill.position + Vector2(3, 1), Vector2(fill.size.x - 6.0, 2.0)))
