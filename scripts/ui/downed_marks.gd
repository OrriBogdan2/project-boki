class_name DownedMarks
extends RefCounted
## A downed Hunter reads at a glance, in the one colour rule (SideColor), with small precise marks
## instead of a big circle on the ground (docs/decisions/0019):
##   - on the ground round their Wisp's base, a compact ring (clear of the body, so the Wisp and its face
##     stay in view): the bleed-out draining in their side colour (ally or rival), revive progress filling
##     inside it, flashing over the last LOW_S seconds; red and pulsing while an enemy stands on them (stomp)
##   - only for a teammate close by (CUE_RANGE), the revive reach on the ground, thin, filling as they
##     revive; their plate over the Wisp says to jump on it (HudPlate)
## Reviving is jumping onto or standing over the Wisp (Life), so there is no key to press.

const HUG := 0.6              # m: the ring round a Wisp's base on the ground (its body is 0.3 m in radius)
const HUG_IN := 0.1           # m: the revive progress inside it
const MARK_W := 4.0           # px: the ring's width
const LOW_S := 5.0            # s: the last seconds of a bleed-out flash
const CUE_RANGE := 9.0        # m: a teammate this close sees the revive reach and the jump prompt
const STOMP_RED := Color(1.0, 0.18, 0.1)
const BACK := Color(0.03, 0.04, 0.07, 0.55)

## Draws every visible downed Hunter's marks on the HUD canvas.
static func draw(c: Control, m: Match) -> void:
	var p: Hunter = m.player
	for o: Hunter in m.hunters:
		if not o.downed or o.out or (o.unseen and o != p):
			continue
		var stomped: bool = o.get_meta("stomped", false)
		var col := STOMP_RED if stomped else SideColor.of(m, o)
		if cued(p, o):
			_reach(c, m, o, col)
		_hug(c, m, o, col)

## Does the viewer `p` get the revive cues for downed `o` (the reach, the jump prompt): a teammate who is
## up, close by, and nobody is stomping `o`. Rivals and the downed themselves never do.
static func cued(p: Hunter, o: Hunter) -> bool:
	return p != null and p != o and o.team == p.team and not p.out and not p.downed \
		and not o.get_meta("stomped", false) and p.flat_dist(o) < CUE_RANGE

## The ring on the ground round downed `o`'s Wisp (it trails the hunter, so it goes where the body is): the
## same marks as badge(), laid round the base.
static func _hug(c: CanvasItem, m: Match, o: Hunter, col: Color) -> void:
	var wisp := HunterWisp.node_of(o)
	var at := o.pos
	if wisp != null:
		at = Vector3(wisp.global_position.x, o.pos.y, wisp.global_position.z)
	var f := bleed_frac(o)
	ring(c, m.cam, at, HUG, BACK, MARK_W + 3.0)
	ring(c, m.cam, at, HUG, Color(col, 0.22), MARK_W)
	if f > 0.0:
		ring(c, m.cam, at, HUG, Color(col, _bleed_alpha(o, m.time)), MARK_W, f)
	if o.revive > 0.0:
		ring(c, m.cam, at, HUG - HUG_IN, HudStyle.REVIVE, MARK_W - 1.0, clampf(o.revive, 0.0, 1.0))

## The ring round a Wisp at screen point `at` (radius `r` px), for the squad's offscreen arrows: bleed-out
## left in `col`, revive progress inside it; flashes while little time is left.
static func badge(c: CanvasItem, at: Vector2, o: Hunter, col: Color, time: float, r: float) -> void:
	var f := bleed_frac(o)
	c.draw_arc(at, r, 0.0, TAU, 40, BACK, MARK_W + 3.0, true)
	c.draw_arc(at, r, 0.0, TAU, 40, Color(col, 0.22), MARK_W, true)
	if f > 0.0:
		c.draw_arc(at, r, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Color(col, _bleed_alpha(o, time)), MARK_W, true)
	if o.revive > 0.0:
		var rv := clampf(o.revive, 0.0, 1.0)
		c.draw_arc(at, r - MARK_W - 1.0, -PI * 0.5, -PI * 0.5 + TAU * rv, 40, HudStyle.REVIVE, MARK_W - 1.0, true)

## The bleed-out arc's alpha: it flashes over the last LOW_S seconds and while an enemy stomps.
static func _bleed_alpha(o: Hunter, time: float) -> float:
	var low := bleed_frac(o) * float(Life.R["bleed_out"]) < LOW_S
	return 0.55 + 0.45 * sin(time * 12.0) if low or o.get_meta("stomped", false) else 1.0

## The revive reach on the ground, for a teammate close by: thin, filling as the revive goes.
static func _reach(c: Control, m: Match, o: Hunter, col: Color) -> void:
	var rr: float = Life.R["revive_radius"]
	ring(c, m.cam, o.pos, rr, Color(col, 0.4), 1.5)
	if o.revive > 0.0:
		ring(c, m.cam, o.pos, rr, Color(HudStyle.REVIVE, 0.9), 3.0, o.revive)

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
