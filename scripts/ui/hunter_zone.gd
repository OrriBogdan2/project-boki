class_name HunterZone
extends RefCounted
## The screen area over your own hunter (feet to the top of the overhead plate). No popup may cover
## it: floating numbers and words (Fx), the message lane's cards (MsgLane) and the knock banner slide
## sideways out of it, and world labels (plates, lair boards) fade under it (LabelSpacing).

const MIN_HALF_W := 40.0  # px: the zone is at least this far either side of the hunter's middle
const BODY_HALF_K := 0.32  # of the hunter's height on screen: the half width
const PLATE_UP := 2.7  # m over the feet (times the hunter's scale): the overhead plate (Hud._draw_overhead)
const FEET_PAD := 10.0  # px under the feet
const NEAR_PX := 260.0  # px: a label farther than this from the zone is not measured
const SIDE_GAP := 6.0  # px: a slid box stops this far off the zone, so it never grazes it


## The zone in screen px; an empty Rect2 when there is no hunter on screen to keep clear.
static func rect(m: Match) -> Rect2:
	var p: Hunter = m.player
	if p == null or m.cam == null or p.out or p.downed or p.riding:
		return Rect2()
	var up := Vector3(0, PLATE_UP * float(p.cdat["scale"]), 0)
	var feet := p.position
	var head := p.position + m.cam.char_lean() * up
	if m.cam.is_position_behind(head) or m.cam.is_position_behind(feet):
		return Rect2()
	var top := m.cam.unproject_position(head)
	var bottom := m.cam.unproject_position(feet)
	if not top.is_finite() or not bottom.is_finite():
		return Rect2()
	var half := maxf(MIN_HALF_W, absf(bottom.y - top.y) * BODY_HALF_K)
	var mid := (top.x + bottom.x) * 0.5
	return Rect2(mid - half, top.y - 20.0, half * 2.0, bottom.y - top.y + FEET_PAD + 20.0)


## The sideways move (px, negative = left) that takes `box` out of `zone`: to whichever side is nearer. 0 when clear.
static func slide(box: Rect2, zone: Rect2) -> float:
	if not zone.has_area() or not box.intersects(zone):
		return 0.0
	var left := zone.position.x - box.end.x - SIDE_GAP
	var right := zone.end.x - box.position.x + SIDE_GAP
	return left if -left < right else right


## `lbl` (a floating number or word) moved sideways, in the camera's plane, out of `zone`.
static func clear_label(lbl: Label3D, cam: Camera3D, zone: Rect2) -> void:
	if not zone.has_area() or not lbl.visible or cam.is_position_behind(lbl.global_position):
		return
	var sp := cam.unproject_position(lbl.global_position)
	if not zone.grow(NEAR_PX).has_point(sp):
		return
	var dx := slide(MsgLane.label_rect(lbl, cam), zone)
	if dx != 0.0:
		var depth := (lbl.global_position - cam.global_position).dot(-cam.global_basis.z)
		lbl.global_position = cam.project_position(sp + Vector2(dx, 0.0), depth)
