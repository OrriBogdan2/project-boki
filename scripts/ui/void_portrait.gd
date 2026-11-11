class_name VoidPortrait
extends Control
## The cracked-mask window of the "Void & Masks" look (UI_STYLE.md on ext/agent-briefs): a Boki over a
## deep starfield with a violet nebula, a torn neon frame and cracks running in from the corners,
## dark with a teal glint. The sky and cracks are fixed per window size and drawn as canvas shapes,
## so it costs nothing per frame. `of` shows a Boki's portrait picture; `window` wraps any control
## (the reveal's live 3D view).

const STAR_PER_PX2 := 1.0 / 900.0       # stars per square px of window
const SKY_TOP := Color("0b0716")        # the void behind the creature, top...
const SKY_LOW := Color("2a1450")        # ...to violet at its feet
const NEBULA := [Color(0.5, 0.2, 0.8, 0.1), Color(0.9, 0.25, 0.7, 0.07), Color(0.25, 0.7, 0.8, 0.06)]
const CRACKS := [                       # polylines in 0..1 of the window: from an edge towards the middle
	[Vector2(0.0, 0.0), Vector2(0.14, 0.12), Vector2(0.12, 0.26), Vector2(0.26, 0.34)],
	[Vector2(1.0, 0.0), Vector2(0.84, 0.09), Vector2(0.88, 0.2), Vector2(0.78, 0.26)],
	[Vector2(1.0, 1.0), Vector2(0.86, 0.9), Vector2(0.9, 0.78), Vector2(0.78, 0.7)],
	[Vector2(0.0, 1.0), Vector2(0.12, 0.92), Vector2(0.1, 0.84), Vector2(0.2, 0.76)],
	[Vector2(0.0, 0.55), Vector2(0.1, 0.5), Vector2(0.16, 0.56)],
	[Vector2(1.0, 0.42), Vector2(0.9, 0.47), Vector2(0.86, 0.4)],
]

var _sky := UiTorn.make(SKY_TOP, 4.0)

## A window `px` square showing this Boki's portrait.
static func of(rec: Dictionary, tree: SceneTree, px := 96.0) -> VoidPortrait:
	var pic := KinPortrait.view(rec, tree, px)
	return window(pic, Vector2(px, px))

## A window this big with `content` inside it (under the cracks and the frame).
static func window(content: Control, px: Vector2) -> VoidPortrait:
	var w := VoidPortrait.new()
	w.custom_minimum_size = px
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	w.add_child(content)
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
	for i in NEBULA.size():
		var at := Vector2(size.x * (0.25 + 0.5 * _h(i + 40)), size.y * (0.2 + 0.6 * _h(i + 50)))
		var rad := minf(size.x, size.y) * (0.22 + 0.2 * _h(i + 60))
		for ring in 3:
			draw_circle(at, rad * (1.0 - 0.28 * ring), NEBULA[i])
	var stars := mini(160, int(size.x * size.y * STAR_PER_PX2))
	for i in stars:
		var h := _h(i)
		var h2 := _h(i + 1000)
		var at := Vector2(6.0 + h * (size.x - 12.0), 6.0 + h2 * (size.y - 12.0))
		var rad := 0.6 + 1.3 * pow(h2, 3.0)
		draw_circle(at, rad, Color(0.88, 0.84, 1.0, 0.3 + 0.6 * h))
		if h > 0.92:
			draw_circle(at, rad * 3.0, Color(0.7, 0.8, 1.0, 0.12))

## A stable pseudo-random number in 0..1 for an integer key.
static func _h(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + 1.7) * 43758.5453, 1.0)

## The frame and the cracks, over the creature: a dark crack with a teal glint along one side.
class Cracks extends Control:
	var frame := UiTorn.make(Color(0, 0, 0, 0), 4.0, 1.2)
	func _init() -> void:
		frame.glow_w = 1.4
	func _draw() -> void:
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
		for c in VoidPortrait.CRACKS:
			var line := PackedVector2Array()
			for p in c:
				line.append(p * size)
			draw_polyline(line, Color(0, 0, 0.02, 0.75), 3.0, true)
			var lit := PackedVector2Array()
			for p in line:
				lit.append(p + Vector2(1.2, -1.2))
			draw_polyline(lit, Color(UI.TEAL, 0.85), 1.3, true)
