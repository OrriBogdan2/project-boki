class_name FarmIcon
extends Control
## The little pictures for the farm's build materials, drawn with shapes (no art files): gems, wood,
## stone, Ember Coals and fibre. cost_row() lays a price out as icons with counts, red when the
## farm is short of that one. Used by the build bar and the upgrade panel.

const COLS := {"gems": Color("6fd3ff"), "wood": Color("b9824f"), "stone": Color("a9a39a"), "coals": Color("ff8a3a"), "fibre": Color("8fd16a")}

var mat := "wood"
var short := false

func _init(m := "wood", px := 16.0) -> void:
	mat = m
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var s := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var edge := Color(0, 0, 0, 0.5)
	match mat:
		"gems":
			var pts := PackedVector2Array([c + Vector2(0, -0.95) * s, c + Vector2(0.85, -0.2) * s, c + Vector2(0, 0.95) * s, c + Vector2(-0.85, -0.2) * s])
			draw_colored_polygon(pts, COLS["gems"])
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.95) * s, c + Vector2(0.85, -0.2) * s, c + Vector2(0, -0.2) * s]), COLS["gems"].lightened(0.35))
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), edge, 1.0, true)
		"wood":
			draw_circle(c, 0.9 * s, Color("8a5a35"))
			draw_circle(c, 0.7 * s, COLS["wood"].lightened(0.2))
			draw_arc(c, 0.45 * s, 0, TAU, 14, Color("8a5a35"), 1.0, true)
			draw_arc(c, 0.2 * s, 0, TAU, 10, Color("8a5a35"), 1.0, true)
		"stone":
			var pts2 := PackedVector2Array([c + Vector2(-0.9, 0.5) * s, c + Vector2(-0.6, -0.45) * s, c + Vector2(0.05, -0.85) * s, c + Vector2(0.8, -0.35) * s, c + Vector2(0.9, 0.5) * s])
			draw_colored_polygon(pts2, COLS["stone"])
			draw_colored_polygon(PackedVector2Array([pts2[1], pts2[2], c + Vector2(0.1, -0.1) * s, c + Vector2(-0.4, 0.15) * s]), COLS["stone"].lightened(0.3))
			draw_polyline(PackedVector2Array([pts2[0], pts2[1], pts2[2], pts2[3], pts2[4], pts2[0]]), edge, 1.0, true)
		"coals":
			draw_circle(c + Vector2(0, 0.1) * s, 0.8 * s, Color("3a3340"))
			draw_circle(c + Vector2(-0.25, 0.0) * s, 0.22 * s, COLS["coals"])
			draw_circle(c + Vector2(0.28, 0.25) * s, 0.18 * s, Color("ffc15a"))
			draw_circle(c + Vector2(0.05, -0.35) * s, 0.14 * s, COLS["coals"])
		"fibre":
			for i in 3:
				var o := (i - 1) * 0.45
				draw_arc(c + Vector2(o * s, 0.95 * s), 1.5 * s, PI * (1.18 - o * 0.25), PI * (1.4 - o * 0.25), 8, COLS["fibre"], maxf(1.5, s * 0.34), true)

## A price as a row of icon + count ("6" next to a log). have: show red for what is short.
static func cost_row(cost: Dictionary, px := 14.0, fs := 12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for m in FarmSites.MATS:
		var n := int(cost.get(m, 0))
		if n <= 0: continue
		var lack := n > FarmSites.have(m)
		var ic := FarmIcon.new(m, px)
		ic.short = lack
		row.add_child(ic)
		var l := Label.new()
		l.text = str(n)
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", Color("ff9a8a") if lack else Color("a6f0b0"))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
	return row
