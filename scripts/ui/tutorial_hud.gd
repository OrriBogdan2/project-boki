class_name TutorialHud
extends RefCounted
## What the tutorial shows on screen (the beam is Tutorial, the pin and edge arrow Hud._draw_waypoint).
## Everything has its own lane so nothing overlaps: the short first-time intro card (the one thing that
## pauses play), the step panel pinned at the top-centre for the whole step (it pops in for each new
## step, and carries an arrow and the distance while the target is off screen or under the hunter), a
## quiet check beside it, and the message lane in the top-right. Nothing sits in the middle or the
## bottom of the screen, where the hunter, the Boki and the hotbar are. While a new panel is fresh
## (Tutorial.card_up) other popups (messages, Boki bubbles, the scout hint) wait.

const MINT := Color("8fe3c8")
const GOLD := Color("f2c84a")
const BAR_W := 0.35         # of the screen width: the widest the panel gets
const BAR_H := 0.085        # of the screen height: the panel's height (one line)
const POP_T := 0.25         # s the panel takes to drop and pop in
const POP_K := 0.12         # how much bigger than its size the panel starts as it pops in
const GLOW_T := 0.8         # s the bright edge of a new panel takes to settle
const PANEL := Color(0.03, 0.04, 0.07, 0.94)
const DETAIL_K := 1.9       # a panel with a second line is this much taller

static var _ring_at := Rect2()      # the pick ring's slot, as last drawn

## The lanes: the panel, the check mark and the message column (Rect2 each), for a screen size.
static func lanes(sz: Vector2) -> Dictionary:
	var w := sz.x * BAR_W
	var bh := sz.y * BAR_H
	var banner := Rect2(Vector2((sz.x - w) * 0.5, sz.y * 0.035), Vector2(w, bh))
	return {
		"banner": banner,
		"check": Rect2(Vector2(banner.position.x - bh - 10.0, banner.position.y), Vector2(bh, bh)),
		"toast": Rect2(Vector2(sz.x * 0.68, sz.y * 0.02), Vector2(sz.x * 0.32 - 12.0, sz.y * 0.21)),
		"intro": Rect2(Vector2(sz.x * 0.3, sz.y * 0.36), Vector2(sz.x * 0.4, sz.y * 0.28)),
	}

## The panel's rect on screen this frame: its lane, taller with a second line, dropping in as it pops.
static func panel_rect(sz: Vector2, tu: Tutorial) -> Rect2:
	var r: Rect2 = lanes(sz)["banner"]
	r.size.y *= DETAIL_K if tu.detail != "" else 1.0
	var k := clampf(tu.card_t / POP_T, 0.0, 1.0)
	var s := 1.0 + POP_K * sin(k * PI)       # (grows a touch past its size and settles back)
	var drop := (1.0 - pow(1.0 - k, 3.0)) * (r.end.y + 4.0) - (r.end.y + 4.0)
	return Rect2(r.get_center() + Vector2(0, drop) - r.size * s * 0.5, r.size * s)

static func draw(h, sz: Vector2) -> void:
	var tu: Tutorial = h.m.tut
	if tu.intro:
		_intro(h, sz, tu)
		return
	if tu.step < 0 or tu.step >= Tutorial.steps().size():
		return
	var r := panel_rect(sz, tu)
	var dir := Vector2.ZERO
	if tu.target != Vector3.INF and h.m.cam and h.m.player:
		dir = MarkerDir.off_dir(h.m.cam, sz, tu.target, h.m.player.pos)
	_bar(h, r, tu, dir)
	_pick_ring(h, tu)
	if not tu.card_up():
		_extras(h, r, tu)
	if tu.done_t > 0.0:
		_check(h, lanes(sz)["check"], tu.done_t / Tutorial.DONE_T)

