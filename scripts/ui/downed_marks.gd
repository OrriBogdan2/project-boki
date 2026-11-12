class_name DownedMarks
extends RefCounted
## A downed Hunter reads at a glance, in the one colour rule (SideColor), with small precise marks
## instead of a big circle on the ground (docs/decisions/0019):
##   - round their Wisp, a compact ring: the bleed-out draining in their side colour (ally or rival),
##     revive progress filling inside it, flashing over the last LOW_S seconds; red and pulsing while
##     an enemy stands on them (stomp)
##   - a knocked teammate gets a bigger ping over their plate instead (ally_ping): their red-tinted face
##     in a spiked ring that drains with their bleed-out, "ALLY KNOCKED" under it; it pops in as they go
##     down (sizes measured off the reference, scripts/ui/SQUAD_FRAMES_SPEC.md)
##   - only for a teammate close by (CUE_RANGE), the revive reach on the ground, thin, filling as they
##     revive, and one line on the HUD saying to step onto the Wisp
## Reviving is standing on the Wisp (Life), so there is no key to press.

const MARK_UP := 0.45         # m over the feet: the Hunter Wisp's middle (WispLook hover)
const MARK_R := 17.0          # px: the ring round the Wisp
const MARK_W := 4.0           # px: its width
const LOW_S := 5.0            # s: the last seconds of a bleed-out flash
const CUE_RANGE := 9.0        # m: a teammate this close sees the revive reach and the HUD line
const STOMP_RED := Color(1.0, 0.18, 0.1)
const PING_R := 25.8          # px: the ally ping's face radius
const PING_RISE := 90.0       # px: the ping's centre over their plate's anchor (clears the downed plate)
const PING_POP := 0.25        # s: the ping's pop-in (overshoots, then settles)
const PING_RING := Color("3cb8f0")
const PING_TEXT_PX := 14      # font px: ALLY KNOCKED
const BACK := Color(0.03, 0.04, 0.07, 0.55)

## Draws every visible downed Hunter's marks on the HUD canvas (`hud` gives the faces and knock times).
static func draw(c: Control, m: Match, hud) -> void:
	var p: Hunter = m.player
	var cue: Hunter = null
	for o: Hunter in m.hunters:
		if not o.downed or o.out or (o.unseen and o != p):
			continue
		var stomped: bool = o.get_meta("stomped", false)
		var col := STOMP_RED if stomped else SideColor.of(m, o)
		var mate := p != null and p != o and o.team == p.team and not p.out and not p.downed
		if mate and not stomped and p.flat_dist(o) < CUE_RANGE:
			_reach(c, m, o, col)
			if p.flat_dist(o) > float(Life.R["revive_radius"]) and (cue == null or p.flat_dist(o) < p.flat_dist(cue)):
				cue = o
		if mate_of(p, o):
			if not m.cam.is_position_behind(o.pos):
				ally_ping(c, m, hud, o, stomped)
			continue
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

## A knocked teammate's ping over where they lie.
static func ally_ping(c: Control, m: Match, hud, o: Hunter, stomped: bool) -> void:
	var t := m.time - float(hud.mates.since.get(o.nid, -9.0))
	var k := clampf(t / PING_POP, 0.0, 1.0)
	var sc := 1.0 + 0.3 * sin(k * PI) if k < 1.0 else 1.0
	var a := clampf(t / 0.08, 0.0, 1.0)
	var at := m.cam.unproject_position(o.pos + Vector3(0, HudPlate.plate_offset(o), 0)) - Vector2(0, PING_RISE)
	var r := PING_R * sc
	var ring_col := Color(STOMP_RED if stomped else PING_RING, a)
	# the spikes: three flames off the ring's upper left, one off its upper right
	for sp in [[-2.4, 1.85], [-1.9, 1.5], [-2.9, 1.45], [-0.75, 1.55]]:
		var d := Vector2.from_angle(sp[0])
		var tip := at + d * r * float(sp[1])
		var side := d.orthogonal() * r * 0.2
		c.draw_colored_polygon(PackedVector2Array([at + d * r + side, tip, at + d * r - side]), ring_col)
	c.draw_circle(at, r + 3.5, ring_col)
	c.draw_circle(at, r, Color(0.75, 0.12, 0.25, a))
	var face := SquadFrames.face(hud, o, false)
	SquadFrames.disc(c, at, r * 0.94, face, Color(0.75, 0.12, 0.25), Color(1, 0.55, 0.6, 0.85 * a))
	c.draw_arc(at, r + 1.75, -PI * 0.5, -PI * 0.5 + TAU * bleed_frac(o), 40, Color(Color.WHITE, 0.6 * a), 1.5, true)
	for d in [Vector2(1, 1), Vector2(1, -1)]:
		var x0 := at + Vector2(0, -r - 2.0)
		c.draw_line(x0 - d * 5.0, x0 + d * 5.0, Color(1, 0.15, 0.3, a), 3.0, true)
	var ty := at.y + r + 13.0
	var w := TextCache.width(HudStyle.BIG, "ALLY KNOCKED", PING_TEXT_PX) * 0.9
	c.draw_set_transform_matrix(Transform2D(Vector2(0.9, 0), Vector2(-0.2, 1), Vector2(at.x - w * 0.5, ty)))
	var edge := Color(0.1, 0.35, 0.9, a)
	TextCache.draw(c, HudStyle.BIG, Vector2.ZERO, "ALLY KNOCKED", PING_TEXT_PX, Color(1, 1, 1, a), 5, edge)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## True when `o` is a squadmate of the local player `p` (not `p` themself).
static func mate_of(p: Hunter, o: Hunter) -> bool:
	return p != null and p != o and o.team == p.team
