class_name TutorialHud
extends RefCounted
## What the tutorial shows on screen (the beam is Tutorial, the pin and edge arrow Hud._draw_waypoint).
## Everything has its own lane so nothing overlaps: the short first-time intro card (the one thing that
## pauses play), the step panel pinned at the top-centre for the whole step (it slides in with a bright
## glow and a chime for each new step, settles to a steady breathing glow, flares again after a stall,
## shows its keys as key caps in the line, and carries an arrow and the distance while the target is
## off screen or under the hunter), a quiet check beside it, and the message lane in the top-right.
## Nothing sits in the middle or the bottom of the screen, where the hunter, the Boki and the hotbar
## are, and the glow stays in the top strip. While a new panel is fresh
## (Tutorial.card_up) other popups (messages, Boki bubbles, the scout hint) wait.

const MINT := Color("8fe3c8")
const GOLD := Color("f2c84a")
const BAR_W := 0.35         # of the screen width: the widest the panel gets
const BAR_H := 0.085        # of the screen height: the panel's height (one line)
const POP_T := 0.25         # s the panel takes to drop and pop in
const POP_K := 0.12         # how much bigger than its size the panel starts as it pops in
const GLOW_T := 1.2         # s the bright glow of a new panel takes to settle to the steady one
const REST_GLOW := 0.45     # the steady glow (0..1) a settled panel keeps, so it never goes quiet
const BREATHE := 0.08       # how far the steady glow breathes up and down
const BREATHE_HZ := 0.5     # breaths a second
const FLARE_T := 0.8        # s per flare of a stall's re-pulse (Tutorial.NAG_PULSE_T holds three)
const FLARE_K := 0.05       # how much bigger the panel swells at the top of a flare
const HALO := 0.35          # of the panel's row height: how far the glow spreads at its brightest
const LIT := Color(0.07, 0.17, 0.15, 0.96)   # the panel's fill at full glow (still dark under the words)
const KEY_FACE := Color(0.95, 0.97, 1.0)
const KEY_LIP := Color(0.55, 0.62, 0.7)
const KEY_INK := Color(0.05, 0.07, 0.11)
## The actions a step's line can name (Tutorial._fill's %J %G %E %T %Q): shown as key caps in the line.
const LINE_KEYS := ["jump", "glide", "signature", "throw", "gear1"]
const PANEL := Color(0.03, 0.04, 0.07, 0.94)
const DETAIL_K := 1.9       # a panel with a second line is this much taller

static var _ring_at := Rect2()      # the pick ring's slot, as last drawn
static var _frame_box: StyleBoxFlat  # the panel's own box (its glow changes every frame, so it isn't cached per colour)
static var _parts_of := ""          # the line and key cap _parts was split for
static var _parts: Array = []       # the line as [text, is_key] runs

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
	var s := 1.0 + POP_K * sin(k * PI) + FLARE_K * _flare(tu)     # (grows a touch past its size and settles back)
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

## How bright the panel's glow is (0..1): full on a new step, settling over GLOW_T to the steady breathing
## REST_GLOW, and flaring again while a stall pulses it (Tutorial.nag_t).
static func glow(tu: Tutorial) -> float:
	var g := REST_GLOW + BREATHE * sin(Time.get_ticks_msec() / 1000.0 * TAU * BREATHE_HZ)
	g = maxf(g, 1.0 - clampf(tu.card_t / GLOW_T, 0.0, 1.0))
	return maxf(g, _flare(tu))

## A stall's re-pulse: three flares, each bright at once and fading over FLARE_T.
static func _flare(tu: Tutorial) -> float:
	if tu.nag_t <= 0.0:
		return 0.0
	return pow(1.0 - fposmod(Tutorial.NAG_PULSE_T - tu.nag_t, FLARE_T) / FLARE_T, 2.0)

