class_name HudTopRow
extends RefCounted
## The HUD's top-row widgets laid out as rows that grow to their text, so no two cells ever draw over
## each other: the squad counters (top right) and the match clock under the minimap (top left: timer,
## exit line, level chip). A cell is never shrunk or clipped; the row gets wider instead. Hud calls
## these two draws; `rects` is what they drew last frame, for --hudref-check's no-overlap assert.

const PAD := 10.0          # px: inside a row's end
const GAP := 10.0          # px: kept between two cells' text
const COUNTER_ICON_W := 28.0   # px: a counter's icon and the space after it
const COUNTER_MIN_W := 58.0    # px: a counter cell at one or two digits
const COUNTER_FONT := 15       # px
const CLOCK_FONT := 16         # px: the timer
const LINE_FONT := 11          # px: the exit line
const CHIP_FONT := 12          # px: the level chip
const CLOCK_H := 30.0          # px
const COUNTER_H := 34.0        # px
const EDGE := 18.0             # px: from the window's edge
const CHIP_COLOR := Color("ffd27a")
const DIVIDER := Color(1, 1, 1, 0.1)
const PLATE := Color(0.04, 0.05, 0.08, 0.86)

## id -> Rect2 of each cell drawn last frame: "counter0".., "counters", "timer", "exit", "level", "clock"
static var rects := {}

## The four squad counters ([icon, text, colour] each), right-aligned. Returns the row's bottom edge.
static func draw_counters(H, sz: Vector2, cells: Array) -> float:
	var widths: Array = []
	var total := 0.0
	for cell in cells:
		var w := maxf(COUNTER_MIN_W, COUNTER_ICON_W + TextCache.width(H.big, String(cell[1]), COUNTER_FONT) + PAD)
		widths.append(w)
		total += w
	var row := Rect2(Vector2(sz.x - EDGE - total, EDGE), Vector2(total, COUNTER_H))
	H._rounded(row, PLATE, 8)
	rects["counters"] = row
	var x := row.position.x
	for i in cells.size():
		var col: Color = cells[i][2]
		Icons.draw(H.c, String(cells[i][0]), Vector2(x + 17, row.position.y + 17), 7.0, Color(col, 0.85))
		H._text(Vector2(x + COUNTER_ICON_W, row.position.y + 23), String(cells[i][1]), COUNTER_FONT, col, H.big)
		var text_at := Vector2(x + COUNTER_ICON_W, row.position.y)
		rects["counter%d" % i] = Rect2(text_at, Vector2(widths[i] - COUNTER_ICON_W, COUNTER_H))
		if i > 0:
			H.c.draw_line(Vector2(x, row.position.y + 7), Vector2(x, row.end.y - 7), DIVIDER, 1.0)
		x += widths[i]
	return row.end.y

## Where the clock bar's cells go: {"clock", "timer", "exit", "level"} rects (no "level" without a chip).
## The timer sits at the left, the level chip at the right, the exit line in the gap between. `bar` is
## the bar at the minimap's width; it grows past that when the three need it.
static func clock_cells(font: Font, bar: Rect2, timer: String, line: String, chip: String) -> Dictionary:
	var wt := TextCache.width(font, timer, CLOCK_FONT)
	var wl := TextCache.width(font, line, LINE_FONT)
	var wc := TextCache.width(font, chip, CHIP_FONT)
	bar.size.x = maxf(bar.size.x, PAD * 2.0 + wt + wl + wc + GAP * (2.0 if chip != "" else 1.0))
	var t_end := bar.position.x + PAD + wt
	var c_start := bar.end.x - PAD - wc
	var lx := clampf((t_end + c_start - wl) * 0.5, t_end + GAP, c_start - GAP - wl)
	var cells := {"clock": bar, "timer": Rect2(Vector2(bar.position.x + PAD, bar.position.y), Vector2(wt, bar.size.y)),
		"exit": Rect2(Vector2(lx, bar.position.y), Vector2(wl, bar.size.y))}
	if chip != "":
		cells["level"] = Rect2(Vector2(c_start, bar.position.y), Vector2(wc, bar.size.y))
	return cells

## The clock bar (timer and line are [text, colour]). Returns the bar actually drawn.
static func draw_clock(H, bar: Rect2, timer: Array, line: Array, chip: String) -> Rect2:
	var cells := clock_cells(H.big, bar, timer[0], line[0], chip)
	rects.merge(cells, true)
	if not cells.has("level"):
		rects.erase("level")
	bar = cells["clock"]
	H._rounded(bar, PLATE, 8)
	H._text(Vector2(cells["timer"].position.x, bar.position.y + 20), timer[0], CLOCK_FONT, timer[1], H.big)
	H._text(Vector2(cells["exit"].position.x, bar.position.y + 19), line[0], LINE_FONT, line[1], H.big)
	if chip != "":
		H._text(Vector2(cells["level"].position.x, bar.position.y + 19), chip, CHIP_FONT, CHIP_COLOR, H.big)
	return bar
