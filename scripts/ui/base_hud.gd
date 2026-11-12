class_name BaseHud
extends RefCounted
## Basing to a teammate on screen (BaseRecall, BaseWheel):
##   - anyone basing, foe or friend: a ring filling round them with the seconds left, and over the teammate
##     they'll appear beside, "<name> incoming" with the same ring (the circle on the ground is a world Fx)
##   - the B wheel: a slice per teammate round where you started holding B, each with their framed portrait
##     and name, greyed when they can't take you, the one you point at lit in mint. One teammate: one ring.

const RIN := 30.0             # px: the dead zone's drawn edge (inside it, letting go cancels)
const PORTRAIT := 40.0        # px: a slice's portrait


static func draw(H) -> void:
	var m: Match = H.m
	for h: Hunter in m.hunters:
		if h.base_t > 0.0 and not h.out and not (h.unseen and h != m.player):
			_channel(H, h)
	if m.player and BaseWheel.is_open(m.player):
		_wheel(H, m.player)


static func _channel(H, h: Hunter) -> void:
	var cam: Camera3D = H.m.cam
	var mint := BaseRecall.MINT
	var f := BaseRecall.progress(h)
	if not cam.is_position_behind(h.position):
		var sp: Vector2 = cam.unproject_position(h.position + Vector3(0, 0.2, 0))
		H.c.draw_arc(sp, 26.0, 0, TAU, 40, Color(mint, 0.25), 3.0, true)
		H._arc(sp, 26.0, f, mint, 4.0)
		H._ctext(sp + Vector2(0, 44), "BASING  %.1f" % h.base_t, 12, mint, H.big)
	var to: Hunter = h.base_to
	if to and is_instance_valid(to) and not cam.is_position_behind(to.position):
		var tsp: Vector2 = cam.unproject_position(to.position + Vector3(0, 3.0, 0))
		H._ctext(tsp, "%s incoming  %.1f" % [h.pname.substr(0, 14), h.base_t], 12, mint, H.big)
		var gsp: Vector2 = cam.unproject_position(to.position + Vector3(0, 0.1, 0))
		H.c.draw_arc(gsp, 22.0, 0, TAU, 32, Color(mint, 0.3), 2.0, true)
		H._arc(gsp, 22.0, f, mint, 3.0)


static func _wheel(H, p: Hunter) -> void:
	var w: Dictionary = p.inp["bwheel"]
	var mates: Array = w["mates"]
	var n := mates.size()
	var o: Vector2 = w["o"]
	var pop := KinWheel.pop_at(float(w["t"]))
	var rin := RIN * pop
	var rout := float(KinWheel.rules()["radius_px"]) * 1.25 * pop
	var sel := int(w["sel"])
	var mint := BaseRecall.MINT
	for i in n:
		var mate: Hunter = mates[i]
		var ok := BaseRecall.can_take(p, mate)
		var lit := sel == i
		var a := BaseWheel.dir(i, n).angle()
		var fill := Color(mint, 0.55) if lit and ok else Color(0.03, 0.04, 0.07, 0.75)
		if lit and not ok:
			fill = Color(0.35, 0.36, 0.4, 0.75)
		if n == 1:
			H.c.draw_arc(o, (rin + rout) * 0.5, 0.0, TAU, 48, fill, rout - rin, true)
		else:
			H.c.draw_colored_polygon(_wedge(o, a, PI / float(n) - 0.04, rin, rout), fill)
		var mid := o + BaseWheel.dir(i, n) * (rin + rout) * 0.5
		var r := Rect2(mid - Vector2(PORTRAIT, PORTRAIT + 14.0) * 0.5, Vector2(PORTRAIT, PORTRAIT))
		var edge := mint if lit and ok else Color(H.INK, 0.3)
		H._draw_portrait(r, mate, "down" if mate.downed else "", edge)
		if not ok:
			H.c.draw_rect(r, Color(0.08, 0.08, 0.1, 0.6))
		var name_col := Color(H.INK, 0.9 if ok else 0.45)
		if lit:
			name_col = Color.WHITE
		H._ctext(mid + Vector2(0, PORTRAIT * 0.5 + 6.0), mate.pname.substr(0, 12), 13, name_col, H.big)
		if not ok:
			H._ctext(mid + Vector2(0, PORTRAIT * 0.5 + 19.0), "can't take you", 10, Color(H.INK, 0.5), H.big)
	H.c.draw_circle(o, rin - 4.0, Color(0.03, 0.04, 0.07, 0.85))
	H._ctext(o + Vector2(0, 4), Settings.key_cap("base"), 13, Color(H.INK, 0.6), H.big)
	if sel >= 0:
		H.c.draw_line(o, o + BaseWheel.dir(sel, n) * (rin - 6.0), mint, 3.0, true)


## A ring slice round `o`, centred on angle `a`, `half` radians to each side.
static func _wedge(o: Vector2, a: float, half: float, rin: float, rout: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for j in 17:
		var t := a - half + 2.0 * half * float(j) / 16.0
		pts.append(o + Vector2(cos(t), sin(t)) * rout)
	for j in range(16, -1, -1):
		var t := a - half + 2.0 * half * float(j) / 16.0
		pts.append(o + Vector2(cos(t), sin(t)) * rin)
	return pts
