class_name KeyCounter
extends RefCounted
## The chest-key count on the HUD: a small brass key and a number, right-aligned to `anchor`
## (the Hud puts it on the weapon card, right under the utility belt; move the call, not this file, if
## the belt moves). Dim at zero, bright and pulsing for a moment when the count goes up.

const COL := Color("f2c84a")
static var _last := {}      # hunter id -> [count, time it last rose]

static func draw(c: Control, p: Hunter, anchor: Vector2, font: Font) -> void:
	var m = p.m
	if m == null or not m.get("chests") or (p.chest_keys == 0 and not (m.chests as Array).any(func(ch): return not ch["open"] and not ch.get("free", false))):
		return
	var rec: Array = _last.get(p.nid, [0, -9.0])
	if p.chest_keys > int(rec[0]):
		rec[1] = m.time
	rec[0] = p.chest_keys
	_last[p.nid] = rec
	var pop := clampf(1.0 - (m.time - float(rec[1])) / 0.7, 0.0, 1.0)
	var col := COL if p.chest_keys > 0 else Color(COL, 0.4)
	var txt := "%d" % p.chest_keys
	var s := 22.0 + pop * 5.0
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var at := anchor + Vector2(-w - 16.0, 0)
	c.draw_rect(Rect2(at + Vector2(-16, -14), Vector2(w + 36, 26)), Color(0.04, 0.04, 0.07, 0.6))
	Icons.draw(c, "key", at + Vector2(-2, -1), s * 0.5, col)
	c.draw_string(font, at + Vector2(10, 7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
