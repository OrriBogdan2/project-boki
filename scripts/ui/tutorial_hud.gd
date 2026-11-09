class_name TutorialHud
extends RefCounted
## What the tutorial shows on screen (the beam and the edge arrow are Tutorial and Hud._draw_waypoint).
## Everything has its own lane so nothing overlaps: the short first-time intro card (the one thing that
## pauses play), a small banner at the top-centre for each new step that settles into a pill at the
## bottom-centre, a quiet check beside the pill, and the message lane in the top-right. Nothing sits in
## the middle of the screen, where the hunter, the Boki and the target are. While the banner is up other
## popups (messages, Boki bubbles, the scout hint) wait. A Skip button sits left of the banner the whole run.

const MINT := Color("8fe3c8")
const GOLD := Color("f2c84a")
const BAR_W := 0.35         # of the screen width: the widest the banner and the pill get
const BAR_H := 0.085        # of the screen height: the banner's height (the pill is a bit lower)
const SLIDE_T := 0.25       # s the banner takes to slide in
const FADE_T := 0.3         # s it takes to hand over to the pill
const PANEL := Color(0.04, 0.05, 0.08, 0.9)
const SKIP_W := 150.0       # px: the Skip button's width
const SKIP_GAP := 14.0      # px between it and the banner

## The lanes: the banner, the pill, the check mark and the message column (Rect2 each), for a screen size.
static func lanes(sz: Vector2) -> Dictionary:
	var w := sz.x * BAR_W
	var bh := sz.y * BAR_H
	var ph := sz.y * 0.065
	return {
		"banner": Rect2(Vector2((sz.x - w) * 0.5, sz.y * 0.035), Vector2(w, bh)),
		"pill": Rect2(Vector2((sz.x - w) * 0.5, sz.y * 0.73), Vector2(w, ph)),
		"check": Rect2(Vector2((sz.x + w) * 0.5 + 10.0, sz.y * 0.73), Vector2(ph, ph)),
		"toast": Rect2(Vector2(sz.x * 0.68, sz.y * 0.02), Vector2(sz.x * 0.32 - 12.0, sz.y * 0.21)),
		"intro": Rect2(Vector2(sz.x * 0.3, sz.y * 0.36), Vector2(sz.x * 0.4, sz.y * 0.28)),
	}

static func draw(h, sz: Vector2) -> void:
	var tu: Tutorial = h.m.tut
	if tu.intro:
		_intro(h, sz, tu)
		return
	if tu.step < 0 or tu.step >= Tutorial.steps().size():
		return
	var ln := lanes(sz)
	var k := 1.0 if banner_blocked(h, ln["banner"], tu) else clampf((tu.card_t - Tutorial.CARD_T) / FADE_T, 0.0, 1.0)
	if k < 1.0:
		var slide := 1.0 - pow(1.0 - clampf(tu.card_t / SLIDE_T, 0.0, 1.0), 3.0)
		var r: Rect2 = ln["banner"]
		r.position.y -= (1.0 - slide) * (r.end.y + 4.0)
		_bar(h, r, tu, 1.0 - k, false)
	var pr: Rect2 = ln["pill"]
	_bar(h, pr, tu, k, true)
	if k >= 1.0:
		_pill_extras(h, pr, tu)
		_detail(h, pr, tu)
	if tu.done_t > 0.0:
		_check(h, ln["check"], tu.done_t / Tutorial.DONE_T)

## Is the marker's pin about where the banner would go? Then the banner is skipped and the pill shows at once.
static func banner_blocked(h, banner: Rect2, tu: Tutorial) -> bool:
	if tu.target == Vector3.INF or h.m.cam == null or h.m.cam.is_position_behind(tu.target):
		return false
	var sp: Vector2 = h.m.cam.unproject_position(tu.target)
	return Rect2(sp - Vector2(130.0, 110.0), Vector2(260.0, 190.0)).intersects(banner)

