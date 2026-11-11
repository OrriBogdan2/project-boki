class_name LabelCull
extends RefCounted
## Which world labels get laid out this frame (item 94: labels and nameplates were 2.8 ms a frame).
## Hud._draw_world_labels walked every Hunter, monster, Boki, deathbox and beacon on the map and laid
## out its plate or label even when it was off screen or across the map. Now an anchor that is behind
## the camera, past FAR_M from what the camera follows, or beyond EDGE_PX off the screen is skipped
## before anything is measured or drawn.

const FAR_M := 60.0            # m (flat) from the camera's focus: nothing further gets a plate or label
const EDGE_PX := 120.0         # how far past the screen edge an anchor may be and still draw (plates are wide)
const RIDE_M := 5.0            # m (flat): aboard the sky ship a rival's plate draws only this close (30 riders'
                               # plates stacked on one deck read as nothing and cost half the ride's HUD frame)

## nid -> the frame its plate was last laid out (checks read it), and how many were skipped last frame
static var laid := {}
static var skipped := 0

## Where to draw a label anchored at `wpos`, or Vector2.INF when it isn't worth laying out.
static func at(H, wpos: Vector3, far := FAR_M) -> Vector2:
	var cam = H.m.cam
	if cam == null or cam.is_position_behind(wpos):
		skipped += 1
		return Vector2.INF
	var f: Vector3 = H.m.player.pos if H.m.player and not H.m.player.out else cam.focus
	if Vector2(wpos.x - f.x, wpos.z - f.z).length_squared() > far * far:
		skipped += 1
		return Vector2.INF
	var sp: Vector2 = cam.unproject_position(wpos)
	if not sp.is_finite() or not (H.c as CanvasItem).get_viewport_rect().grow(EDGE_PX).has_point(sp):
		skipped += 1
		return Vector2.INF
	return sp

## A plate drawn for this entity this frame.
## While the local player rides the sky ship: a rival further than RIDE_M along the deck gets no plate.
static func ride_skip(m: Match, h: Hunter) -> bool:
	var me: Hunter = m.player
	if me == null or not me.riding or h.team == me.team:
		return false
	return h.flat_dist(me) > RIDE_M
static func mark(e: Ent) -> void:
	laid[e.nid] = Engine.get_process_frames()

## Start of a frame's labels.
static func begin() -> void:
	skipped = 0
	if laid.size() > 512:
		laid.clear()
