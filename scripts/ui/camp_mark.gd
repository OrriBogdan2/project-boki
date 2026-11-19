class_name CampMark
extends RefCounted
## The marker for a camp that has not appeared yet (the tutorial's first camp, TutorialCamps.coming): a ring on
## the ground where the monsters will stand and its clock, in the world and on the minimap, drawn like the
## nest marker (NestMap): a dark disc, an icon and the countdown. Every camp has a fixed spot and a timer you
## can read before it comes. (When ext/predictable-camps-1111 lands, draw this through CampMap: docs/DEBT.md.)

const COL := Color("ffd36a")
const RING_PX := 34.0  # the world ring's radius when the camp is about to appear (it closes in as the clock runs)


## The camp's spot and seconds to go, or {} when none is on its way.
static func pending(m: Match) -> Dictionary:
	if m.tut == null or m.tut.camps == null:
		return {}
	return m.tut.camps.coming


static func minimap(hud, to_map: Callable, on_map: Callable) -> void:
	var c := pending(hud.m)
	if c.is_empty():
		return
	var pv: Vector2 = to_map.call(c["at"])
	if on_map.call(pv, 4.0):
		_disc(hud, pv, MapDetail.ICON_R * 0.8, c)


static func world(hud) -> void:
	var c := pending(hud.m)
	if c.is_empty() or hud.m.cam.is_position_behind(c["at"]):
		return
	var gp: Vector2 = hud.m.cam.unproject_position(c["at"] + Vector3(0, 0.05, 0))
	var k := clampf(float(c["left"]) / TutorialCamps.TELEGRAPH_T, 0.0, 1.0)
	hud.c.draw_arc(gp, RING_PX * (1.0 + k), 0, TAU, 32, Color(COL, 0.9), 3.0, true)
	_disc(hud, gp + Vector2(0, -RING_PX * 1.6), 16.0, c)


static func _disc(hud, pv: Vector2, s: float, c: Dictionary) -> void:
	var cv: Control = hud.c
	cv.draw_circle(pv, s * 1.35, Color(0, 0, 0, 0.7))
	cv.draw_arc(pv, s * 1.35, 0, TAU, 20, COL, 1.5, true)
	Icons.draw(cv, "paw", pv, s * 0.8, COL)
	hud._ctext(pv + Vector2(0, -s * 1.6), Lairs.clock(float(c["left"])), 10 if s < 10.0 else 18, Color.WHITE, hud.big)
