class_name ReminderCard
extends RefCounted
## The short reminder card when you try something that can't work ("Chests need a key"): one line on
## a small card a little below the middle of the screen, clear of the hunter and the interact prompt.
## Only one at a time (MatchTips.remind replaces the last); it fades out over its last moments.

const FADE_S := 0.3         # s: the fade at the end
const PX := 20              # px: the line's type size
const COL := Color("ffd0c4")

static func draw(h, sz: Vector2) -> void:
	var tips: MatchTips = h.m.tips
	if tips == null or tips.remind_t <= 0.0 or Record.clean():
		return
	var a := clampf(tips.remind_t / FADE_S, 0.0, 1.0)
	var w: float = h.big.get_string_size(tips.remind_text, HORIZONTAL_ALIGNMENT_LEFT, -1, PX).x + 44.0
	var r := Rect2(Vector2((sz.x - w) * 0.5, sz.y * 0.6), Vector2(w, PX * 2.2))
	h._rounded(r, Color(0.08, 0.05, 0.06, 0.9 * a), 12, Color(COL, 0.5 * a), 2)
	h._ctext(r.get_center() + Vector2(0, PX * 0.36), tips.remind_text, PX, Color(COL, a), h.big)
