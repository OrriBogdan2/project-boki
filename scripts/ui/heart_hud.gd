class_name HeartHud
extends RefCounted
## The Heart on screen (docs/decisions/0023), for the Hud and the FullMap, the same for every player:
##   - the Heart's marker with a charge ring on the minimap and the full map, and a waypoint in the world;
##   - the carrier's glyph on every map (revealed) with their name, and a waypoint over them;
##   - the Heart Gate (dim until the Heartspark is carried, then lit);
##   - the Blight's tide ring closing on the Heart.

const TIDE_COL := Color(0.75, 0.2, 0.35, 0.8)

# ------------------------------------------------------------------ the world
static func world_labels(hud) -> void:
	var m: Match = hud.m
	var ht: Heart = m.heart
	if ht == null or m.player == null or ht.site == Vector3.INF:
		return
	var cam: Camera3D = m.cam
	match ht.state:
		"charging":
			hud._draw_waypoint(ht.site + Vector3(0, 1.0, 0), _word(ht), Heart.COL)
		"ready":
			hud._draw_waypoint(ht.spark_pos + Vector3(0, 1.0, 0), "Heartspark", Heart.COL)
		"carried":
			if ht.carrier and ht.carrier != m.player:
				var who := "%s has the Heartspark" % ht.carrier.pname
				hud._draw_waypoint(ht.carrier.pos + Vector3(0, 1.0, 0), who, Heart.COL)
			elif ht.carrier == m.player:
				hud._draw_waypoint(ht.gate + Vector3(0, 1.0, 0), "Heart Gate", Heart.GATE_COL)
		"cooling":
			if m.player.flat_dist(ht.site) < 40.0 and not cam.is_position_behind(ht.site):
				var cp := cam.unproject_position(ht.site + Vector3(0, 3.8, 0))
				hud._ctext(cp, "Cooling  %ds" % int(ceil(ht.cool)), 13, Heart.COL, hud.big)
	if ht.state != "carried" and ht.state != "cooling" and m.player.flat_dist(ht.site) < 30.0:
		var gp := cam.unproject_position(ht.gate + Vector3(0, 3.6, 0))
		if m.player.flat_dist(ht.gate) < 30.0 and not cam.is_position_behind(ht.gate):
			hud._ctext(gp, "Heart Gate", 12, Heart.GATE_COL.darkened(0.2), hud.big)
	if ht.state == "carried" and ht.carrier == m.player:
		var cp2 := cam.unproject_position(m.player.pos + Vector3(0, 3.4, 0))
		hud._ctext(cp2, "You carry the Heartspark  ·  everyone sees you", 13, Heart.COL, hud.big)

# ------------------------------------------------------------------ the maps
static func minimap(hud, inner: Rect2, to_map: Callable, on_map: Callable) -> void:
	var m: Match = hud.m
	var ht: Heart = m.heart
	if ht == null or ht.site == Vector3.INF:
		return
	_tide(hud.c, m, to_map, on_map, 1.5)
	var gv: Vector2 = to_map.call(ht.gate)
	if on_map.call(gv, 4.0):
		gate_glyph(hud.c, gv, 4.0, ht.state == "carried")
	var hv: Vector2 = to_map.call(ht.site)
	if on_map.call(hv, 4.0):
		heart_glyph(hud.c, hv, 5.0, ht, m.time)
	else:
		hud._edge_arrow(inner, inner.get_center(), hv, Heart.COL)
	if ht.state == "carried" and ht.carrier:
		var cv: Vector2 = to_map.call(ht.carrier.pos)
		if on_map.call(cv, 4.0):
			spark_glyph(hud.c, cv, 4.0, m.time)
		else:
			hud._edge_arrow(inner, inner.get_center(), cv, Heart.COL)

static func full_map(fm) -> void:
	var m: Match = fm.m
	var ht: Heart = m.heart
	if ht == null or ht.site == Vector3.INF:
		return
	var area: Rect2 = fm.rect.grow(-4.0)
	var c: Control = fm.hud.c
	_tide(c, m, fm.to_screen, func(pv: Vector2, pad: float) -> bool: return area.grow(-pad).has_point(pv), 2.5)
	var gv: Vector2 = fm.to_screen(ht.gate)
	if area.has_point(gv):
		gate_glyph(c, gv, 7.0, ht.state == "carried")
		fm.hud._ctext(gv + Vector2(0, 18), "Heart Gate", 11, Heart.GATE_COL, fm.hud.big)
	var hv: Vector2 = fm.to_screen(ht.site)
	if area.has_point(hv):
		heart_glyph(c, hv, 9.0, ht, m.time)
		fm.hud._ctext(hv + Vector2(0, -20), _word(ht), 12, Heart.COL, fm.hud.big)
	if ht.state == "carried" and ht.carrier:
		var cv: Vector2 = fm.to_screen(ht.carrier.pos)
		if area.has_point(cv):
			spark_glyph(c, cv, 7.0, m.time)
			fm.hud._ctext(cv + Vector2(0, -16), "%s  ·  Heartspark" % ht.carrier.pname, 12, Heart.COL, fm.hud.big)

