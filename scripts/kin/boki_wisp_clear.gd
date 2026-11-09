class_name BokiWispClear
extends RefCounted
## Keeps a Boki wisp (BokiWispLook) out of the way at the match camera (DECISIONS 2026-11-09): it orbits on
## the side away from the aim, fades while it is over the aim line, the cursor, your hit circle or a plate,
## sheds a shorter trail when its Hunter fires, and with a crowd only the nearest few keep sparkles.
## Pure look rules: who carries the wisp is the wisp prototype's job. Everything is judged on screen (px),
## because the aim line lies on the ground and the wisp floats at shoulder height.

const ORBIT_R := 0.95           # m from the Hunter's middle
const REAR := 1.75              # rad off the aim where its arc is centred (100 deg: beside it, a little behind)
const SWING := 0.3              # rad it swings either side of that: the orbit is an arc, never a full lap
const SWING_HZ := 0.35          # swings per second
const MAX_DROP := 0.5           # m it may sink below shoulder height to clear its Hunter's plate
const SIDE_STICKY := 12.0       # px a side must win by before the wisp crosses to it
const REACH := 0.3              # m from the wisp's middle to its ears, hop and trail's edge
const LINE_HALF := 0.15         # m: half the width of the aim line
const FADE_BAND := 24.0         # px over which it fades in as it leaves an obstacle
const MIN_ALPHA := 0.2          # how faint it gets right over the aim line
const PLATE_ALPHA := 0.5        # ...and over a plate, the cursor or your hit circle (those draw over it anyway)
const FIRE_TRAIL := 0.4         # fraction of the trail's life while its Hunter fires: sparkles out of the way
const TRAIL_RANGE := 14.0       # m from you: further wisps shed no sparkles
const TRAIL_WISPS := 10         # wisps that may shed sparkles at once: BokiWispLook's budget of 300
const PLATE_ABOVE := 15.0       # px of the plate's name line over its bars

## The screen the camera shows: world point to pixels, and how many pixels a metre is at that depth.
class View extends RefCounted:
	var inv: Transform3D
	var focal: float            # px from the eye to the screen, so a metre at depth d is focal / d px
	var mid: Vector2

	func _init(cam_xf: Transform3D, fov_deg: float, screen: Vector2) -> void:
		inv = cam_xf.affine_inverse()
		focal = screen.y * 0.5 / tan(deg_to_rad(fov_deg) * 0.5)
		mid = screen * 0.5

	func px(p: Vector3) -> Vector2:
		var c := inv * p
		return mid + Vector2(c.x, -c.y) * focal / -c.z

	func per_m(p: Vector3) -> float:
		return focal / -(inv * p).z

## Where the wisp rides: an arc behind its Hunter relative to the aim (aim is flat, x/z), on the side whose
## whole arc is furthest from the aim line on screen, sinking a little to stay under its Hunter's plate. Keeps
## its side in the wisp's meta.
static func place(view: View, feet: Vector3, y: float, aim: Vector2, line_len: float, wisp: Node3D,
		t: float) -> Vector3:
	var side := float(wisp.get_meta("side", 1.0))
	var line := aim_line(view, feet, aim, line_len)
	var here := _arc_gap(view, feet, y, aim, side, line)
	if _arc_gap(view, feet, y, aim, -side, line) > here + SIDE_STICKY:
		side = -side
		wisp.set_meta("side", side)
	var swing := SWING * sin(TAU * (t * SWING_HZ + float(wisp.get_meta("phase", 0.0))))
	return _below_plate(view, feet, _at(feet, y, aim, side, swing))

## Its alpha: full in the clear, MIN_ALPHA over the aim line (a screen segment [a, b]), PLATE_ALPHA over any
## rect (a plate, the cursor, your hit circle).
static func alpha(view: View, wisp_at: Vector3, line: PackedVector2Array, rects: Array[Rect2]) -> float:
	var rect_gap_min := INF
	for r in rects:
		rect_gap_min = minf(rect_gap_min, rect_gap(view, wisp_at, r))
	var over_line := lerpf(MIN_ALPHA, 1.0, clampf(line_gap(view, wisp_at, line) / FADE_BAND, 0.0, 1.0))
	var over_rect := lerpf(PLATE_ALPHA, 1.0, clampf(rect_gap_min / FADE_BAND, 0.0, 1.0))
	return minf(over_line, over_rect)

