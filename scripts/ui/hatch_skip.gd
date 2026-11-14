class_name HatchSkip
extends CanvasLayer
## The hatch beat plays about nine seconds with nothing to press. This watches it: any key or click
## jumps it to its end (the Boki revealed, its card up), and a small "Press any key" pill says so
## after PILL_AT seconds. Only the waiting is skipped; the caller frees this when the card is up.
##
##   add_child(HatchSkip.new(func(): ...jump to the end...))

const ARM_AT := 0.5  # s: a key counts from here on (the last knock's own key must not skip the egg)
const PILL_AT := 1.5  # s: when the "Press any key" pill fades in

var jump: Callable
var t := 0.0
var pill: PanelContainer


func _init(on_skip: Callable) -> void:
	jump = on_skip
	layer = 70


func _ready() -> void:
	pill = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.025, 0.05, 0.6)
	box.set_corner_radius_all(14)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", box)
	pill.add_child(UI.label("Press any key", 13, UI.MUTED))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	pill.offset_bottom = -14
	pill.offset_top = -44
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.modulate.a = 0.0
	add_child(pill)


func _process(dt: float) -> void:
	t += dt
	pill.modulate.a = clampf((t - PILL_AT) / 0.4, 0.0, 1.0)


func _input(ev: InputEvent) -> void:
	if t < ARM_AT or not _is_press(ev):
		return
	get_viewport().set_input_as_handled()
	jump.call()


func _is_press(ev: InputEvent) -> bool:
	if ev is InputEventKey:
		return ev.pressed and not ev.echo
	return (ev is InputEventMouseButton or ev is InputEventJoypadButton or ev is InputEventScreenTouch) and ev.pressed
