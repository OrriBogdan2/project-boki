class_name TutorialHud
extends RefCounted
## What the Trial Expedition shows on screen (the beam and the edge arrow are Tutorial and Hud._draw_waypoint).
## Each lesson opens with a calm card in the middle of the screen: the Trial's name and the lesson
## number, one instruction with its key, a few plain words on why, and a looping clip of the ability
## where one helps. The world waits behind it until a key is pressed. Then a pill at the bottom-centre
## holds the instruction while you do it, and the message lane sits in the top-right. While the card
## is up other popups (messages, Boki bubbles) wait.

const MINT := Color("8fe3c8")
const GOLD := Color("f2c84a")
const PANEL := Color(0.04, 0.05, 0.08, 0.9)
const CARD_PANEL := Color(0.05, 0.07, 0.11, 0.96)
const DIM := Color(0, 0, 0, 0.35)       # over the waiting world behind the card
const PILL_W := 0.35        # of the screen width: the widest the pill gets
const CARD_W := 0.5         # of the screen width: the lesson card
const CARD_H := 0.36        # of the screen height
const CLIP_H := 0.5         # of the card's height: the clip's stage (16:9)
const DETAIL_LINES := 4     # the card's plain-words lines wrap to at most this many

## The lanes: the lesson card, the pill and the message column (Rect2 each), for a screen size.
static func lanes(sz: Vector2) -> Dictionary:
	var w := sz.x * PILL_W
	var ph := sz.y * 0.065
	var cs := Vector2(sz.x * CARD_W, sz.y * CARD_H)
	return {
		"card": Rect2(Vector2((sz.x - cs.x) * 0.5, sz.y * 0.47 - cs.y * 0.5), cs),
		"pill": Rect2(Vector2((sz.x - w) * 0.5, sz.y * 0.73), Vector2(w, ph)),
		"toast": Rect2(Vector2(sz.x * 0.68, sz.y * 0.02), Vector2(sz.x * 0.32 - 12.0, sz.y * 0.21)),
	}

static func draw(h, sz: Vector2) -> void:
	var tu: Tutorial = h.m.tut
	if tu.step < 0 or tu.step >= Tutorial.steps().size():
		return
	var ln := lanes(sz)
	if tu.card:
		_card(h, sz, ln["card"], tu)
		return
	var pr: Rect2 = ln["pill"]
	_pill(h, pr, tu)
	_pill_extras(h, pr, tu)

