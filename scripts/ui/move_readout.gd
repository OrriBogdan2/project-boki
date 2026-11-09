class_name MoveReadout
extends Label
## The movement readout for tuning: horizontal and vertical speed, the locomotion state and its
## last transitions, the cap and the drag, for whoever moves locally (farm avatar or match hunter, via
## Loco.report). F7 (the move_readout key) or Settings > Controls toggles it. While it shows,
## content/rules/tuning.json is re-read whenever it changes, so every knob tunes live.

var _poll_t := 0.0

func _ready() -> void:
	position = Vector2(12, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)
	visible = bool(Settings.get_v("move_readout"))

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_readout"):
		Settings.set_v("move_readout", not bool(Settings.get_v("move_readout")))

func _process(dt: float) -> void:
	visible = bool(Settings.get_v("move_readout"))
	if not visible:
		return
	_poll_t -= dt
	if _poll_t <= 0.0:
		_poll_t = float(Loco.T.get("poll_s", 0.5))
		Loco.poll()
	var f := Loco.r_fsm
	if f == null:
		text = "movement: nothing moving yet"
		return
	text = "h %5.2f m/s   v %6.2f m/s\nstate %s (%.2fs)   cap %.2f   drag %.2f/s\n%s%s" % [Loco.r_hs, Loco.r_vs,
		f.state_name(), f.since, Loco.r_cap, Loco.drag_now(), " ".join(f.history),
		("   refused %d" % f.refused) if f.refused > 0 else ""]
