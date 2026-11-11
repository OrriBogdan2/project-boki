class_name DownedMarks
extends RefCounted
## A downed Hunter reads at a glance, in the one colour rule (SideColor):
##   - a ring on the ground the size of the revive range, in their side colour, filling brighter as a
##     teammate brings them up; red and pulsing while an enemy stands on them
##   - over them, a small knocked mark ringed by their bleed-out timer, draining as they bleed out
##   - for a teammate near (not yet in) the ring, one short cue: "Revive" and how far
##   - while a stomp runs on them (Stomp), for anyone within NEAR_M: the ring fills in the stomper's
##     colour over Stomp.TIME; the wisp's own player reads BEING under it, and a squadmate with a move
##     ready that stuns or knocks (stomps.json "savers") reads SAVE and that move's key at the stomper
## Reviving is standing in the ring (Life), so there is no key to press. Words go through LabelCull.claim.

const MARK_UP := 2.35         # m over the feet: the knocked mark
const MARK_R := 13.0          # px: the bleed-out ring's radius
const CUE_RANGE := 9.0        # m: a teammate this close (and outside the ring) gets the cue
const CUE_DROP := 30.0        # px under the feet: where a cue word sits
const STOMP_RED := Color(1.0, 0.18, 0.1)
const NEAR_M := 25.0          # m (flat) from you: a stomp's ring and words show only this close
                              # (further off, you can't reach the stomper in time)
const BEING := "Being stomped"
const SAVE := "Stun to save"
const WORD_FS := 14           # px: the stomp words
## A "savers" slot -> the action whose key it shows
const SAVE_KEYS := {"sec": "secondary", "k1": "signature", "x": "hunter_ult"}

## Each stomp the last frame drew: wisp nid -> {frac, col, word, key, rect} (checks read it)
static var shown := {}

## Draws every visible downed Hunter's marks on the HUD canvas.
static func draw(hud) -> void:
	var c: Control = hud.c
	var m: Match = hud.m
	var p: Hunter = m.player
	var rr: float = Life.R["revive_radius"]
	shown.clear()
	for o in m.hunters:
		if not o.downed or o.out or (o.unseen and o != p) or m.cam.is_position_behind(o.position):
			continue
		var s := stomper_of(o)
		if s and LabelCull.at(hud, o.pos, NEAR_M).is_finite():
			_stomp(hud, o, s, rr)
			continue
		var col := SideColor.of(m, o)
		var stomped: bool = o.get_meta("stomped", false)
		var pulse := 0.5 + 0.5 * sin(m.time * 10.0)
		if stomped:
			ring(c, m.cam, o.pos, rr * (1.0 + 0.08 * pulse), Color(STOMP_RED, 0.55 + 0.35 * pulse), 4.0)
		else:
			ring(c, m.cam, o.pos, rr, Color(col, 0.45 + 0.2 * pulse), 2.5)
			if o.revive > 0.0:
				ring(c, m.cam, o.pos, rr, Color(col.lerp(Color.WHITE, 0.4), 0.95), 5.0, o.revive)
		_mark(c, m, o, STOMP_RED if stomped else col)
		if p == null or p.out or p.downed or p == o or o.team != p.team or stomped:
			continue
		var d := p.flat_dist(o)
		if d > rr and d < CUE_RANGE:
			var at := m.cam.unproject_position(o.pos + Vector3(0, 0.1, 0)) + Vector2(0, CUE_DROP)
			HudStyle.ctext(c, at, "Revive  %.0fm" % ceilf(d - rr), 13, col)

## A ring on the ground round `at` (radius `r` m), drawn as a screen polyline; `frac` < 1 draws an arc
## from `start` (radians), for progress.
static func ring(c: CanvasItem, cam: Camera3D, at: Vector3, r: float, col: Color, width: float, frac := 1.0,
		start := -PI * 0.5) -> void:
	var pts := PackedVector2Array()
	var steps := maxi(2, int(ceil(40.0 * clampf(frac, 0.0, 1.0))))
	for i in steps + 1:
		var a := start + TAU * frac * float(i) / float(steps)
		var wp := at + Vector3(cos(a) * r, 0.08, sin(a) * r)
		if cam.is_position_behind(wp):
			return
		pts.append(cam.unproject_position(wp))
	c.draw_polyline(pts, col, width, true)

