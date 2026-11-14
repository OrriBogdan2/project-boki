class_name TutorialHud
extends RefCounted
## What the tutorial shows on screen (the beam is Tutorial, the pin and edge arrow Hud._draw_waypoint).
## Everything has its own lane so nothing overlaps: the short first-time intro card (the one thing that
## pauses play), the step panel pinned at the top-centre for the whole step (it pops in for each new
## step, and carries an arrow and the distance while the target is off screen or under the hunter), a
## quiet check beside it, and the message lane in the top-right. Nothing sits in the middle or the
## bottom of the screen, where the hunter, the Boki and the hotbar are. While a new panel is fresh
## (Tutorial.card_up) other popups (messages, Boki bubbles, the scout hint, the world's F prompt) wait,
## so one prompt shows at a time; what a fight needs now (MsgLane.URGENT, FIGHT_PROMPTS) still shows.

const MINT := TutorialStrip.MINT
const GOLD := TutorialStrip.GOLD
const PANEL := TutorialStrip.PANEL

const FIGHT_PROMPTS := ["revive", "finish", "stomping", "boxrev"]     # Match.interact kinds that never wait

static var _ring_at := Rect2()      # the pick ring's slot, as last drawn

## The lanes: the strip, the check mark and the message column (Rect2 each), for a screen size.
static func lanes(sz: Vector2) -> Dictionary:
	var banner := TutorialStrip.rect(sz)
	var bh := banner.size.y
	return {
		"banner": banner,
		"check": Rect2(Vector2(banner.position.x - bh - 10.0, banner.position.y), Vector2(bh, bh)),
		"toast": Rect2(Vector2(sz.x * 0.72, sz.y * 0.02), Vector2(sz.x * 0.28 - 12.0, sz.y * 0.21)),
		"intro": Rect2(Vector2(sz.x * 0.3, sz.y * 0.36), Vector2(sz.x * 0.4, sz.y * 0.28)),
	}

## The world prompt (Hud._draw_prompt) may show: no fresh panel is up, or it is one a fight needs.
static func prompt_shows(m: Match) -> bool:
	return m.tut == null or not m.tut.card_up() or String(m.interact.get("kind", "")) in FIGHT_PROMPTS

static func draw(h, sz: Vector2) -> void:
	var tu: Tutorial = h.m.tut
	if tu.intro:
		_intro(h, sz, tu)
		return
	if tu.step < 0 or tu.step >= Tutorial.steps().size():
		return
	var r := TutorialStrip.shown(sz, tu.card_t)
	var dir := Vector2.ZERO
	if tu.target != Vector3.INF and h.m.cam and h.m.player:
		dir = MarkerDir.off_dir(h.m.cam, sz, tu.target, h.m.player.pos)
	_bar(h, r, tu, dir)
	_pick_ring(h, tu)
	if not tu.card_up():
		_extras(h, r, tu)
	if tu.done_t > 0.0:
		_check(h, lanes(sz)["check"], tu.done_t / Tutorial.DONE_T)

## The step's one line in the strip: key cap on the left, on the right the counter and, while the target's
## pin isn't on screen, an arrow pointing the way with the distance. A nag re-pulses it. (The plain-words
## detail goes to the message lane when the step opens: Tutorial.)
static func _bar(h, r: Rect2, tu: Tutorial, dir: Vector2) -> void:
	var line := {"text": tu.text, "key_cap": tu.key_cap, "count": tu.progress_text(), "dir": dir}
	if dir != Vector2.ZERO:
		var gap := Vector2(tu.target.x - tu.m.player.pos.x, tu.target.z - tu.m.player.pos.z)
		line["dist"] = "%dm" % int(round(gap.length()))
	var age := fposmod(tu.card_t, 0.4) if tu.nag_t > 0.0 else tu.card_t
	TutorialStrip.paint(h.c, h.big, r, line, age)

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
