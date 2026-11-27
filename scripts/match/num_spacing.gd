class_name NumSpacing
extends RefCounted
## Floating numbers on one spot keep apart (docs/HUD.md, Damage numbers): each frame, a smaller number
## that prints over a bigger one (or, same size, a newer over an older one) slides sideways, in the
## camera's plane, just clear of it, the way numbers slide out of the HunterZone. So a focused target's
## rolled hit, its tick, its heal and a tick floating off never pile up into one blot
## (`--dmg-number-check`: at most 3 over one spot in a trio focus).

const GAP := 4.0  # px left between a slid number and the one it cleared


## `nums`: Fx.nums. Only damage and heal numbers ("val") are spaced; words stack on their own (Fx._clear_spot).
## `zone` (HunterZone.rect, may be empty): a number never slides back into it while clearing another.
static func spread(nums: Array, cam: Camera3D, zone := Rect2()) -> void:
	if cam == null:
		return
	var live: Array = []
	for n in nums:
		var l: Label3D = n["node"]
		if n.has("val") and l.visible and not cam.is_position_behind(l.global_position):
			live.append(n)
	if live.size() < 2:
		return
	live.sort_custom(_first)
	var placed: Array[Rect2] = []
	for n in live:
		var l: Label3D = n["node"]
		var box := MsgLane.label_rect(l, cam)
		var x0 := box.position.x
		for r in placed:
			if box.intersects(r):
				box.position.x += _slide(box, r)
		if zone.has_area() and box.intersects(zone):
			box.position.x += _clear_zone(box, zone, placed)
		var dx := box.position.x - x0
		if dx != 0.0:
			var depth := (l.global_position - cam.global_position).dot(-cam.global_basis.z)
			var at := cam.unproject_position(l.global_position) + Vector2(dx, 0.0)
			l.global_position = cam.project_position(at, depth)
		placed.append(box)


## Bigger numbers keep their spot; among equals, the older one does.
static func _first(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = (a["node"] as Label3D).font_size
	var sb: int = (b["node"] as Label3D).font_size
	return sa > sb if sa != sb else float(a["t"]) > float(b["t"])


## The sideways move (px) that takes `box` just clear of `r`, to whichever side is nearer.
static func _slide(box: Rect2, r: Rect2) -> float:
	var left := r.position.x - box.end.x - GAP
	var right := r.end.x - box.position.x + GAP
	return left if -left < right else right


## The sideways move (px) that takes `box` out of the hunter's `zone`: to the side where it also lands clear of the
## numbers already `placed`, else the nearer side (a number beside another beats a number over your hunter).
static func _clear_zone(box: Rect2, zone: Rect2, placed: Array[Rect2]) -> float:
	var left := zone.position.x - box.end.x - GAP
	var right := zone.end.x - box.position.x + GAP
	var left_free := true
	var right_free := true
	for r in placed:
		left_free = left_free and not Rect2(box.position + Vector2(left, 0.0), box.size).intersects(r)
		right_free = right_free and not Rect2(box.position + Vector2(right, 0.0), box.size).intersects(r)
	if left_free != right_free:
		return left if left_free else right
	return left if -left < right else right