## The lesson card: the Trial's name and lesson number, the line with its key, the why, the clip's
## space on the right, and what to press to go on.
static func _card(h, sz: Vector2, r: Rect2, tu: Tutorial) -> void:
	h.c.draw_rect(Rect2(Vector2.ZERO, sz), DIM)
	h._rounded(r, CARD_PANEL, 18, Color(MINT, 0.35), 2)
	var pad := r.size.y * 0.09
	var left := r.position.x + pad
	var right := r.end.x - pad
	if tu.preview() != "":
		right -= clip_size(sz).x + pad
	var kpx := int(sz.y * 0.02)
	var y := r.position.y + pad + kpx
	var ls: Array = tu.lesson()
	h._text(Vector2(left, y), "TRIAL EXPEDITION  ·  LESSON %d OF %d" % [ls[0], ls[1]], kpx, MINT, h.big)
	var row := sz.y * 0.06
	var mid := y + 12.0 + row * 0.5
	var px := int(row * 0.5)
	var tx := left
	if tu.key_cap != "":
		tx += _keycap(h, Vector2(left, mid), row, px, tu.key_cap) + 14.0
	var tpx := px
	while tpx > 16 and h.big.get_string_size(tu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > right - tx:
		tpx -= 1
	h._text(Vector2(tx, mid + tpx * 0.36), tu.text, tpx, GOLD, h.big)
	var dy := mid + row * 0.5 + kpx * 0.6
	if tu.detail != "":
		var w := TutorialText.wrap(h.big, tu.detail, int(sz.y * 0.024), right - left, DETAIL_LINES)
		for one in w["lines"]:
			dy += float(w["px"]) * 1.3
			h._text(Vector2(left, dy), String(one), int(w["px"]), Color(1, 1, 1, 0.88), h.big)
	if tu.card_t >= Tutorial.READ_T:
		h._text(Vector2(left, r.end.y - pad * 0.8), "Press any key to try it", kpx, Color(1, 1, 1, 0.6), h.big)

## The clip's stage size for a screen size (16:9, a share of the card's height).
static func clip_size(sz: Vector2) -> Vector2:
	var tall := sz.y * CARD_H * CLIP_H
	return Vector2(tall * 16.0 / 9.0, tall)

## Puts the lesson's ability clip on the card (made when the card opens, freed when it closes).
static func sync_clip(h, tu: Tutorial) -> void:
	var want := tu.preview() if tu.card else ""
	if tu.clip != null and (want == "" or tu.clip.slot != want):
		tu.clip.queue_free()
		tu.clip = null
	if want == "":
		return
	var sz: Vector2 = h.c.size
	if tu.clip == null:
		tu.clip = AbilityClip.make(tu.m.player.ak.id, want, clip_size(sz))
		tu.clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.c.add_child(tu.clip)
	var r: Rect2 = lanes(sz)["card"]
	var pad := r.size.y * 0.09
	tu.clip.position = Vector2(r.end.x - pad - tu.clip.size.x, r.position.y + pad * 0.7)

## A key cap with its left edge at `at.x`, centred on `at.y`; returns its width.
static func _keycap(h, at: Vector2, row: float, px: int, key: String) -> float:
	var key_w: float = h.big.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var cap_w := maxf(row * 0.7, key_w + 20.0)
	var cr := Rect2(Vector2(at.x, at.y - row * 0.3), Vector2(cap_w, row * 0.6))
	h._panel(cr, Color(0.93, 0.95, 0.98), 10)
	h._ctext(cr.get_center() + Vector2(0, px * 0.36), key, px, Color(0.06, 0.08, 0.12), h.big)
	return cap_w

## The pill: the lesson's line with its key cap on the left and the counter on the right.
static func _pill(h, r: Rect2, tu: Tutorial) -> void:
	h._panel(r, PANEL, 14)
	if tu.nag_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 8.0)
		h.c.draw_rect(r, Color(MINT, 0.7 * pulse), false, 3.0)
	var row := r.size.y
	var mid := r.position.y + row * 0.5
	var px := int(row * 0.46)
	var left := r.position.x + 14.0
	var n := tu.progress_text()
	var n_w: float = h.big.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var right: float = r.end.x - 14.0 - (n_w + 12.0 if n != "" else 0.0)
	if tu.key_cap != "":
		left += _keycap(h, Vector2(left, mid), row, px, tu.key_cap) + 14.0
	var tpx := px
	while tpx > 16 and h.big.get_string_size(tu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > right - left:
		tpx -= 1
	h._text(Vector2(left, mid + tpx * 0.36), tu.text, tpx, GOLD, h.big)
	if n != "":
		h._text(Vector2(r.end.x - 14.0 - n_w, mid + px * 0.36), n, px, MINT, h.big)

## The scout hint above the pill and the outpost's defend bar under it.
static func _pill_extras(h, r: Rect2, tu: Tutorial) -> void:
	var hint := tu.scout_hint()
	if hint != "":
		h._ctext(Vector2(r.get_center().x, r.position.y - 14.0), hint, int(r.size.y * 0.34), MINT, h.big)
	if tu.id() in ["uplink", "defend"]:
		var o := tu.outpost()
		if not o.is_empty():
			var br := Rect2(Vector2(r.position.x + 20.0, r.end.y + 6.0), Vector2(r.size.x - 40.0, 6.0))
			h._bar(br, clampf(float(o["prog"]), 0.0, 1.0), ExitModels.UPLINK)

## Where the interact prompt ("Hold F to open") goes: above the pill in the Trial, else its usual spot.
static func prompt_y(h, sz: Vector2) -> float:
	return sz.y - 222.0 if h.m.tut == null else lanes(sz)["pill"].position.y - 64.0

## During the Trial the message lane is the top-right column, clear of the card and the pill
## (Tutorial holds it while the card is up).
static func place_msgs(lane: MsgLane, sz: Vector2) -> void:
	var r: Rect2 = lanes(sz)["toast"]
	lane.top = r.position.y
	lane.right_edge = r.end.x
