class_name AimReticle
extends Control
## The cursor states of AimKit (docs/AIMKIT.md), for the local player only, drawn on the crosshair:
## - charge ring: a thin arc that fills with the charge (0..1) at 26 px, outside the HUD's ammo ring;
## - full-charge flare: on reaching full, a ring that snaps out and fades plus a 4-point glint (0.28 s);
## - perfect-window star: a gold 4-point star with a soft ring, held for one footage frame (0.12 s).

const R := 26.0           # px: the charge ring's radius, outside the HUD's ammo and resource arcs (Reticle.RES_R)
const FLARE_T := 0.28     # s: the full-charge flare
const PERFECT_T := 0.12   # s: the perfect-window star (one 5 fps footage frame, enough to register)

var d: AimDraw

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Where the cursor is on screen: the mouse in live play, the aim point projected when a tool drives
## the match (checks and screenshots step it by hand).
func cursor(h: Hunter) -> Vector2:
	if d.m.is_processing():
		return get_viewport().get_mouse_position()
	var cam: Camera3D = d.m.get("cam")
	var a: Vector3 = h.inp.get("aim", h.pos)
	if cam == null or cam.is_position_behind(a):
		return Vector2(-999, -999)
	return cam.unproject_position(a)

func _draw() -> void:
	var me = d.m.get("player")
	if me == null or bool(d.m.get("paused")) or not d.ret.has(me.get_instance_id()):
		return
	var r: Dictionary = d.ret[me.get_instance_id()]
	var mp := cursor(me)
	var col: Color = r["col"]
	var k := float(r["k"])
	if k >= 0.0 and float(d.m.time) - float(r["t"]) <= AimDraw.KEEP:
		draw_arc(mp, R, 0.0, TAU, 40, Color(0, 0, 0, 0.3), 3.0, true)
		if k > 0.0:
			var full := k >= 1.0
			draw_arc(mp, R, -PI * 0.5, -PI * 0.5 + TAU * minf(1.0, k), 40, Color(col.lerp(Color.WHITE, 0.4 if full else 0.0), 0.95 if full else 0.75), 3.0 if full else 2.0, true)
	var ft := float(r["flare"])
	if ft > 0.0:
		var t := 1.0 - ft / FLARE_T            # 0 -> 1 over the flare
		var e := 1.0 - pow(1.0 - t, 3.0)        # out-cubic
		var fc: Color = r["fcol"]
		draw_arc(mp, R + 4.0 + e * 16.0, 0.0, TAU, 40, Color(fc.lerp(Color.WHITE, 0.5), 0.9 * (1.0 - t)), 2.5, true)
		_star(mp, 10.0 + 8.0 * (1.0 - t), Color(fc.lerp(Color.WHITE, 0.7), 0.95 * (1.0 - t)), PI * 0.25)
	var pt := float(r["perfect"])
	if pt > 0.0:
		var pc: Color = r["pcol"]
		var a := 1.0                            # a flash: full strength for its whole (short) life, then gone
		draw_circle(mp, 20.0, Color(pc, 0.18 * a))
		draw_arc(mp, 20.0, 0.0, TAU, 40, Color(pc, 0.7 * a), 2.0, true)
		_star(mp, 23.0, Color(0.1, 0.06, 0.0, 0.35 * a), 0.0, 1.5)
		_star(mp, 20.0, Color(pc.lerp(Color.WHITE, 0.25), a), 0.0)

## A 4-point star (a glint) of radius s.
func _star(c: Vector2, s: float, col: Color, rot := 0.0, waist_k := 1.0) -> void:
	var w := s * 0.2 * waist_k
	var pts := PackedVector2Array()
	for i in 8:
		var a := rot + i * PI * 0.25
		pts.append(c + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else w))
	draw_colored_polygon(pts, col)
