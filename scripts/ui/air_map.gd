class_name AirMap
extends RefCounted
## Air rings on the full map and the minimap (docs/AIR_RINGS.md): each air lane as a dashed cyan line
## with a tick at every ring, each lift ring as a gold circle with an up chevron. On the minimap they are
## a DETAIL kind ("air"): shown while you hold the map keys or ride in.

const DASH_M := 3.0     # m: dash and gap of a lane line, in the world (dashes outside the map are left out)

## The rings on the full map (FullMap).
static func full_map(fm) -> void:
	var m: Match = fm.m
	if m.air_rings == null:
		return
	var area: Rect2 = fm.rect.grow(-4.0)
	_draw(fm.hud.c, m.air_rings, fm.to_screen, func(pv: Vector2) -> bool: return area.has_point(pv), 2.0, 7.0)

## The rings on the minimap; `to_map` and `on_map` are the minimap's own.
static func minimap(hud, to_map: Callable, on_map: Callable, hold: bool) -> void:
	var m: Match = hud.m
	if m.air_rings == null or not MapDetail.shows("air", hold):
		return
	_draw(hud.c, m.air_rings, to_map, func(pv: Vector2) -> bool: return on_map.call(pv, 3.0), 1.5, 4.0)

static func _draw(c: Control, air: AirRings, to_px: Callable, inside: Callable, width: float, glyph_r: float) -> void:
	var lane_col := Color(AirRings.GLIDE_COL, 0.8)
	for ln in air.lanes:
		var a: Vector3 = ln["a"]
		var b: Vector3 = ln["b"]
		var dashes := int(a.distance_to(b) / DASH_M)
		for k in range(0, dashes, 2):
			var p0: Vector2 = to_px.call(a.lerp(b, float(k) / dashes))
			var p1: Vector2 = to_px.call(a.lerp(b, float(k + 1) / dashes))
			if inside.call(p0) and inside.call(p1):
				c.draw_line(p0, p1, lane_col, width, true)
	for rg in air.list:
		var pv: Vector2 = to_px.call(rg["pos"])
		if not inside.call(pv):
			continue
		if rg["lift"]:
			lift_glyph(c, pv, glyph_r)
		else:
			var d: Vector2 = rg["dir"]
			var across := Vector2(-d.y, d.x) * glyph_r * 0.7
			c.draw_line(pv - across, pv + across, AirRings.GLIDE_COL, width + 1.0, true)

## A lift ring: a gold ring with a chevron pointing up.
static func lift_glyph(c: Control, pv: Vector2, s: float) -> void:
	c.draw_circle(pv, s, Color(0, 0, 0, 0.45))
	c.draw_arc(pv, s, 0.0, TAU, 20, AirRings.LIFT_COL, maxf(1.5, s * 0.25), true)
	var tip := pv + Vector2(0, -s * 0.5)
	c.draw_polyline([pv + Vector2(-s * 0.45, s * 0.2), tip, pv + Vector2(s * 0.45, s * 0.2)], AirRings.LIFT_COL,
		maxf(1.5, s * 0.22), true)
