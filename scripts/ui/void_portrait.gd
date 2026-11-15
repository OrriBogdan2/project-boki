class_name VoidPortrait
extends Control
## The cracked-mask window of the "Void & Masks" look (UI_STYLE.md on ext/agent-briefs): a Boki over a
## deep starfield, a torn neon frame and teal cracks running in from the corners. The starfield and
## cracks are fixed per window size and drawn as canvas shapes, so it costs nothing per frame.

const STARS := 26                       # specks in the sky
const SKY_TOP := Color("0b0716")        # the void behind the creature, top...
const SKY_LOW := Color("2a1450")        # ...to violet at its feet
const CRACKS := [                       # polylines in 0..1 of the window: from a corner towards the middle
	[Vector2(0.0, 0.0), Vector2(0.14, 0.12), Vector2(0.12, 0.26), Vector2(0.26, 0.34)],
	[Vector2(1.0, 0.0), Vector2(0.84, 0.09), Vector2(0.88, 0.2)],
	[Vector2(1.0, 1.0), Vector2(0.86, 0.9), Vector2(0.9, 0.78), Vector2(0.78, 0.7)],
	[Vector2(0.0, 1.0), Vector2(0.12, 0.92), Vector2(0.1, 0.84)],
]

var _sky := UiTorn.make(SKY_TOP, 3.0)

## A window `px` square showing this Boki.
static func of(rec: Dictionary, tree: SceneTree, px := 96.0) -> VoidPortrait:
	var w := VoidPortrait.new()
	w.custom_minimum_size = Vector2(px, px)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pic := KinPortrait.view(rec, tree, px)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	w.add_child(pic)
	var top := Cracks.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(top)
	return w

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_sky, r)
	var low := Rect2(4.0, size.y * 0.5, size.x - 8.0, size.y * 0.5 - 4.0)
	draw_rect(low, Color(SKY_LOW, 0.55))
	for i in STARS:
		var h := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(float(i) * 78.233) * 12345.6789, 1.0)
		var at := Vector2(6.0 + h * (size.x - 12.0), 6.0 + h2 * (size.y - 12.0))
		draw_circle(at, 0.7 + h2 * 0.9, Color(0.85, 0.8, 1.0, 0.35 + 0.5 * h))

## The frame and the teal cracks, over the creature.
class Cracks extends Control:
	var frame := UiTorn.make(Color(0, 0, 0, 0), 3.0, 1.0)
	func _draw() -> void:
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
		for c in VoidPortrait.CRACKS:
			var line := PackedVector2Array()
			for p in c:
				line.append(p * size)
			draw_polyline(line, Color(UI.TEAL, 0.9), 1.4, true)
