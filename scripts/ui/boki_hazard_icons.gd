class_name BokiHazardIcons
extends RefCounted
## On the Boki box (GripHud): one small hazard icon in each bottom corner for each Boki you carry that counters a
## hazard on this map (TerrainHazards, content/rules/terrain_hazards.json): the lead on the left, the second on the
## right. Dim until you stand in that hazard, then lit in the hazard's colour. No text. Nothing off a hazard map, and
## no icon for a Boki that counters nothing here (a solo run with no second Boki shows at most one).

const INSET := 8.0           # px: an icon's centre this far in from the box's corner
const RAD := 7.0             # px: the icon's dark disc
const DIM := 0.4             # alpha of an icon you are not standing in

static func draw(H, p: Hunter, r: Rect2) -> void:
	var tz := TerrainHazards.of(H.m)
	if tz == null:
		return
	var shown := view(tz, p)
	for i in shown.size():
		var kind: String = shown[i][0]
		if kind == "":
			continue
		var lit: bool = shown[i][1]
		var at := Vector2(r.position.x + INSET if i == 0 else r.end.x - INSET, r.end.y - INSET)
		var col := Color(String(TerrainHazards.kind_def(kind)["look"]["edge"]))
		H.c.draw_circle(at, RAD, Color(0.03, 0.03, 0.05, 0.92))
		if lit:
			H.c.draw_arc(at, RAD + 1.0, 0, TAU, 20, Color(col, 0.6 + 0.4 * sin(float(H.m.time) * 6.0)), 2.0, true)
		glyph(H.c, kind, at, RAD * 0.62, Color(col, 1.0 if lit else DIM))

## What the box shows: for the lead then the second, [hazard kind or "", lit].
static func view(tz: TerrainHazards, p: Hunter) -> Array:
	var here := tz.kind_under(p)
	var out: Array = []
	for k in [p.kin, p.kin2]:
		var kind := icon_kind(tz, k, here)
		out.append([kind, kind != "" and kind == here and (k as Kin).state != "downed"])
	return out

## The hazard this Boki counters on the map, "" for none (the one you stand in if it counters several).
static func icon_kind(tz: TerrainHazards, k: Kin, here: String) -> String:
	if k == null or not is_instance_valid(k) or k.dead:
		return ""
	if here != "" and TerrainHazards.counters(k, here):
		return here
	for kind in tz.kinds:
		if TerrainHazards.counters(k, kind):
			return kind
	return ""

## A hazard's mark in a -1..1 box scaled by s: flame, drop, snowflake, bolt, thorns.
static func glyph(c: Control, kind: String, at: Vector2, s: float, col: Color) -> void:
	var P := func(pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in pts:
			out.append(at + Vector2(q[0], q[1]) * s)
		return out
	var w := maxf(1.2, s * 0.3)
	match kind:
		"lava":
			c.draw_colored_polygon(P.call([[0, -1], [0.7, 0.1], [0.6, 0.7], [0, 1], [-0.6, 0.7], [-0.7, 0.1]]), col)
		"deep_water":
			c.draw_colored_polygon(P.call([[0, -1], [0.65, 0.3], [0.4, 0.85], [-0.4, 0.85], [-0.65, 0.3]]), col)
		"ice":
			for a in 3:
				var d := Vector2.from_angle(PI / 3.0 * a) * s
				c.draw_line(at - d, at + d, col, w, true)
		"static":
			c.draw_polyline(P.call([[0.4, -1], [-0.4, 0.1], [0.3, 0.1], [-0.4, 1]]), col, w, true)
		_:
			for x in [-0.6, 0.0, 0.6]:
				c.draw_colored_polygon(P.call([[x - 0.3, 0.9], [x + 0.3, 0.9], [x, -0.9 + absf(x) * 0.6]]), col)
