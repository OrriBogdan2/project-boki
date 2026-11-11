class_name CampMap
extends RefCounted
## The monster camps (Camps) and the lairs' boss wake times (Lairs.wake_left) on the minimap and the full map.
## The map is fixed, so the full map marks every camp spot with a faint dot. A camp your squad has seen shows
## its reward icon and one pip per tier; once cleared it greys out over the countdown to its return. A live lair
## whose boss has not risen yet shows the countdown to its wake.

const DIM := Color(0.6, 0.62, 0.68, 0.6)
const CAMP_COL := Color("ff7a5a")      # a camp with no named reward (generated maps)
const ICON_S := 4.5                    # px: the camp icon's radius on the full map (the minimap uses MapDetail.ICON_R)
const CLOCK_FS := 10

static func minimap(hud, to_map: Callable, on_map: Callable, hold: bool) -> void:
	var m: Match = hud.m
	if m.camps != null:
		for camp in m.camps.list:
			if not camp["seen"] or not MapDetail.shows("camp", hold, not camp["up"]):
				continue
			var pv: Vector2 = to_map.call(camp["pos"])
			if on_map.call(pv, 4.0):
				_camp(hud, pv, MapDetail.ICON_R * 0.75, camp, m.camps.left(camp))
	if m.lairs != null and MapDetail.shows("lair", hold):
		for L in m.lairs.list:
			var pv: Vector2 = to_map.call(L["c"])
			if on_map.call(pv, 4.0):
				_wake_clock(hud, pv + Vector2(0, MapDetail.ICON_R * 2.0), m.lairs.wake_left(L))

static func full_map(fm) -> void:
	var m: Match = fm.m
	var area: Rect2 = fm.rect.grow(-4.0)
	if m.camps != null:
		for camp in m.camps.list:
			var pv: Vector2 = fm.to_screen(camp["pos"])
			if not area.has_point(pv):
				continue
			if camp["seen"]:
				_camp(fm.hud, pv, ICON_S, camp, m.camps.left(camp))
			else:
				fm.hud.c.draw_circle(pv, 2.5, Color(DIM, 0.45))
	if m.lairs != null:
		for L in m.lairs.list:
			var pv: Vector2 = fm.to_screen(L["c"])
			if area.has_point(pv):
				_wake_clock(fm.hud, pv + Vector2(0, 24), m.lairs.wake_left(L))

## A seen camp: its reward icon in a dark disc and a pip per tier, greyed with its countdown while cleared.
static func _camp(hud, pv: Vector2, s: float, camp: Dictionary, left: float) -> void:
	var c: Control = hud.c
	var reward: Dictionary = Camps.REWARDS.get(camp["reward"], {})
	var col: Color = reward.get("col", CAMP_COL) if camp["up"] else DIM
	c.draw_circle(pv, s * 1.35, Color(0, 0, 0, 0.7))
	c.draw_arc(pv, s * 1.35, 0, TAU, 20, col, 1.5, true)
	Icons.draw(c, String(reward.get("icon", "burst")), pv, s * 0.8, col)
	var tier := int(camp["tier"])
	for i in tier:
		c.draw_circle(pv + Vector2((i - (tier - 1) * 0.5) * s * 0.7, s * 1.35 + 2.5), maxf(1.2, s * 0.2), col)
	if not camp["up"] and left < INF:
		hud._ctext(pv + Vector2(0, -s * 1.6), Lairs.clock(left), CLOCK_FS, Color.WHITE, hud.big)

static func _wake_clock(hud, at: Vector2, left: float) -> void:
	if left > 0.0:
		hud._ctext(at, "WAKES " + Lairs.clock(left), CLOCK_FS, Color("ffd36a"), hud.big)