## Who is stomping `o` right now (Stomp), or null.
static func stomper_of(o: Hunter) -> Hunter:
	var s = o.get_meta("stomped_by", null)
	return s if is_instance_valid(s) and not (s as Hunter).stomp.is_empty() else null

## The key of `h`'s first ready move that stuns or knocks (stomps.json "savers"), or "" when none is.
static func saver_key(h: Hunter) -> String:
	if KinMerge.active(h):
		return ""          # merged: the form's moves stand in for the kit's
	for slot in StompLook.rules()["savers"].get(h.arch, []):
		var unlocked := int(h.slot_lv.get(Hunter.SLOT_ALIAS.get(slot, slot), 1)) > 0      # "x" opens by level instead
		if unlocked and bool(h.slot_info(slot)["ready"]):
			return Settings.key_cap(SAVE_KEYS[slot])
	return ""

## A stomp on `o` by `s`: the ring filling in the stomper's colour, and the one word for you.
static func _stomp(hud, o: Hunter, s: Hunter, rr: float) -> void:
	var m: Match = hud.m
	var me: Hunter = m.player
	var col := SideColor.of(m, s)
	var frac := clampf(float(s.stomp["t"]) / Stomp.TIME, 0.0, 1.0)
	ring(hud.c, m.cam, o.pos, rr, Color(col, 0.35), 2.5)
	ring(hud.c, m.cam, o.pos, rr, col, 5.0, frac)
	_mark(hud.c, m, o, col)
	var word := ""
	var key := ""
	var at := o.pos
	if me == o:
		word = BEING
	elif me and not me.out and not me.downed and me.team == o.team:
		key = saver_key(me)
		word = SAVE if key != "" else ""
		at = s.pos
	var r := Rect2()
	if word != "":
		r = _word(hud, at, word, key, col.lerp(Color.WHITE, 0.35))
	shown[o.nid] = {"frac": frac, "col": col, "word": word, "key": key, "rect": r}

## `word` under the feet at `at` (and `key` in a pill after it), placed by LabelCull.claim.
static func _word(hud, at: Vector3, word: String, key: String, col: Color) -> Rect2:
	var sp := LabelCull.at(hud, at, NEAR_M)
	if not sp.is_finite():
		return Rect2()
	var tw := TextCache.width(HudStyle.BIG, word, WORD_FS)
	var pw := TextCache.width(HudStyle.BIG, key, HudStyle.KEY_FS) + 12.0 if key != "" else 0.0
	var w := tw + (pw + 6.0 if key != "" else 0.0)
	var r := LabelCull.claim(Rect2(sp + Vector2(-w * 0.5, CUE_DROP - 15.0), Vector2(w, 20.0)))
	HudStyle.text(hud.c, r.position + Vector2(0, 15), word, WORD_FS, col)
	if key != "":
		HudStyle.key_pill(hud.c, Vector2(r.end.x - pw * 0.5, r.get_center().y), key, col)
	return r

## How much of a downed Hunter's bleed-out is left, 1 (just knocked) to 0.
static func bleed_frac(o: Hunter) -> float:
	return clampf(o.down_hp / maxf(1.0, float(Data.MATCH["down_hp"])), 0.0, 1.0)

static func _mark(c: Control, m: Match, o: Hunter, col: Color) -> void:
	var at := m.cam.unproject_position(o.pos + Vector3(0, MARK_UP, 0))
	c.draw_circle(at, MARK_R + 3.0, Color(0.03, 0.04, 0.07, 0.8))
	c.draw_arc(at, MARK_R, 0.0, TAU, 32, Color(col, 0.25), 3.0, true)
	var f := bleed_frac(o)
	if f > 0.0:
		c.draw_arc(at, MARK_R, -PI * 0.5, -PI * 0.5 + TAU * f, 32, col, 3.0, true)
	Icons.draw(c, "knock", at, 8.0, col.lerp(Color.WHITE, 0.3))
