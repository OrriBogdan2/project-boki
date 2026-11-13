class_name DownedMarks
extends RefCounted
## A downed Hunter reads at a glance, in the one colour rule (SideColor), with small precise marks
## instead of a big circle on the ground (docs/decisions/0019):
##   - round their Wisp, a compact ring: the bleed-out draining in their side colour (ally or rival),
##     revive progress filling inside it, flashing over the last LOW_S seconds; red and pulsing while
##     an enemy stands on them (stomp)
##   - only for a teammate close by (CUE_RANGE), the revive reach on the ground, thin, filling as they
##     revive, and one line on the HUD saying to step onto the Wisp
##   - while a stomp runs on them (Stomp), for anyone within NEAR_M, that ring fills in the stomper's
##     colour over Stomp.TIME instead; the wisp's own player reads BEING under it, and a squadmate with a
##     move ready that stuns or knocks (stomps.json "savers") reads SAVE and that move's key at the stomper
## Reviving is standing on the Wisp (Life), so there is no key to press. Words go through LabelCull.claim.

const MARK_UP := 0.45         # m over the feet: the Hunter Wisp's middle (WispLook hover)
const MARK_R := 17.0          # px: the ring round the Wisp
const MARK_W := 4.0           # px: its width
const LOW_S := 5.0            # s: the last seconds of a bleed-out flash
const CUE_RANGE := 9.0        # m: a teammate this close sees the revive reach and the HUD line
const STOMP_RED := Color(1.0, 0.18, 0.1)
const BACK := Color(0.03, 0.04, 0.07, 0.55)
const STOMP_R := 21.0         # px: the stomp ring round the Wisp (a little wider than the bleed-out one)
const CUE_DROP := 30.0        # px under the feet: where a stomp word sits
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
	var cue: Hunter = null
	shown.clear()
	for o: Hunter in m.hunters:
		if not o.downed or o.out or (o.unseen and o != p):
			continue
		var s := stomper_of(o)
		if s and LabelCull.at(hud, o.pos, NEAR_M).is_finite():
			_stomp(hud, o, s)
			continue
		var stomped: bool = o.get_meta("stomped", false)
		var col := STOMP_RED if stomped else SideColor.of(m, o)
		var mate := p != null and p != o and o.team == p.team and not p.out and not p.downed
		if mate and not stomped and p.flat_dist(o) < CUE_RANGE:
			_reach(c, m, o, col)
			if p.flat_dist(o) > float(Life.R["revive_radius"]) and (cue == null or p.flat_dist(o) < p.flat_dist(cue)):
				cue = o
		var at3 := o.pos + Vector3(0, MARK_UP, 0)
		if not m.cam.is_position_behind(at3):
			badge(c, m.cam.unproject_position(at3), o, col, m.time, MARK_R)
	if cue:
		var sz := c.size
		HudStyle.ctext(c, Vector2(sz.x * 0.5, sz.y * 0.8), "Step onto %s's wisp to revive" % cue.pname, 15,
			SideColor.of(m, cue))

## The ring round a Wisp at screen point `at` (radius `r` px): bleed-out left in `col`, revive progress
## inside it; flashes while little time is left. The squad's offscreen arrows draw the same one.
static func badge(c: CanvasItem, at: Vector2, o: Hunter, col: Color, time: float, r: float) -> void:
	var f := bleed_frac(o)
	var low := f * float(Life.R["bleed_out"]) < LOW_S
	var a := 0.55 + 0.45 * sin(time * 12.0) if low or o.get_meta("stomped", false) else 1.0
	c.draw_arc(at, r, 0.0, TAU, 40, BACK, MARK_W + 3.0, true)
	c.draw_arc(at, r, 0.0, TAU, 40, Color(col, 0.22), MARK_W, true)
	if f > 0.0:
		c.draw_arc(at, r, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Color(col, a), MARK_W, true)
	if o.revive > 0.0:
		var rv := clampf(o.revive, 0.0, 1.0)
		c.draw_arc(at, r - MARK_W - 1.0, -PI * 0.5, -PI * 0.5 + TAU * rv, 40, HudStyle.REVIVE, MARK_W - 1.0, true)

## The revive reach on the ground, for a teammate close by: thin, filling as the revive goes.
static func _reach(c: Control, m: Match, o: Hunter, col: Color) -> void:
	var rr: float = Life.R["revive_radius"]
	ring(c, m.cam, o.pos, rr, Color(col, 0.4), 1.5)
	if o.revive > 0.0:
		ring(c, m.cam, o.pos, rr, Color(HudStyle.REVIVE, 0.9), 3.0, o.revive)

## Who is stomping `o` right now (Stomp), or null.
static func stomper_of(o: Hunter) -> Hunter:
	# not get_meta(k, null): that logs an error each frame the key is unset
	var s = o.get_meta("stomped_by") if o.has_meta("stomped_by") else null
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
static func _stomp(hud, o: Hunter, s: Hunter) -> void:
	var m: Match = hud.m
	var me: Hunter = m.player
	var col := SideColor.of(m, s)
	var frac := clampf(float(s.stomp["t"]) / Stomp.TIME, 0.0, 1.0)
	var at3 := o.pos + Vector3(0, MARK_UP, 0)
	if not m.cam.is_position_behind(at3):
		var sp := m.cam.unproject_position(at3)
		hud.c.draw_arc(sp, STOMP_R, 0.0, TAU, 40, BACK, MARK_W + 3.0, true)
		hud.c.draw_arc(sp, STOMP_R, 0.0, TAU, 40, Color(col, 0.3), MARK_W, true)
		hud.c.draw_arc(sp, STOMP_R, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, col, MARK_W, true)
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

## How much of a downed Hunter's bleed-out is left, 1 (just knocked) to 0.
static func bleed_frac(o: Hunter) -> float:
	return clampf(o.down_hp / maxf(1.0, float(Data.MATCH["down_hp"])), 0.0, 1.0)
