class_name UiMotion
extends RefCounted
## The menus' motion, in one place so it stays quick and consistent: panels slide up as they fade
## in, buttons dip when pressed and spring back, the picked tab's underline glides to the new tab,
## switch knobs ease across, toasts slide and fade. Nothing changes a control's layout size (hover
## never resizes: only modulate, scale about the centre and a draw offset move). With Settings >
## Accessibility > Fewer flashes on, everything just fades or snaps (calm()).

const OPEN_S := 0.2          # a panel's slide in
const FADE_S := 0.14         # its fade (and the whole open when calm)
const SLIDE_PX := 18.0       # how far below its place a panel starts
const PRESS_S := 0.06        # a button dipping under the finger
const SPRING_S := 0.24       # ... and springing back past its size, then settling
const GLIDE_S := 0.22        # the tab underline moving to the picked tab
const KNOB_S := 0.18         # a switch knob crossing its track
const TOAST_HOLD_S := 2.2

static var _glide_at := {}   # tab row key -> Vector2(x, width) where its underline last sat

## True when motion should be kept to fades (the "Fewer flashes" setting).
static func calm() -> bool:
	return bool(Settings.get_v("reduce_flashes"))

## Opens a control: it fades in and slides up into place (just fades when calm). Works inside
## containers: the offset is re-applied after every re-layout until the slide is done.
static func open(c: Control, delay := 0.0) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, FADE_S).set_delay(delay)
	if calm():
		return
	slide(c, SLIDE_PX, 0.0, OPEN_S, delay)

## Moves `c` by a vertical draw offset from `from_px` to `to_px` (0 is its laid-out place).
static func slide(c: Control, from_px: float, to_px: float, secs: float, delay := 0.0) -> Tween:
	var st := {"off": 0.0}
	var shift := func(px: float) -> void:
		if not is_instance_valid(c):
			return
		c.position.y += px - float(st["off"])
		st["off"] = px
	shift.call(from_px)
	var par := c.get_parent()
	if par is Container:
		# a re-layout puts the control back in its place; keep the offset on top of it
		var again := func() -> void:
			if is_instance_valid(c):
				c.position.y += float(st["off"])
		(par as Container).sort_children.connect(again)
		c.tree_exiting.connect(func():
			if is_instance_valid(par) and (par as Container).sort_children.is_connected(again):
				(par as Container).sort_children.disconnect(again), CONNECT_ONE_SHOT)
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(shift, from_px, to_px, secs).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	return tw

## A button dips when pressed and springs back with a small overshoot on release (scaled about its
## centre, so its layout size never changes).
static func press(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	var to := func(s: float, secs: float, spring: bool) -> void:
		if not is_instance_valid(b) or not b.is_inside_tree() or calm():
			return
		var tw := b.create_tween()
		var step := tw.tween_property(b, "scale", Vector2(s, s), secs)
		if spring:
			step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	b.button_down.connect(func(): if not b.disabled: to.call(0.95, PRESS_S, false))
	b.button_up.connect(func(): to.call(1.0, SPRING_S, true))
	b.mouse_exited.connect(func(): if b.scale != Vector2.ONE: to.call(1.0, 0.1, false))

## The picked tab's underline in `col`, drawn over the track. When the row was just showing another
## tab (the panel rebuilds on a switch), it glides from there to `on_btn`. `key` names the row.
static func glide(track: Control, on_btn: Control, key: String, col: Color) -> void:
	var line := Control.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(line)
	var st := {"t": 1.0, "from": _glide_at.get(key, Vector2(-1, 0))}
	line.draw.connect(func():
		var to := Vector2(on_btn.global_position.x - line.global_position.x, on_btn.size.x)
		var t := float(st["t"])
		var from: Vector2 = st["from"]
		var at := to if t >= 1.0 or from.x < 0.0 else from.lerp(to, t)
		if t >= 1.0:
			_glide_at[key] = to
		var r := Rect2(at.x + 12.0, line.size.y - 3.0, maxf(4.0, at.y - 24.0), 3.0)
		line.draw_style_box(UI.bar_box(col, 2), r))
	on_btn.resized.connect(line.queue_redraw)
	if calm() or (st["from"] as Vector2).x < 0.0:
		return
	st["t"] = 0.0
	var tw := line.create_tween()
	tw.tween_method(func(x: float):
		st["t"] = x
		line.queue_redraw(), 0.0, 1.0, GLIDE_S).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

## A CheckButton whose knob eases across its track when flipped (the theme's track icons carry no
## knob; this draws it). Returns the button.
static func knob(cb: CheckButton) -> CheckButton:
	var st := {"t": 1.0 if cb.button_pressed else 0.0}
	cb.toggled.connect(func(on: bool):
		var goal := 1.0 if on else 0.0
		if calm():
			st["t"] = goal
			cb.queue_redraw()
			return
		var tw := cb.create_tween()
		tw.tween_method(func(x: float):
			st["t"] = x
			cb.queue_redraw(), float(st["t"]), goal, KNOB_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))
	cb.draw.connect(func():
		var track := cb.get_theme_icon("checked")
		var tex := UiTheme.knob_tex(cb.disabled)
		var x0 := cb.size.x - float(track.get_width())
		var mid := Vector2(0, cb.size.y * 0.5)
		var kx := lerpf(UiTheme.KNOB_X0, float(track.get_width()) - UiTheme.KNOB_X0, float(st["t"]))
		cb.draw_texture(tex, Vector2(x0 + kx, mid.y) - Vector2(tex.get_size()) * 0.5))
	return cb

## A toast's life: it slides down into place as it fades in, holds, then lifts away and fades.
static func toast(c: Control, y: float) -> void:
	var calm_now := calm()
	c.position.y = y if calm_now else y - 16.0
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.18)
	if not calm_now:
		tw.parallel().tween_property(c, "position:y", y, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(TOAST_HOLD_S)
	tw.tween_property(c, "modulate:a", 0.0, 0.32)
	if not calm_now:
		var lift := tw.parallel().tween_property(c, "position:y", y - 10.0, 0.32)
		lift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(c.queue_free)
