class_name TimingBar
extends RefCounted
## The timing bar of the Training post drill, shared with the Dash's cheers (scripts/home/base_race.gd):
## a marker sweeps back and forth over a bar; press while it is in the gold. Each press grades
## "great", "good" or "miss", then the marker speeds up and the gold moves.

const GREAT := 0.06          # bar widths from the gold's centre: a great press
const GOOD := 0.16           # bar widths from the gold's centre: a good press
const START_SPEED := 0.85    # bar widths a second at the first press
const SPEEDUP := 1.35        # each press, the marker sweeps this much faster
const WIDTH := 560.0         # px, the card's width on a wide screen

var m := 0.0                 # the marker, 0..1 along the bar
var dir := 1.0
var speed := START_SPEED
var zone := 0.5              # the gold's centre, 0..1
var card: Control = null
var lbl: Label = null
var canvas: Control = null

func _init() -> void:
	zone = randf_range(0.3, 0.7)

## The bar's card at the bottom of the screen, with a title line and the press hint under it.
func open(root: Control, hint: String) -> void:
	var bar := UI.card(Color(0.06, 0.07, 0.1, 0.92), 12, 14)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -64
	bar.offset_bottom = -64
	bar.custom_minimum_size.x = minf(WIDTH, root.get_viewport_rect().size.x - 32.0)
	var col := UI.vbox(8)
	bar.add_child(col)
	lbl = UI.label("", 15)
	col.add_child(lbl)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(0, 26)
	canvas.draw.connect(_draw)
	col.add_child(canvas)
	col.add_child(UI.label(hint, 12, UI.MUTED))
	root.add_child(bar)
	card = bar

func close() -> void:
	if is_instance_valid(card):
		card.queue_free()
	card = null

func step(d: float) -> void:
	m += dir * speed * d
	if m > 1.0:
		m = 2.0 - m
		dir = -1.0
	if m < 0.0:
		m = -m
		dir = 1.0
	if is_instance_valid(canvas):
		canvas.queue_redraw()

## Grades this press, then speeds the marker up and moves the gold.
func press() -> String:
	var off := absf(m - zone)
	var r := "miss"
	if off < GREAT:
		r = "great"
	elif off < GOOD:
		r = "good"
	speed *= SPEEDUP
	zone = randf_range(0.2, 0.8)
	return r

## A press on the bar: interact, jump or a left click.
static func is_press(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		return true
	var mb := event as InputEventMouseButton
	return mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT

func _draw() -> void:
	var w := canvas.size.x
	var h := canvas.size.y
	canvas.draw_rect(Rect2(0, h * 0.3, w, h * 0.4), Color(1, 1, 1, 0.1))
	canvas.draw_rect(Rect2(w * (zone - GOOD), h * 0.3, w * GOOD * 2.0, h * 0.4), Color(UI.ACCENT, 0.45))
	canvas.draw_rect(Rect2(w * (zone - GREAT), h * 0.2, w * GREAT * 2.0, h * 0.6), UI.GOLD)
	canvas.draw_rect(Rect2(w * m - 3, 0, 6, h), UI.INK)
