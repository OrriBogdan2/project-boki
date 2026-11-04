class_name TutorialHud
extends RefCounted
## What the tutorial shows on screen (the beam and the edge arrow are Tutorial and Hud._draw_waypoint):
## the full-screen intro card, a big centred card for each new step that shrinks into an objective
## pill at the bottom, a check mark when a step is done, a hint to crouch when the target is far.

const MINT := Color("8fe3c8")
const GOLD := Color("f2c84a")
const CARD_W := 900.0
const POP_T := 0.25        # s the card takes to pop in
const SHRINK_T := 0.45     # s it takes to shrink into the pill

static func draw(h, sz: Vector2) -> void:
	var tu: Tutorial = h.m.tut
	if tu.intro:
		_intro(h, sz, tu)
		return
	if tu.step < 0 or tu.step >= Tutorial.steps().size():
		return
	_dim(h, sz, tu)
	var cw := minf(CARD_W, sz.x - 80.0)
	var pw := minf(780.0, sz.x - 60.0)
	var big_r := Rect2(Vector2(sz.x * 0.5 - cw * 0.5, sz.y * 0.28), Vector2(cw, 250.0))
	var pill_r := Rect2(Vector2(sz.x * 0.5 - pw * 0.5, sz.y - 200.0), Vector2(pw, 66.0))
	var k := clampf((tu.card_t - Tutorial.CARD_T) / SHRINK_T, 0.0, 1.0)
	if k >= 1.0:
		_pill(h, pill_r, tu)
	else:
		var e := 1.0 - pow(1.0 - k, 3.0)
		var pop := _back(clampf(tu.card_t / POP_T, 0.0, 1.0))
		var r := Rect2(big_r.position.lerp(pill_r.position, e), big_r.size.lerp(pill_r.size, e))
		if k <= 0.0:
			var cen := r.get_center()
			r = Rect2(cen - r.size * 0.5 * pop, r.size * pop)
		h._panel(r, Color(0.04, 0.05, 0.08, 0.93), 18)
		if k < 0.5:
			_card_text(h, r, tu, 1.0 - k * 2.0)
		else:
			_pill_text(h, r, tu, (k - 0.5) * 2.0)
	if tu.done_t > 0.0:
		_check(h, sz, tu.done_t / Tutorial.DONE_T)
	if tu.spot_t > 0.0:
		h._ctext(Vector2(sz.x * 0.5, sz.y * 0.2), "You spotted it!", 44, GOLD, h.big)

static func _intro(h, sz: Vector2, tu: Tutorial) -> void:
	h.c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.8))
	var cx := sz.x * 0.5
	h._ctext(Vector2(cx, sz.y * 0.2), "TRAINING RUN", 30, MINT, h.big)
	h._ctext(Vector2(cx, sz.y * 0.31), "Follow your Boki and the marker", 54, Color.WHITE, h.big)
	var w := minf(CARD_W, sz.x - 80.0)
	var r := Rect2(Vector2(cx - w * 0.5, sz.y * 0.4), Vector2(w, 190.0))
	h._panel(r, Color(0.08, 0.1, 0.14, 0.95), 18)
	_card_text(h, r, tu, 1.0)
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	var b := Rect2(Vector2(cx - 150.0, sz.y * 0.4 + 230.0), Vector2(300.0, 66.0))
	h._panel(b, Color(MINT, pulse), 33)
	h._ctext(Vector2(cx, b.position.y + 45.0), "Got it", 36, Color("10151c"), h.big)
	h._ctext(Vector2(cx, b.end.y + 34.0), "Press any key", 22, Color(1, 1, 1, 0.7), h.big)

