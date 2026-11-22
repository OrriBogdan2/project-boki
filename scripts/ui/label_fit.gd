class_name LabelFit
## Keeps a billboard world label on the screen: inside the safe frame and clear of the HUD blocks, the tutorial strip
## and the hunter's box. It moves the drawn text (Label3D.offset), never the label's place in the world.

const PASSES := 3  # times it looks over the blocks to avoid
const GAP := 6.0  # px kept between the label and whatever it steps aside for


## `lbl` nudged on screen (px, screen space) clear of every Rect2 in `avoid`, then inside `frame`.
static func fit(lbl: Label3D, cam: Camera3D, frame: Rect2, avoid: Array) -> void:
	lbl.offset = Vector2.ZERO
	if not lbl.visible or cam.is_position_behind(lbl.global_position):
		return
	var box := MsgLane.label_rect(lbl, cam)
	var d := Vector2.ZERO
	for pass_i in PASSES:  # (a step aside can land on the next block: look again)
		for a: Rect2 in avoid:
			var cur := Rect2(box.position + d, box.size)
			if a.has_area() and cur.intersects(a):
				var up := a.position.y - cur.end.y - GAP
				var down := a.end.y - cur.position.y + GAP
				var up_ok := cur.position.y + up >= frame.position.y  # (a way out of the frame is no way)
				var down_ok := cur.end.y + down <= frame.end.y
				if up_ok and (-up < down or not down_ok):
					d.y += up
				elif down_ok:
					d.y += down
		var at := Rect2(box.position + d, box.size)
		d.x += maxf(0.0, frame.position.x - at.position.x) - maxf(0.0, at.end.x - frame.end.x)
		d.y += maxf(0.0, frame.position.y - at.position.y) - maxf(0.0, at.end.y - frame.end.y)
	if d == Vector2.ZERO:
		return
	var sp := cam.unproject_position(lbl.global_position)
	var depth := (lbl.global_position - cam.global_position).dot(-cam.global_basis.z)
	var w := cam.project_position(sp + d, depth) - lbl.global_position
	lbl.offset = Vector2(w.dot(cam.global_basis.x), w.dot(cam.global_basis.y)) / lbl.pixel_size
