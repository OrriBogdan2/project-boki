class_name TextCache
extends RefCounted
## Shaped text kept between frames (item 94). Font.draw_string shapes through a small per-font cache
## (64 lines), and the HUD draws far more distinct strings than that each frame, so every label was
## laid out again every frame. Here a string is shaped once per font and size (a TextLine) and
## reused until its text changes; widths come from the same line. Hud._text / _ctext and
## HudStyle.text / ctext draw through it; the plates' level badges measure with it.

const CAP := 1500              # lines kept per font and size before that bucket starts over
static var _lines := {}        # font id * 256 + size -> {text: TextLine}
static var shaped := 0         # lines shaped so far (checks and the probe read it)

static func line(font: Font, s: String, fs: int) -> TextLine:
	var key := font.get_instance_id() * 256 + clampi(fs, 0, 255)
	var bucket: Dictionary = _lines.get(key, {})
	if bucket.is_empty():
		_lines[key] = bucket
	var tl: TextLine = bucket.get(s)
	if tl == null:
		if bucket.size() >= CAP:
			bucket.clear()
		tl = TextLine.new()
		tl.add_string(s, font, fs)
		bucket[s] = tl
		shaped += 1
	return tl

static func width(font: Font, s: String, fs: int) -> float:
	return line(font, s, fs).get_size().x

## Left-aligned at `p` (the baseline, as CanvasItem.draw_string), with an outline under it when
## `outline` > 0.
static func draw(c: CanvasItem, font: Font, p: Vector2, s: String, fs: int, col: Color, outline := 0,
		outline_col := Color(0, 0, 0, 0.55)) -> void:
	if s == "":
		return
	var tl := line(font, s, fs)
	var at := Vector2(p.x, p.y - tl.get_line_ascent())
	var rid := c.get_canvas_item()
	if outline > 0:
		tl.draw_outline(rid, at, outline, outline_col)
	tl.draw(rid, at, col)
