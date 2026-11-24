class_name NumSpacing
extends RefCounted
## Floating numbers on one spot keep apart (docs/HUD.md, Damage numbers): each frame, a smaller number
## that prints over a bigger one (or, same size, a newer over an older one) slides sideways, in the
## camera's plane, just clear of it, the way numbers slide out of the HunterZone. So a focused target's
## rolled hit, its tick, its heal and a tick floating off never pile up into one blot
## (`--dmg-number-check`: at most 3 over one spot in a trio focus).

const GAP := 4.0  # px left between a slid number and the one it cleared


## `nums`: Fx.nums. Only damage and heal numbers ("val") are spaced; words stack on their own (Fx._clear_spot).
static func spread(nums: Array, cam: Camera3D) -> void:
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