static func _word(ht: Heart) -> String:
	match ht.state:
		"charging":
			return "Heart  %d%%" % int(ht.charge / Heart.r("charge_s") * 100.0)
		"ready":
			return "Heartspark ready"
		"cooling":
			return "Cooling  %ds" % int(ceil(ht.cool))
	return "Heart"

## The tide ring: short segments of the circle that fall on the map.
static func _tide(c: Control, m: Match, to_map: Callable, on_map: Callable, width: float) -> void:
	var tr := Heart.tide_r(m)
	if tr <= 0.0:
		return
	var ctr: Vector3 = m.heart.site
	var n := 96
	var prev := Vector2.INF
	for i in n + 1:
		var a := TAU * i / n
		var pv: Vector2 = to_map.call(ctr + Vector3(cos(a), 0, sin(a)) * tr)
		var inside: bool = on_map.call(pv, 2.0)
		if inside and prev != Vector2.INF:
			c.draw_line(prev, pv, TIDE_COL, width, true)
		prev = pv if inside else Vector2.INF

## The Heart on a map: a crimson heart-gem with a charge ring; lit and pulsing when the spark is ready.
static func heart_glyph(c: Control, pv: Vector2, s: float, ht: Heart, now: float) -> void:
	var f := clampf(ht.charge / Heart.r("charge_s"), 0.0, 1.0) if ht.state != "cooling" else 0.0
	if ht.state == "ready":
		var ph := fmod(now * 1.1, 1.0)
		c.draw_arc(pv, s + 2.0 + ph * s * 3.0, 0, TAU, 28, Color(Heart.COL, 1.0 - ph), 2.0, true)
	c.draw_arc(pv, s + 3.0, 0, TAU, 28, Color(0, 0, 0, 0.55), 3.0, true)
	if f > 0.0:
		c.draw_arc(pv, s + 3.0, -PI * 0.5, -PI * 0.5 + TAU * f, 28, Heart.COL, 3.0, true)
	var body := Heart.GLASS if ht.state != "cooling" else Heart.GLASS.darkened(0.5)
	var pts := PackedVector2Array([pv + Vector2(0, s * 1.2), pv + Vector2(-s * 1.1, -s * 0.1),
		pv + Vector2(-s * 0.55, -s * 0.9),
		pv + Vector2(0, -s * 0.4), pv + Vector2(s * 0.55, -s * 0.9), pv + Vector2(s * 1.1, -s * 0.1)])
	c.draw_colored_polygon(pts, body)
	c.draw_circle(pv + Vector2(-s * 0.2, -s * 0.2), s * 0.28, Color(1, 0.8, 0.85, 0.7))

## The carrier on a map: a bright mote with a pulse.
static func spark_glyph(c: Control, pv: Vector2, s: float, now: float) -> void:
	var ph := fmod(now * 1.6, 1.0)
	c.draw_arc(pv, s + 2.0 + ph * s * 2.5, 0, TAU, 24, Color(Heart.COL, 1.0 - ph), 2.0, true)
	c.draw_circle(pv, s + 1.5, Color(0, 0, 0, 0.6))
	c.draw_circle(pv, s, Heart.COL)
	c.draw_circle(pv, s * 0.45, Color("ffe6ea"))

## The Heart Gate on a map: two posts and a bar, dim until it's open.
static func gate_glyph(c: Control, pv: Vector2, s: float, open: bool) -> void:
	var col := Heart.GATE_COL if open else Heart.GATE_COL.darkened(0.5)
	c.draw_rect(Rect2(pv + Vector2(-s, -s), Vector2(s * 0.45, s * 2.0)), col)
	c.draw_rect(Rect2(pv + Vector2(s * 0.55, -s), Vector2(s * 0.45, s * 2.0)), col)
	c.draw_line(pv + Vector2(-s, -s), pv + Vector2(s, -s), col, 2.0)
	if open:
		c.draw_arc(pv, s * 1.6, 0, TAU, 24, Color(col, 0.7), 1.5, true)
