class_name CampMap
extends RefCounted
## How camps look on the maps (docs/decisions/0048-camps-and-xp.md): a campfire with 1, 2 or 3 flames
## for Small Camp, Camp and Great Camp, a small crown on a Camp Chief, and the one-line texts the drop
## map shows. The markers themselves are SpawnPlan's "camp" category, drawn by FullMap and the minimap.

const FLAME := Color("ffb24a")
const HOT_LABEL := "HOT: bigger camps, better loot"
const LEGEND_ROW := "Camps: clear them to level up"
const SHAPES := {"small": "camp1", "camp": "camp2", "great": "camp3", "chief": "camp4"}

static func is_shape(shape: String) -> bool:
	return shape.begins_with("camp") and shape.length() == 5

## A camp's marker shape from its size id (Camps.list()).
static func shape_of(size_id: String) -> String:
	return SHAPES.get(size_id, "camp2")

## The drop map's line under a region's name: "3 camps: to level 4".
static func region_line(camps: int, xp: float) -> String:
	return "%d camp%s: to level %d" % [camps, "" if camps == 1 else "s", level_for(xp)]

## The level that this much XP, from a fresh start, reaches.
static func level_for(xp: float) -> int:
	var lvl := 1
	for i in range(1, Hunter.XP_TO.size()):
		if xp >= float(Hunter.XP_TO[i]):
			lvl = i + 1
	return lvl

## One camp icon (shape "camp1".."camp4"): logs, 1 to 3 flames, a crown over the fire for a Chief.
static func icon(c: Control, shape: String, p: Vector2, s: float, col: Color) -> void:
	var flames := mini(int(shape.substr(4)), 3)
	c.draw_line(p + Vector2(-s, s * 0.8), p + Vector2(s, s * 0.35), Color(col, 0.8), maxf(1.5, s * 0.3))
	c.draw_line(p + Vector2(s, s * 0.8), p + Vector2(-s, s * 0.35), Color(col, 0.8), maxf(1.5, s * 0.3))
	for i in flames:
		var x := (i - (flames - 1) * 0.5) * s * 0.85
		var h := s * (1.0 if flames == 1 or i == (flames - 1) / 2 else 0.7)
		var base := p + Vector2(x, s * 0.4)
		c.draw_colored_polygon(PackedVector2Array([
			base + Vector2(-s * 0.4, 0), base + Vector2(0, -h * 1.5), base + Vector2(s * 0.4, 0)]), col)
	if shape == "camp4":
		var t := p + Vector2(0, -s * 1.25)
		var pts := PackedVector2Array()
		for v: Vector2 in [Vector2(-0.6, 0.35), Vector2(-0.6, -0.3), Vector2(-0.3, 0), Vector2(0, -0.45),
				Vector2(0.3, 0), Vector2(0.6, -0.3), Vector2(0.6, 0.35)]:
			pts.append(t + v * s)
		c.draw_colored_polygon(pts, Color("fff0b0"))

## A ring that fills as a cleared camp's comeback nears (frac 0..1).
static func comeback_ring(c: Control, p: Vector2, s: float, frac: float) -> void:
	c.draw_arc(p, s * 1.75, -PI * 0.5, -PI * 0.5 + TAU * clampf(frac, 0.0, 1.0), 28, Color(FLAME, 0.9), 2.5, true)

## The pulse on the one camp the first-match guide points at.
static func pulse(c: Control, p: Vector2, s: float) -> void:
	var ph := fmod(Time.get_ticks_msec() / 1000.0 * 1.2, 1.0)
	c.draw_arc(p, s * (1.6 + ph * 1.6), 0, TAU, 32, Color("8fe3c8", 0.9 * (1.0 - ph)), 3.0, true)
