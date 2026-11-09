class_name DownedMarks
extends RefCounted
## A downed Hunter reads at a glance, in the one colour rule (SideColor):
##   - a ring on the ground the size of the revive range, in their side colour, filling brighter as a
##     teammate brings them up; red and pulsing while an enemy stands on them (stomp)
##   - over them, a small knocked mark ringed by their bleed-out timer, draining as they bleed out
##   - for a teammate near (not yet in) the ring, one short cue: "Revive" and how far
## Reviving is standing in the ring (Life), so there is no key to press.

const MARK_UP := 2.35         # m over the feet: the knocked mark
const MARK_R := 13.0          # px: the bleed-out ring's radius
const CUE_RANGE := 9.0        # m: a teammate this close (and outside the ring) gets the cue
const STOMP_RED := Color(1.0, 0.18, 0.1)

## Draws every visible downed Hunter's marks on the HUD canvas.
static func draw(c: Control, m: Match) -> void:
	var p: Hunter = m.player
	var rr: float = Life.R["revive_radius"]
	for o in m.hunters:
		if not o.downed or o.out or (o.unseen and o != p) or m.cam.is_position_behind(o.position):
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
			var at := m.cam.unproject_position(o.pos + Vector3(0, 0.1, 0)) + Vector2(0, 30)
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
