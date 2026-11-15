class_name NestMap
extends RefCounted
## Blight nests (BlightNests) on the minimap and the full map, drawn like camps: an egg icon in a dark
## disc, one pip per Skitter it still holds. A stirring nest flashes; an empty or broken one greys out
## over its countdown to refilling. The minimap shows nests near you or stirring ("nest" in MapDetail;
## all of them while you hold the map key); the full map shows every one (their spots are fixed).
## (When ext/predictable-camps-1111 lands, fold _nest into CampMap._camp: docs/DEBT.md.)

const COL := Color("ff6a2a")  # BlightModels.EMBER
const DIM := Color(0.6, 0.62, 0.68, 0.6)
const NEAR_M := 40.0  # a nest this close matters (shows on the default minimap)
const ICON_S := 4.5  # px on the full map (the minimap uses MapDetail.ICON_R)


static func minimap(hud, to_map: Callable, on_map: Callable, hold: bool) -> void:
	var m: Match = hud.m
	if m.blight == null or m.player == null:
		return
	var nst: BlightNests = m.blight.nests
	for n in nst.list:
		var stir: bool = n["stir_at"] != INF
		if not MapDetail.shows("nest", hold, stir or m.player.flat_dist(n["pos"]) < NEAR_M):
			continue
		var pv: Vector2 = to_map.call(n["pos"])
		if on_map.call(pv, 4.0):
			_nest(hud, pv, MapDetail.ICON_R * 0.75, n, nst)


static func full_map(fm) -> void:
	var m: Match = fm.m
	if m.blight == null:
		return
	var area: Rect2 = fm.rect.grow(-4.0)
	for n in m.blight.nests.list:
		var pv: Vector2 = fm.to_screen(n["pos"])
		if area.has_point(pv):
			_nest(fm.hud, pv, ICON_S, n, m.blight.nests)


static func _nest(hud, pv: Vector2, s: float, n: Dictionary, nst: BlightNests) -> void:
	var c: Control = hud.c
	var cooling := nst.cooling(n)
	var col := DIM if cooling else COL
	if n["stir_at"] != INF and fmod(Time.get_ticks_msec() / 1000.0, 0.3) < 0.15:
		col = Color.WHITE
	c.draw_circle(pv, s * 1.35, Color(0, 0, 0, 0.7))
	c.draw_arc(pv, s * 1.35, 0, TAU, 20, col, 1.5, true)
	Icons.draw(c, "egg", pv, s * 0.8, col)
	var k := int(n["stock"])
	for i in k:
		c.draw_circle(pv + Vector2((i - (k - 1) * 0.5) * s * 0.45, s * 1.35 + 2.5), maxf(0.9, s * 0.14), col)
	if cooling:
		hud._ctext(pv + Vector2(0, -s * 1.6), Lairs.clock(nst.refill_left(n)), 10, Color.WHITE, hud.big)
