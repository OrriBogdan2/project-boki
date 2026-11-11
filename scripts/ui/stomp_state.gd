class_name StompState
extends RefCounted
## What a running stomp (Stomp, 3 s) tells the people it matters to, in plain words, in HudStyle:
##   - the wisp being stomped: a ring timer round their own wisp and one line (WISP_LINE)
##   - their teammates: that player's squad row flashes a stomp icon with the same timer, and when
##     they are off screen the squad arrow carries it too
##   - the stomper is locked, so they get nothing new
## It reads the live stomp, so it is gone the moment the stomp breaks or finishes.

const WISP_LINE := "Being stomped: a stun on the stomper saves you"
const RING_R := 36.0           # px: the ring round your own wisp
const BADGE_R := 11.0          # px: a teammate's badge (row and arrow)
const FLASH_HZ := 8.0          # flashes a second on a teammate's badge
const SAFE := Vector2(70, 90)  # px: kept clear of the screen edge, left/right and top/bottom (as the squad arrows)

## Who is stomping `o` right now, or null.
static func of(o: Hunter) -> Hunter:
	if not o.has_meta("stomped_by"):
		return null
	var s = o.get_meta("stomped_by")
	if not is_instance_valid(s) or (s as Hunter).stomp.is_empty() or (s as Hunter).stomp["o"] != o:
		return null
	return s

## The seconds of the stomp left, 3 (just started) down to 0.
static func left(stomper: Hunter) -> float:
	return clampf(Stomp.TIME - float(stomper.stomp["t"]), 0.0, Stomp.TIME)

## Your own wisp's ring timer, kept inside the screen's safe area. True when you are being stomped.
static func draw_wisp(c: CanvasItem, m: Match, p: Hunter, sz: Vector2) -> bool:
	var s := of(p)
	if s == null:
		return false
	var at := m.cam.unproject_position(p.pos + Vector3(0, 1.0, 0))
	at = at.clamp(SAFE + Vector2.ONE * RING_R, sz - SAFE - Vector2.ONE * RING_R)
	var f := left(s) / Stomp.TIME
	c.draw_circle(at, RING_R + 4.0, Color(HudStyle.SHADE, 0.7))
	c.draw_arc(at, RING_R, 0.0, TAU, 40, Color(HudStyle.STOMPED, 0.25), 5.0, true)
	c.draw_arc(at, RING_R, -PI * 0.5, -PI * 0.5 + TAU * f, 40, HudStyle.STOMPED, 5.0, true)
	HudStyle.ctext(c, at + Vector2(0, 8), "%.1f" % left(s), 22, HudStyle.INK)
	return true

## A teammate's squad row: the flashing stomp badge on the row's right side.
static func draw_row(c: CanvasItem, r: Rect2, mate: Hunter, time: float) -> void:
	var s := of(mate)
	if s != null:
		_badge(c, Vector2(r.end.x - 20.0, r.position.y + 38.0), s, time)

## The same badge beside a teammate's off-screen arrow at `edge` (`side`: along the screen edge).
static func draw_arrow(c: CanvasItem, edge: Vector2, side: Vector2, mate: Hunter, time: float) -> void:
	var s := of(mate)
	if s != null:
		_badge(c, edge + side * 28.0, s, time)

static func _badge(c: CanvasItem, at: Vector2, s: Hunter, time: float) -> void:
	var flash := 0.65 + 0.35 * sin(time * FLASH_HZ)
	var col := Color(HudStyle.STOMPED, flash)
	c.draw_circle(at, BADGE_R + 3.0, Color(HudStyle.SHADE, 0.9))
	c.draw_arc(at, BADGE_R, -PI * 0.5, -PI * 0.5 + TAU * left(s) / Stomp.TIME, 28, col, 3.0, true)
	Icons.draw(c, "stomp", at, BADGE_R * 0.55, col.lerp(Color.WHITE, 0.3))