## The step's line with its key cap on the left, and on the right the counter and, while the target's
## pin isn't on screen, an arrow pointing the way with the distance.
static func _bar(h, r: Rect2, tu: Tutorial, dir: Vector2) -> void:
	var glow := 1.0 - clampf(tu.card_t / GLOW_T, 0.0, 1.0)
	if tu.nag_t > 0.0:
		glow = maxf(glow, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 8.0))
	h._rounded(r, PANEL, 14, Color(MINT, 0.45 + 0.55 * glow), int(2.0 + 2.0 * glow))
	var row := r.size.y / (DETAIL_K if tu.detail != "" else 1.0)     # the first line's height
	var mid := r.position.y + row * 0.5
	var px := int(row * 0.46)
	var left := r.position.x + 14.0
	var right: float = r.end.x - 14.0
	var n := tu.progress_text()
	if n != "":
		var n_w: float = h.big.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		h._text(Vector2(right - n_w, mid + px * 0.36), n, px, MINT, h.big)
		right -= n_w + 12.0
	if dir != Vector2.ZERO:
		right = _arrow(h, Vector2(right, mid), row, dir, tu) - 10.0
	if tu.key_cap != "":
		var key_w: float = h.big.get_string_size(tu.key_cap, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var cap_w := maxf(row * 0.7, key_w + 20.0)
		var cr := Rect2(Vector2(left, mid - row * 0.3), Vector2(cap_w, row * 0.6))
		h._panel(cr, Color(0.93, 0.95, 0.98), 10)
		h._ctext(cr.get_center() + Vector2(0, px * 0.36), tu.key_cap, px, Color(0.06, 0.08, 0.12), h.big)
		left += cap_w + 14.0
	var tpx := px
	while tpx > 16 and h.big.get_string_size(tu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > right - left:
		tpx -= 1
	h._text(Vector2(left, mid + tpx * 0.36), tu.text, tpx, GOLD, h.big)
	if tu.detail != "":
		_detail(h, r, row, tu.detail)

## The way-to-go arrow ending at `end` (right edge, row middle) with the distance before it; returns
## the x where it starts, so the line fits beside it.
static func _arrow(h, end: Vector2, row: float, dir: Vector2, tu: Tutorial) -> float:
	var at := Vector2(end.x - row * 0.3, end.y)
	var s := row * 0.26
	var perp := Vector2(-dir.y, dir.x)
	h.c.draw_circle(at, s * 1.25, Color(MINT, 0.18))
	h.c.draw_colored_polygon(PackedVector2Array([at + dir * s, at - dir * s * 0.6 + perp * s * 0.75,
		at - dir * s * 0.6 - perp * s * 0.75]), MINT)
	var dist := "%dm" % int(round(Vector2(tu.target.x - tu.m.player.pos.x, tu.target.z - tu.m.player.pos.z).length()))
	var dpx := int(row * 0.34)
	var dw: float = h.big.get_string_size(dist, HORIZONTAL_ALIGNMENT_LEFT, -1, dpx).x
	var x := at.x - s * 1.25 - 6.0 - dw
	h._text(Vector2(x, end.y + dpx * 0.36), dist, dpx, MINT, h.big)
	return x

## The plain-words line under a step's line: wrapped to three lines in the space below it.
static func _detail(h, r: Rect2, row: float, txt: String) -> void:
	var w := TutorialText.wrap(h.big, txt, int(row * 0.27), r.size.x - 28.0, 3)
	var y := r.position.y + row * 0.92
	for ln in w["lines"]:
		y += float(w["px"]) * 1.2
		h._text(Vector2(r.position.x + 14.0, y), String(ln), int(w["px"]), Color(1, 1, 1, 0.88), h.big)

## The scout hint under the panel and the outpost's defend bar just under its edge.
static func _extras(h, r: Rect2, tu: Tutorial) -> void:
	var hint := tu.scout_hint()
	if hint != "":
		h._ctext(Vector2(r.get_center().x, r.end.y + 34.0), hint, int(h.c.size.y * 0.026), MINT, h.big)
	if tu.id() in ["uplink", "defend"]:
		var o := tu.outpost()
		if not o.is_empty():
			var br := Rect2(Vector2(r.position.x + 20.0, r.end.y + 6.0), Vector2(r.size.x - 40.0, 6.0))
			h._bar(br, clampf(float(o["prog"]), 0.0, 1.0), ExitModels.UPLINK)

## A pick step: a pulsing gold ring on the one skill slot that can take the point, an arrow dropping onto it.
## (The slot's rect is the gold "+" HudPanels drew; the last one is kept, so the ring holds between redraws.)
static func _pick_ring(h, tu: Tutorial) -> void:
	var slot := TutorialCamps.pick_slot(tu.id())
	if slot == "":
		_ring_at = Rect2()
		return
	var got: Array = RankMarks.plus_spots.get(slot, [])
	if not got.is_empty() and int(got[1]) >= HudPanels.draws - 1:
		_ring_at = got[0]          # (this draws inside the panel pass, before it marks the slots: last pass's)
	if _ring_at.size == Vector2.ZERO:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	var c := _ring_at.get_center()
	var rad := maxf(_ring_at.size.x, _ring_at.size.y) * (0.78 + 0.1 * pulse)
	h.c.draw_circle(c, rad, Color(GOLD, 0.12 + 0.1 * pulse))
	h.c.draw_arc(c, rad, 0.0, TAU, 40, Color(GOLD, 0.7 + 0.3 * pulse), 4.0, true)
	var tip := c - Vector2(0, rad + 6.0 + 10.0 * pulse)
	var s := rad * 0.5
	h.c.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-s, -s * 1.2), tip + Vector2(s, -s * 1.2)]), GOLD)

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

## A small check beside the panel when a step is done: it fades, it does not pop over the screen.
static func _check(h, r: Rect2, k: float) -> void:
	var col := Color(MINT, clampf(k * 1.5, 0.0, 1.0))
	var c := r.get_center()
	var s := r.size.y * 0.32
	var pts := PackedVector2Array([Vector2(-0.5, 0.05), Vector2(-0.15, 0.45), Vector2(0.55, -0.4)])
	for i in pts.size():
		pts[i] = c + pts[i] * s
	h.c.draw_polyline(pts, col, 5.0, true)

## During the tutorial the message lane is the top-right column, clear of the panel
## (Hud holds it while the panel is fresh).
static func place_msgs(lane: MsgLane, sz: Vector2) -> void:
	var r: Rect2 = lanes(sz)["toast"]
	lane.top = r.position.y
	lane.right_edge = r.end.x
