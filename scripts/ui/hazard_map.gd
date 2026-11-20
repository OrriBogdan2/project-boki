class_name HazardMap
extends RefCounted
## Terrain hazards (TerrainHazards) on the minimap and the full map, so a drop plan or a route can see
## them: each area's outline tinted by kind (colours from content/rules/terrain_hazards.json "look"),
## a shield on every area your carried Boki counters. The full map's key (MapKey) lists the kinds.

const NEAR_M := 20.0       # m: the minimap shows the hazards once you are this close to one (else on a hold)
const FILL_A := 0.5        # fill opacity over the painted map
const EDGE_A := 0.95       # outline opacity
const CASING := Color(0.02, 0.03, 0.06, 0.55)    # the dark line under an outline, so it reads on any island colour
const MM_SHIELD := 12.0    # px: the shield on the minimap
const FULL_SHIELD := 16.0  # px: the shield on the full map
const SAFE := Color("8fe3a0")

## The minimap's own reason to show the hazards: one lies within NEAR_M of you.
static func matters(m: Match) -> bool:
	var tz := TerrainHazards.of(m)
	if tz == null or m.player == null:
		return false
	var at := Vector2(m.player.pos.x, m.player.pos.z)
	return tz.areas.any(func(a): return (a["box"] as Rect2).grow(NEAR_M).has_point(at))

static func fill(kind: String) -> Color:
	var look: Dictionary = TerrainHazards.kind_def(kind)["look"]
	return Color(Color(String(look["deep"])).lerp(Color(String(look["edge"])), 0.3), FILL_A)

static func edge(kind: String) -> Color:
	return Color(Color(String(TerrainHazards.kind_def(kind)["look"]["edge"])), EDGE_A)

## `to_screen` maps a world point (Vector3) to the screen; `inner` is the square map, `circ` the round
## minimap's (centre x, y, radius; z = 0 for a square map). Areas are cut to what the map shows.
static func draw(c: Control, m: Match, to_screen: Callable, inner: Rect2, circ: Vector3, shield_px: float) -> void:
	var tz := TerrainHazards.of(m)
	if tz == null:
		return
	var clip := _clip(inner, circ)
	for a in tz.areas:
		var kind := String(a["kind"])
		var pts := PackedVector2Array()
		for p in a["poly"]:
			pts.append(to_screen.call(Vector3(p.x, 0.0, p.y)))
		for part in Geometry2D.intersect_polygons(pts, clip):
			if part.size() >= 3:
				c.draw_colored_polygon(part, fill(kind))
		for i in pts.size():
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if _inside(pts[i], inner, circ) and _inside(b, inner, circ):
				c.draw_line(pts[i], b, CASING, 3.5, true)
				c.draw_line(pts[i], b, edge(kind), 1.8, true)
		var mid: Vector2 = to_screen.call(a["centre"])
		if m.player and _inside(mid, inner, circ) and tz.guards(m.player, kind):
			c.draw_circle(mid, shield_px * 0.75, Color(0.03, 0.05, 0.08, 0.7))
			Icons.draw(c, "brightshield", mid, shield_px, SAFE)

static func _inside(p: Vector2, inner: Rect2, circ: Vector3) -> bool:
	if circ.z > 0.0:
		return p.distance_to(Vector2(circ.x, circ.y)) <= circ.z
	return inner.has_point(p)

static func _clip(inner: Rect2, circ: Vector3) -> PackedVector2Array:
	if circ.z <= 0.0:
		return PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end,
			Vector2(inner.position.x, inner.end.y)])
	var ring := PackedVector2Array()
	for i in 40:
		ring.append(Vector2(circ.x, circ.y) + Vector2.from_angle(TAU * i / 40.0) * circ.z)
	return ring
