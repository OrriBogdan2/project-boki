class_name BondHud
extends RefCounted
## The bond pull on the HUD (docs/decisions/0008, KinTrack), drawn through the in-match HUD `H`:
##   - the squad of a captured Boki, once up: "<Boki> is this way" over the captor, or an arrow at the screen edge
##   - the captor: a "Tracked" chip while they carry one
## Kept out of hud.gd (a god file): hud.gd makes one call.

const COL := Color("f2c84a")
const EDGE := 0.44          # share of the short screen side: how far from the centre the edge arrow sits

static func draw(H) -> void:
	var m = H.m
	var p: Hunter = m.player
	if p == null:
		return
	var sz: Vector2 = H.c.size
	if KinTrack.tracked(p) and not p.out:
		_tracked(H, sz)
	var carried := KinLoss.rescuing(p)
	if carried != null:
		_carrying(H, sz, carried)
	if not KinTrack.pulling(p):
		return
	var th := KinTrack.captor_for(m, p.team)
	if th == null:
		return
	var label := "%s is this way" % KinTrack.name_for(th, p.team)
	var cam: Camera3D = m.cam
	var tp := cam.unproject_position(th.position + Vector3(0, 2.8, 0))
	var behind := cam.is_position_behind(th.position)
	if not behind and Rect2(Vector2(30, 30), sz - Vector2(60, 60)).has_point(tp):
		H._ctext(tp, label, 15, COL, H.big)
		var chevron := PackedVector2Array([tp + Vector2(-8, 6), tp + Vector2(8, 6), tp + Vector2(0, 16)])
		H.c.draw_colored_polygon(chevron, COL)
		return
	var ctr := sz * 0.5
	var d := (ctr - tp).normalized() if behind else (tp - ctr).normalized()
	var edge := ctr + d * minf(sz.x, sz.y) * EDGE
	var perp := Vector2(-d.y, d.x)
	var tip := PackedVector2Array([edge + d * 18.0, edge - d * 6.0 + perp * 11.0, edge - d * 6.0 - perp * 11.0])
	H.c.draw_colored_polygon(tip, COL)
	H._ctext(edge - d * 30.0, label, 13, COL, H.big)
	H._ctext(edge - d * 46.0, "%dm" % int(p.flat_dist(th)), 12, Color(H.INK, 0.9), H.big)

static func _tracked(H, sz: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(H.m.time * 5.0)
	var c := Vector2(sz.x * 0.5, 96.0 + H.alerts_h)
	var r := Rect2(c - Vector2(58, 14), Vector2(116, 28))
	H._rounded(r, Color(0.05, 0.03, 0.03, 0.8), 14, Color(1.0, 0.35, 0.3, 0.6 + 0.4 * pulse), 2)
	H.c.draw_arc(c + Vector2(-38, 0), 7.0, 0, TAU, 20, Color(1.0, 0.45, 0.35), 2.0, true)
	H.c.draw_circle(c + Vector2(-38, 0), 2.5, Color(1.0, 0.45, 0.35))
	H._ctext(c + Vector2(8, 5), "TRACKED", 13, Color(1.0, 0.55, 0.45), H.big)

## While you carry your Boki: what it is and how to put it down.
static func _carrying(H, sz: Vector2, k: Kin) -> void:
	var line := "Carrying %s  ·  %s to drop" % [k.rec.get("name", "your Boki"), Settings.key_cap("dash")]
	H._ctext(Vector2(sz.x * 0.5, sz.y * 0.72), line, 16, Color(H.INK, 0.95), H.big)
