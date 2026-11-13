class_name StripView
extends Control
## TutorialStrip as a Control, for the screens that are built from nodes (the farm). Full-screen and
## click-through; it draws the same one-line strip the match HUD draws (TutorialStrip.paint), pulsing for
## PULSE_T whenever set_line() gets a new objective key, and calm after.

var line := {}
var key := ""
var age := 99.0
var font: Font = preload("res://fonts/LilitaOne-Regular.ttf")
var _drawn := ""

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The line to show; `objective` is the step's identity: a new one restarts the glow and the pulse.
func set_line(l: Dictionary, objective: String) -> void:
	line = l
	if objective != key:
		key = objective
		age = 0.0
		TutorialStrip.chime()
	queue_redraw()

func rect() -> Rect2:
	return TutorialStrip.shown(size, age)

func _process(dt: float) -> void:
	if age < TutorialStrip.PULSE_T + 0.1:
		age += dt
		queue_redraw()

func _draw() -> void:
	if not line.is_empty():
		TutorialStrip.paint(self, font, rect(), line, age)