## px between the wisp's edge (its reach) and the aim line's edge: below 0 they overlap.
static func line_gap(view: View, wisp_at: Vector3, line: PackedVector2Array) -> float:
	return _seg_gap(view.px(wisp_at), line[0], line[1]) - (REACH + LINE_HALF) * view.per_m(wisp_at)

## Puts the rules on the node: fade, a shorter trail while firing, and sparkles on or off.
static func apply(wisp: Node3D, fade: float, firing: bool, sparkles: bool) -> void:
	(wisp.get_node("Body") as GeometryInstance3D).set_instance_shader_parameter("fade", fade)
	var trail := wisp.get_node("Trail") as CPUParticles3D
	var life := BokiWispLook.TRAIL_LIFE * (FIRE_TRAIL if firing else 1.0)
	if trail.lifetime != life:
		trail.lifetime = life
	trail.emitting = sparkles
	trail.color.a = fade

## Which of these wisps (their distances from you, m) may shed sparkles: the nearest TRAIL_WISPS in range.
static func sparkly(dists: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(dists.size())
	for i in dists.size():
		var nearer := 0
		for d in dists:
			nearer += 1 if d < dists[i] else 0
		out[i] = 1 if dists[i] <= TRAIL_RANGE and nearer < TRAIL_WISPS else 0
	return out

## The aim line on screen: from the Hunter's feet, line_len m along the aim.
static func aim_line(view: View, feet: Vector3, aim: Vector2, line_len: float) -> PackedVector2Array:
	var end := feet + Vector3(aim.x, 0, aim.y) * line_len
	return PackedVector2Array([view.px(feet), view.px(end)])

## A ground circle (your hit circle) as the screen rect that holds it.
static func ground_rect(view: View, feet: Vector3, radius: float) -> Rect2:
	var rect := Rect2(view.px(feet), Vector2.ZERO)
	for corner in [Vector3(radius, 0, 0), Vector3(-radius, 0, 0), Vector3(0, 0, radius), Vector3(0, 0, -radius)]:
		rect = rect.expand(view.px(feet + corner))
	return rect

## The plate over a Hunter, as the screen rect it covers (its name line, bars and frame).
static func plate_rect(view: View, feet: Vector3) -> Rect2:
	var top := view.px(feet + Vector3(0, HudPlate.PLATE_OFFSET, 0))
	var w := HudStyle.PLATE_W + HudStyle.PLATE_PAD * 2.0
	var h := HudStyle.PLATE_HP_H + HudStyle.PLATE_AR_H + HudStyle.PLATE_PAD * 2.0 + 1.0
	return Rect2(top.x - w * 0.5, top.y - PLATE_ABOVE, w, h + PLATE_ABOVE)

## The spot lowered, by up to MAX_DROP, until it is under its Hunter's plate on screen (or past it).
static func _below_plate(view: View, feet: Vector3, at: Vector3) -> Vector3:
	var plate := plate_rect(view, feet)
	var p := view.px(at)
	var reach := REACH * view.per_m(at)
	if p.x + reach < plate.position.x or p.x - reach > plate.end.x or p.y + reach < plate.position.y:
		return at
	var px_per_m := view.px(at - Vector3.UP).y - p.y
	return at - Vector3.UP * clampf((plate.end.y + reach - p.y) / px_per_m, 0.0, MAX_DROP)

## The wisp's spot at an angle off the aim: side is +1 or -1, swing the offset on the arc.
static func _at(feet: Vector3, y: float, aim: Vector2, side: float, swing: float) -> Vector3:
	var off := aim.rotated(side * (REAR + swing)) * ORBIT_R
	return Vector3(feet.x + off.x, y, feet.z + off.y)

## The smallest gap (px, past the wisp's reach) between the aim line and the wisp anywhere on one side's arc.
static func _arc_gap(view: View, feet: Vector3, y: float, aim: Vector2, side: float, line: PackedVector2Array) -> float:
	var gap := INF
	for s in [-SWING, 0.0, SWING]:
		var at := _at(feet, y, aim, side, s)
		gap = minf(gap, line_gap(view, at, line))
	return gap

static func _seg_gap(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

## px between the wisp's edge and a screen rect (below 0 they overlap).
static func rect_gap(view: View, wisp_at: Vector3, r: Rect2) -> float:
	var p := view.px(wisp_at)
	var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dy := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
	return Vector2(dx, dy).length() - REACH * view.per_m(wisp_at)

## The cursor's reticle (AimReticle.R px round it) on screen, as a rect.
static func cursor_rect(at: Vector2) -> Rect2:
	var r := Vector2(AimReticle.R, AimReticle.R)
	return Rect2(at - r, r * 2.0)
