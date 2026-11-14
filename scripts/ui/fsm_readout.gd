class_name FsmReadout
extends Label
## The F7 readout for tuning: the local mover's speeds, cap and drag (Loco.report), then every live state
## machine (Fsm.live) with its state, the time in it, its refused count and its last transitions. F7 (the
## move_readout key) or Settings > Controls toggles it. While it shows, content/rules/tuning.json is re-read
## whenever it changes, so every knob tunes live.

const SHOWN := 3     # log lines listed per machine

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
	var lines := PackedStringArray()
	if Loco.r_fsm == null:
		lines.append("movement: nothing moving yet")
	else:
		lines.append("h %5.2f m/s   v %6.2f m/s   cap %.2f   drag %.2f/s"
			% [Loco.r_hs, Loco.r_vs, Loco.r_cap, Loco.drag_now()])
	for label in Fsm.live:
		var f: Fsm = (Fsm.live[label] as WeakRef).get_ref()
		if f == null:
			continue
		var refused := ("   refused %d" % f.refused) if f.refused > 0 else ""
		lines.append("%s: %s (%.2fs)%s" % [label, f.state_name(), f.since, refused])
		for i in range(maxi(0, f.history.size() - SHOWN), f.history.size()):
			lines.append("   " + f.history[i])
	text = "\n".join(lines)
