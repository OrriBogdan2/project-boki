class_name DuoTutorialHud
extends CanvasLayer
## What the 2v2 tutorial (DuoTutorial) shows: the guide's line in a bubble over her head (pinned to the
## screen edge when she is off it), one short tip pill at the top-centre with its key cap and count (it
## pulses when she nags, and ticks green when the beat lands), a row of dots for the beats, and the
## end card. Nothing covers the middle of the screen: the fight is the tutorial.

const INK := Color("f3eee2")
const MINT := Color("8fe3c8")
const PANEL := Color(0.03, 0.04, 0.07, 0.9)
const BUBBLE := Color(0.98, 0.96, 0.9, 0.96)
const BUBBLE_INK := Color(0.1, 0.09, 0.12)
const LINE_S := 4.5          # s a line stands over her head
const FADE_S := 0.4          # s it takes to fade
const TEXT_PX := 20
const TIP_PX := 22
const EDGE_PAD := 24.0       # px from the screen edge a pinned bubble keeps
const END_DELAY := 1.0       # s after the last line before the end card comes in

var tu: DuoTutorial
var font: Font = preload("res://fonts/Rubik.ttf")
var c: Control

func _init(owner_tut: DuoTutorial) -> void:
	tu = owner_tut
	layer = 5
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_all)
	add_child(c)

func _process(_dt: float) -> void:
	c.queue_redraw()

func _draw_all() -> void:
	var sz := c.get_viewport_rect().size
	if tu.finished and tu.end_t > END_DELAY:
		_end_card(sz)
		return
	_bubble(sz)
	if tu.gap_t <= 0.0 and not tu.cur().is_empty():
		_tip(sz)
	_dots(sz)

func _bubble(sz: Vector2) -> void:
	var a := clampf((LINE_S - tu.line_t) / FADE_S, 0.0, 1.0) * clampf(tu.line_t * 8.0, 0.0, 1.0)
	if a <= 0.0 or tu.line == "":
		return
	var at := tu.guide.pos + Vector3(0, 2.4, 0)
	var cam := tu.m.cam
	var sp := sz * Vector2(0.5, 0.75) if cam.is_position_behind(at) else cam.unproject_position(at)
	var txt := "%s: %s" % [tu.guide.pname, tu.line]
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX).x
	var w := tw + 28.0
	var on := Rect2(Vector2(EDGE_PAD, EDGE_PAD), sz - Vector2(EDGE_PAD, EDGE_PAD) * 2.0).has_point(sp)
	sp.x = clampf(sp.x, EDGE_PAD + w * 0.5, sz.x - EDGE_PAD - w * 0.5)
	sp.y = clampf(sp.y, EDGE_PAD + 60.0, sz.y - EDGE_PAD)
	var r := Rect2(sp + Vector2(-w * 0.5, -54.0), Vector2(w, 36.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BUBBLE, BUBBLE.a * a)
	sb.set_corner_radius_all(14)
	c.draw_style_box(sb, r)
	if on:
		var tail := PackedVector2Array([sp + Vector2(-8, -19), sp + Vector2(8, -19), sp + Vector2(0, -8)])
		c.draw_colored_polygon(tail, Color(BUBBLE, BUBBLE.a * a))
	var name_w := font.get_string_size(tu.guide.pname + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX).x
	var base := r.position + Vector2(14, 25)
	var name_col := Color(MINT.darkened(0.45), a)
	c.draw_string(font, base, tu.guide.pname + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX, name_col)
	c.draw_string(font, base + Vector2(name_w, 0), " " + tu.line, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX,
		Color(BUBBLE_INK, a))

## The tip pill: [key] what to do, and the count when the beat needs more than one.
func _tip(sz: Vector2) -> void:
	var b := tu.cur()
	var txt := tu.fill(String(b["tip"]))
	var need := int(b["need"])
	if need > 1:
		txt += "   %d/%d" % [tu.got, need]
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, TIP_PX).x
	var pulse := 1.0 + 0.06 * sin(tu.nagging * 18.0) if tu.nagging > 0.0 else 1.0
	var pill := Vector2(tw + 40.0, 46.0) * pulse
	var r := Rect2(Vector2((sz.x - pill.x) * 0.5, sz.y * 0.04), pill)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(23)
	sb.border_color = MINT if tu.nagging > 0.0 else Color(1, 1, 1, 0.1)
	sb.set_border_width_all(2)
	c.draw_style_box(sb, r)
	c.draw_string(font, r.position + Vector2(20, 31), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, TIP_PX, INK)

## One dot per beat under the tip: done ones filled, this one ringed.
func _dots(sz: Vector2) -> void:
	var n := tu.beats.size()
	var gap := 16.0
	var x0 := sz.x * 0.5 - (n - 1) * gap * 0.5
	for i in n:
		var at := Vector2(x0 + i * gap, sz.y * 0.04 + 62.0)
		if i < tu.beat or (i == tu.beat and tu.gap_t > 0.0) or tu.finished:
			c.draw_circle(at, 4.0, MINT)
		elif i == tu.beat:
			c.draw_arc(at, 5.0, 0.0, TAU, 16, MINT, 2.0, true)
		else:
			c.draw_circle(at, 3.0, Color(1, 1, 1, 0.3))

func _end_card(sz: Vector2) -> void:
	var a := clampf((tu.end_t - END_DELAY) * 2.0, 0.0, 1.0)
	var r := Rect2(sz * Vector2(0.32, 0.38), sz * Vector2(0.36, 0.2))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL, PANEL.a * a)
	sb.set_corner_radius_all(18)
	c.draw_style_box(sb, r)
	var title := "Sparring match won"
	var sub := "%s will see you out there." % tu.guide.pname
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, TIP_PX).x
	c.draw_string(font, r.position + Vector2((r.size.x - tw) * 0.5, r.size.y * 0.45), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(MINT, a))
	c.draw_string(font, r.position + Vector2((r.size.x - sw) * 0.5, r.size.y * 0.75), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TIP_PX, Color(INK, a))