## A big key cap on the left, the headline (wrapped) and the sub line.
static func _card_text(h, r: Rect2, tu: Tutorial, a: float) -> void:
	var left := r.position.x + 36.0
	if tu.key_cap != "":
		var cap_w := maxf(96.0, h.big.get_string_size(tu.key_cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x + 36.0)
		var cr := Rect2(Vector2(left, r.get_center().y - 48.0), Vector2(cap_w, 96.0))
		h._panel(cr, Color(0.93, 0.95, 0.98, a), 16)
		h._ctext(cr.get_center() + Vector2(0, 16), tu.key_cap, 44, Color(0.06, 0.08, 0.12, a), h.big)
		left += cap_w + 28.0
	var width := r.end.x - left - 30.0
	var lines := _wrap(h.big, tu.text, 38, width)
	var y := r.get_center().y - (lines.size() * 44.0 + (34.0 if tu.sub != "" else 0.0)) * 0.5 + 34.0
	for ln in lines:
		h._text(Vector2(left, y), ln, 38, Color(GOLD, a), h.big)
		y += 44.0
	if tu.sub != "":
		for ln in _wrap(h.body, tu.sub, 22, width):
			h._text(Vector2(left, y + 4.0), ln, 22, Color(1, 1, 1, 0.88 * a), h.body)
			y += 28.0

static func _pill(h, r: Rect2, tu: Tutorial) -> void:
	h._panel(r, Color(0.04, 0.05, 0.08, 0.93), 18)
	_pill_text(h, r, tu, 1.0)
	var hint := tu.scout_hint()
	if hint != "":
		var hr := Rect2(Vector2(r.position.x + r.size.x * 0.5 - 250.0, r.position.y - 46.0), Vector2(500.0, 38.0))
		h._panel(hr, Color(0.04, 0.05, 0.08, 0.9), 12)
		h._ctext(hr.get_center() + Vector2(0, 8), hint, 20, MINT, h.big)
	if tu.id() == "defend":
		var o := tu.outpost()
		if not o.is_empty():
			var br := Rect2(Vector2(r.position.x + 20.0, r.end.y + 8.0), Vector2(r.size.x - 40.0, 8.0))
			h._bar(br, clampf(float(o["prog"]), 0.0, 1.0), ExitModels.UPLINK)

static func _pill_text(h, r: Rect2, tu: Tutorial, a: float) -> void:
	var n := "%d/%d" % [mini(tu.step + 1, Tutorial.steps().size()), Tutorial.steps().size()]
	h._text(r.position + Vector2(22, 42), n, 20, Color(MINT, a), h.big)
	h._ctext(r.get_center() + Vector2(24, 11), tu.pill, 30, Color(GOLD, a), h.big)

## A check mark that pops and fades.
static func _check(h, sz: Vector2, k: float) -> void:
	var c := Vector2(sz.x * 0.5, sz.y * 0.45)
	var s := 70.0 * (1.0 + (1.0 - k) * 0.5)
	var col := Color(MINT, clampf(k * 1.5, 0.0, 1.0))
	h.c.draw_circle(c, s * 1.15, Color(0, 0, 0, 0.45 * col.a))
	var pts := PackedVector2Array([Vector2(-0.5, 0.05), Vector2(-0.15, 0.45), Vector2(0.55, -0.4)])
	for i in pts.size():
		pts[i] = c + pts[i] * s
	h.c.draw_polyline(pts, col, 14.0, true)

## The screen edges dim for a moment while a new card is up.
static func _dim(h, sz: Vector2, tu: Tutorial) -> void:
	var a := clampf(1.0 - maxf(0.0, tu.card_t - 1.6) / 0.9, 0.0, 1.0) * clampf(tu.card_t / 0.15, 0.0, 1.0)
	if a <= 0.0:
		return
	for i in 6:
		var w := sz.x * 0.05 * (6 - i) / 6.0 * 2.0
		var v := sz.y * 0.05 * (6 - i) / 6.0 * 2.0
		var col := Color(0, 0, 0, 0.09 * a)
		h.c.draw_rect(Rect2(0, 0, w, sz.y), col)
		h.c.draw_rect(Rect2(sz.x - w, 0, w, sz.y), col)
		h.c.draw_rect(Rect2(0, 0, sz.x, v), col)
		h.c.draw_rect(Rect2(0, sz.y - v, sz.x, v), col)

static func _back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

static func _wrap(font: Font, txt: String, px: int, width: float) -> Array:
	var out: Array = []
	var line := ""
	for wd in txt.split(" "):
		var tryl: String = wd if line == "" else line + " " + wd
		if line != "" and font.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			out.append(line)
			line = wd
		else:
			line = tryl
	if line != "":
		out.append(line)
	return out
