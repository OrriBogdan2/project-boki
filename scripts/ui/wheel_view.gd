class_name WheelView
extends RefCounted
## A flick wheel drawn on the HUD: wedges with a label and a hint each, popped open with an ease-out-back,
## the one under the flick lit. Shared by the Boki order wheel (G) and the ping wheel.

## Draws `w` ({o: where it opened, sel: lit wedge or -1, t: seconds open}) as `segments` in `col`.
## `hints` maps a segment id to its small line; `current` is the id to mark as already chosen.
static func draw(H, w: Dictionary, segments: Array, col: Color, hints: Dictionary, current := "") -> void:
	var o: Vector2 = w["o"]
	var pop := KinWheel.pop(float(w["t"]))
	var rin := 26.0 * pop
	var rout := float(KinWheel.rules()["radius_px"]) * pop
	for i in segments.size():
		var sg: Dictionary = segments[i]
		var a: float = (sg["dir"] as Vector2).angle()
		var pts := PackedVector2Array()
		for j in 11:
			var t := a - PI / 4.0 + 0.04 + (PI / 2.0 - 0.08) * float(j) / 10.0
			pts.append(o + Vector2(cos(t), sin(t)) * rout)
		for j in range(10, -1, -1):
			var t := a - PI / 4.0 + 0.04 + (PI / 2.0 - 0.08) * float(j) / 10.0
			pts.append(o + Vector2(cos(t), sin(t)) * rin)
		var lit := int(w["sel"]) == i
		H.c.draw_colored_polygon(pts, Color(col, 0.62) if lit else Color(0.03, 0.04, 0.07, 0.72))
		var mid := o + (sg["dir"] as Vector2) * (rin + rout) * 0.5
		var label_col := Color.WHITE if lit else Color(H.INK, 0.92)
		H._ctext(mid + Vector2(0, -2), String(sg["label"]).to_upper(), 15, label_col, H.big)
		H._ctext(mid + Vector2(0, 12), String(hints.get(sg["id"], "")), 10, Color(H.INK, 0.85 if lit else 0.55), H.big)
		if String(sg["id"]) == current:
			H.c.draw_circle(mid + Vector2(0, -20), 3.0, col)
	H.c.draw_circle(o, rin - 4.0, Color(0.03, 0.04, 0.07, 0.8))
	var sel := int(w["sel"])
	if sel >= 0:
		H.c.draw_line(o, o + (segments[sel]["dir"] as Vector2) * (rin - 6.0), col, 3.0, true)
