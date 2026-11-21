class_name SelfCcLine
extends RefCounted
## One compact line under your vitals while crowd control is on you: each effect's name and a bar
## shrinking over its time, the one that takes the most away first (the CC lockouts order: stun and
## Daze forbid everything, root your feet, Ground your leaps; Slow forbids nothing). Words, colours
## and times come from HudPlate.statuses, so your line and the plates agree. Drawn by HudVitals.

const ORDER := ["STUNNED", "DAZED", "ROOTED", "GROUNDED", "SLOWED"]
const FS := 10             # px: the name's font size
const BAR_W := 44.0        # px: each effect's bar
const BAR_H := 4.0         # px
const GAP := 12.0          # px between one effect and the next

static var _full := {}     # word -> the longest time left seen while it lasts: the bar's full length

## The effects on `p` now as [word, colour, seconds left, fraction left], highest priority first.
static func entries(p: Ent) -> Array:
	var on := {}
	for st in HudPlate.statuses(p):
		if ORDER.has(st[2]):
			on[st[2]] = st
	var out := []
	for word in ORDER:
		if not on.has(word):
			_full.erase(word)
			continue
		var left := float(on[word][3])
		_full[word] = maxf(float(_full.get(word, 0.0)), left)
		out.append([word, on[word][1], left, left / maxf(0.01, float(_full[word]))])
	return out

## The line from `at` (top left), at most `w` wide; an effect that would not fit is left off.
static func draw(c: CanvasItem, at: Vector2, w: float, p: Hunter) -> void:
	var x := at.x
	for e in entries(p):
		var col: Color = e[1]
		var nw := HudStyle.BIG.get_string_size(e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		if x + nw + 4.0 + BAR_W > at.x + w:
			break
		HudStyle.text(c, Vector2(x, at.y + 9.0), e[0], FS, col)
		var r := Rect2(Vector2(x + nw + 4.0, at.y + 4.0), Vector2(BAR_W, BAR_H))
		c.draw_rect(r.grow(1.0), HudStyle.SHADE)
		HudStyle.strip(c, r, float(e[3]), col)
		x = r.end.x + GAP