## The panel: dark under the words, a mint edge going white and a soft halo spreading as it glows.
static func _frame(h, r: Rect2, row: float, g: float) -> void:
	if _frame_box == null:
		_frame_box = StyleBoxFlat.new()
		_frame_box.set_corner_radius_all(14)
		_frame_box.anti_aliasing = true
	var lift := clampf((g - REST_GLOW) / (1.0 - REST_GLOW), 0.0, 1.0)
	_frame_box.bg_color = PANEL.lerp(LIT, lift)
	_frame_box.border_color = Color(MINT.lerp(Color.WHITE, 0.6 * lift), 0.6 + 0.4 * g)
	_frame_box.set_border_width_all(int(2.0 + 3.0 * g))
	_frame_box.shadow_color = Color(MINT, 0.2 + 0.55 * g)
	_frame_box.shadow_size = int(row * HALO * (0.35 + 0.65 * g))
	h.c.draw_style_box(_frame_box, r)

## The step's line (its keys as key caps in it), and on the right the counter and, while the target's
## pin isn't on screen, an arrow pointing the way with the distance.
static func _bar(h, r: Rect2, tu: Tutorial, dir: Vector2) -> void:
	var row := r.size.y / (DETAIL_K if tu.detail != "" else 1.0)     # the first line's height
	_frame(h, r, row, glow(tu))
	var mid := r.position.y + row * 0.5
	var px := int(row * 0.46)
	var right: float = r.end.x - 14.0
	var n := tu.progress_text()
	if n != "":
		var n_w: float = h.big.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		h._text(Vector2(right - n_w, mid + px * 0.36), n, px, MINT, h.big)
		right -= n_w + 12.0
	if dir != Vector2.ZERO:
		right = _arrow(h, Vector2(right, mid), row, dir, tu) - 10.0
	_line(h, r.position.x + 14.0, right, mid, px, tu)
	if tu.detail != "":
		_detail(h, r, row, tu.detail)

## The line as runs of words and keys: a key the line names (or the step's key cap) is a run of its own;
## the step's key cap goes in front when the line doesn't name it. Split again only when the line changes.
static func parts(tu: Tutorial) -> Array:
	if _parts_of == tu.text + "|" + tu.key_cap:
		return _parts
	_parts_of = tu.text + "|" + tu.key_cap
	var keys: Array = LINE_KEYS.map(func(a): return Settings.key_cap(a))
	if tu.key_cap != "":
		keys.append(tu.key_cap)
	_parts = []
	var words := ""
	var named := false
	for w in tu.text.split(" "):
		var core := w.rstrip(",.:;!?")
		if core != "" and core in keys:
			named = named or core == tu.key_cap
			if words != "":
				_parts.append([words, false])
			_parts.append([core, true])
			words = w.substr(core.length())
		else:
			words += (" " if words != "" else "") + w
	if words.strip_edges() != "":
		_parts.append([words, false])
	if tu.key_cap != "" and not named:
		_parts.push_front([tu.key_cap, true])
	return _parts

## The line's runs from `left`, shrunk to fit before `right`, gold words and light key caps.
static func _line(h, left: float, right: float, mid: float, px: int, tu: Tutorial) -> void:
	var runs := parts(tu)
	var tpx := px
	while tpx > int(px * 0.62) and _runs_w(h, runs, tpx) > right - left:
		tpx -= 1
	var x := left
	for run in runs:
		if run[1]:
			var cw := _cap_w(h, run[0], tpx)
			var cr := Rect2(Vector2(x, mid - tpx * 0.68), Vector2(cw, tpx * 1.3))
			h._panel(Rect2(cr.position + Vector2(0, 3), cr.size), KEY_LIP, 8)
			h._panel(cr, KEY_FACE, 8)
			h._ctext(cr.get_center() + Vector2(0, tpx * 0.34), run[0], tpx, KEY_INK, h.big)
			x += cw + tpx * 0.3
		else:
			h._text(Vector2(x, mid + tpx * 0.36), run[0], tpx, GOLD, h.big)
			x += TextCache.width(h.big, run[0], tpx) + tpx * 0.3

static func _cap_w(h, key: String, px: int) -> float:
	return maxf(px * 1.4, TextCache.width(h.big, key, px) + px * 0.6)

static func _runs_w(h, runs: Array, px: int) -> float:
	var w := 0.0
	for run in runs:
		w += (_cap_w(h, run[0], px) if run[1] else TextCache.width(h.big, run[0], px)) + px * 0.3
	return w - px * 0.3

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