## One line with its key cap on the left (and the counter on the right): the banner and the pill.
static func _bar(h, r: Rect2, tu: Tutorial, a: float, is_pill: bool) -> void:
	if a <= 0.0:
		return
	var pulse := 0.0
	if is_pill and tu.nag_t > 0.0:
		pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 8.0)
	h._panel(r, Color(PANEL.r, PANEL.g, PANEL.b, PANEL.a * a), 14)
	if pulse > 0.0:
		h.c.draw_rect(r, Color(MINT, 0.7 * pulse), false, 3.0)
	var row := r.size.y
	var mid := r.position.y + row * 0.5
	var px := int(row * (0.46 if is_pill else 0.42))
	var left := r.position.x + 14.0
	var n := tu.progress_text()
	var n_w: float = h.big.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var right: float = r.end.x - 14.0 - (n_w + 12.0 if n != "" else 0.0)
	if tu.key_cap != "":
		var key_w: float = h.big.get_string_size(tu.key_cap, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var cap_w := maxf(row * 0.7, key_w + 20.0)
		var cr := Rect2(Vector2(left, mid - row * 0.3), Vector2(cap_w, row * 0.6))
		h._panel(cr, Color(0.93, 0.95, 0.98, a), 10)
		h._ctext(cr.get_center() + Vector2(0, px * 0.36), tu.key_cap, px, Color(0.06, 0.08, 0.12, a), h.big)
		left += cap_w + 14.0
	var tpx := px
	while tpx > 16 and h.big.get_string_size(tu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > right - left:
		tpx -= 1
	h._text(Vector2(left, mid + tpx * 0.36), tu.text, tpx, Color(GOLD, a), h.big)
	if n != "":
		h._text(Vector2(r.end.x - 14.0 - n_w, mid + px * 0.36), n, px, Color(MINT, a), h.big)

## The scout hint above the pill (not while the banner is up).
static func _pill_extras(h, r: Rect2, tu: Tutorial) -> void:
	var hint := tu.scout_hint()
	if hint != "":
		h._ctext(Vector2(r.get_center().x, r.position.y - 14.0), hint, int(r.size.y * 0.34), MINT, h.big)

## The plain line under the pill (the summon beats): wraps to two lines on its own panel.
static func _detail(h, r: Rect2, tu: Tutorial) -> void:
	if tu.detail == "":
		return
	var px := int(r.size.y * 0.3)
	var sz: Vector2 = h.big.get_multiline_string_size(tu.detail, HORIZONTAL_ALIGNMENT_CENTER, r.size.x * 1.3, px)
	var box := Rect2(Vector2(r.get_center().x - sz.x * 0.5 - 12.0, r.end.y + 8.0), sz + Vector2(24.0, 12.0))
	h._panel(box, PANEL, 10)
	h.c.draw_multiline_string(h.big, box.position + Vector2(12.0, 6.0 + px * 0.85), tu.detail,
		HORIZONTAL_ALIGNMENT_CENTER, sz.x, px, -1, Color(1, 1, 1, 0.92))

## The Skip button, left of the banner for the whole run: it ends the tutorial at once, as finished
## (the match's end marks it done, so nothing it gives is lost). Added by Tutorial.update once the Hud is up.
static func add_skip(m: Match) -> Button:
	var b := Button.new()
	b.name = "TutSkip"
	b.text = "Skip tutorial"
	b.focus_mode = Control.FOCUS_NONE
	b.anchor_left = 0.5 - BAR_W * 0.5
	b.anchor_right = b.anchor_left
	b.offset_left = -SKIP_W - SKIP_GAP
	b.offset_right = -SKIP_GAP
	b.anchor_top = 0.035
	b.offset_bottom = 44.0
	b.pressed.connect(func(): Practice.leave(m, true))
	m.hud.add_child(b)
	m.hud.ui_extra.append(b)       # (the mouse over it is not a shot)
	return b

## The first-time intro: short, over a light dim, and the rest of the HUD stays away.
static func _intro(h, sz: Vector2, tu: Tutorial) -> void:
	h.c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.5 * clampf(1.0 - (tu.intro_t - 1.6) / 0.4, 0.0, 1.0)))
	var r: Rect2 = lanes(sz)["intro"]
	h._panel(r, Color(0.06, 0.08, 0.12, 0.94), 18)
	var cx := r.get_center().x
	h._ctext(Vector2(cx, r.position.y + r.size.y * 0.34), "TRAINING RUN", int(sz.y * 0.032), MINT, h.big)
	var y := r.position.y
	h._ctext(Vector2(cx, y + r.size.y * 0.62), "Follow your Boki and the marker", int(sz.y * 0.04), Color.WHITE, h.big)
	h._ctext(Vector2(cx, y + r.size.y * 0.86), "Press any key", int(sz.y * 0.028), Color(1, 1, 1, 0.75), h.big)

## A small check beside the pill when a step is done: it fades, it does not pop over the screen.
static func _check(h, r: Rect2, k: float) -> void:
	var col := Color(MINT, clampf(k * 1.5, 0.0, 1.0))
	var c := r.get_center()
	var s := r.size.y * 0.32
	var pts := PackedVector2Array([Vector2(-0.5, 0.05), Vector2(-0.15, 0.45), Vector2(0.55, -0.4)])
	for i in pts.size():
		pts[i] = c + pts[i] * s
	h.c.draw_polyline(pts, col, 5.0, true)

## Where the interact prompt ("Hold F to open") goes: above the pill in the tutorial, else its usual spot.
static func prompt_y(h, sz: Vector2) -> float:
	return sz.y - 222.0 if h.m.tut == null else lanes(sz)["pill"].position.y - 64.0

## During the tutorial the message lane is the top-right column, clear of the banner and the pill
## (Hud holds it while the banner is up).
static func place_msgs(lane: MsgLane, sz: Vector2) -> void:
	var r: Rect2 = lanes(sz)["toast"]
	lane.top = r.position.y
	lane.right_edge = r.end.x
