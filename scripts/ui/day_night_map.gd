class_name DayNightMap
extends RefCounted
## The day/night cycle on the HUD (DayNight): the phase row (a sun or moon, the phase and the seconds to the
## next swap) and the camps that follow a phase, on the minimap and the full map, drawn like nests (NestMap):
## a dark disc and an icon, a moon for a night camp and a sun for a day camp. A camp that is up is bright; one
## that is down is dim, with the seconds until its phase comes round. A burst marks the night's elite,
## shown from the start at its fixed spot. The minimap shows the camps near you, the ones
## about to wake and the awake ones; the full map shows every one.

const NEAR_M := 60.0  # a camp this close matters (shows on the default minimap)
const SOON_S := 40.0  # a camp this close to waking matters
const ICON_S := 4.5  # px on the full map (the minimap uses MapDetail.ICON_R)
const DIM := Color(0.6, 0.62, 0.68, 0.6)


## The phase row inside the HUD's weather row `r`: the icon, the phase name and the time to the swap.
static func row(hud, r: Rect2) -> void:
	var dn: DayNight = hud.m.day_night
	var t: float = hud.m.sess_time()
	var night := dn.is_night(t)
	var col := DayNight.NIGHT_COL if night else DayNight.DAY_COL
	Icons.draw(hud.c, "moon" if night else "sun", r.position + Vector2(12, 10), 7.0, col)
	var label := (
		("NIGHT" if night else "DAY")
		+ "  ·  "
		+ ("DAY" if night else "NIGHT")
		+ " IN "
		+ Lairs.clock(dn.left_in_phase(t))
	)
	hud._text(r.position + Vector2(24, 14), label, 10, col, hud.big)


static func minimap(hud, to_map: Callable, on_map: Callable, hold: bool) -> void:
	var m: Match = hud.m
	if m.player == null or not m.day_night.on():
		return
	var dn: DayNight = m.day_night
	var t := m.sess_time()
	for sp: Dictionary in dn.spawns.phase_spots():
		var up := _up(dn, sp, t)
		var soon := not up and dn.left_in_phase(t) < SOON_S
		if not MapDetail.shows("dark_camp", hold, up or soon or m.player.flat_dist(sp["pos"]) < NEAR_M):
			continue
		var pv: Vector2 = to_map.call(sp["pos"])
		if on_map.call(pv, 4.0):
			_camp(hud, pv, MapDetail.ICON_R * 0.75, sp, up, dn.left_in_phase(t))
	var bp := _boss_at(dn, t)
	if bp != Vector3.INF:
		_boss(hud, to_map.call(bp), MapDetail.ICON_R * 0.8, on_map, t)


static func full_map(fm) -> void:
	var m: Match = fm.m
	if not m.day_night.on():
		return
	var dn: DayNight = m.day_night
	var t := m.sess_time()
	var area: Rect2 = fm.rect.grow(-4.0)
	for sp: Dictionary in dn.spawns.phase_spots():
		var pv: Vector2 = fm.to_screen(sp["pos"])
		if area.has_point(pv):
			_camp(fm.hud, pv, ICON_S, sp, _up(dn, sp, t), dn.left_in_phase(t))
	var bp := _boss_at(dn, t)
	if bp != Vector3.INF:
		var bv: Vector2 = fm.to_screen(bp)
		if area.has_point(bv):
			_boss(fm.hud, bv, ICON_S, func(_p, _r): return true, t)


## Is a camp of this phase up now (its phase is the one running)?
static func _up(dn: DayNight, sp: Dictionary, t: float) -> bool:
	return (sp["mode"] == "night") == dn.is_night(t)


## The elite's spot to mark: the standing night's, else the next night's.
static func _boss_at(dn: DayNight, t: float) -> Vector3:
	return dn.spawns.boss_spot(dn.next_night(t))


static func _camp(hud, pv: Vector2, s: float, sp: Dictionary, up: bool, left: float) -> void:
	var c: Control = hud.c
	var night: bool = sp["mode"] == "night"
	var col := DIM
	if up:
		col = DayNight.NIGHT_COL if night else DayNight.DAY_COL
	c.draw_circle(pv, s * 1.35, Color(0, 0, 0, 0.7))
	c.draw_arc(pv, s * 1.35, 0, TAU, 20, col, 1.5, true)
	Icons.draw(c, "moon" if night else "sun", pv, s * 0.8, col)
	if not up:
		hud._ctext(pv + Vector2(0, -s * 1.6), Lairs.clock(left), 10, Color.WHITE, hud.big)


static func _boss(hud, pv: Vector2, s: float, on_map: Callable, t: float) -> void:
	var dn: DayNight = hud.m.day_night
	if not on_map.call(pv, 4.0):
		return
	var c: Control = hud.c
	var up := dn.is_night(t) and dn.spawns.boss != null and not dn.spawns.boss.dead
	var col := DayNightSpawns.BOSS_COL if up else DIM
	c.draw_circle(pv, s * 1.35, Color(0, 0, 0, 0.7))
	c.draw_arc(pv, s * 1.35, 0, TAU, 20, col, 2.0, true)
	Icons.draw(c, "burst", pv, s * 0.9, col)
	if not dn.is_night(t):
		hud._ctext(
			pv + Vector2(0, -s * 1.6), Lairs.clock(dn.night_start(dn.next_night(t)) - t), 10, Color.WHITE, hud.big
		)
