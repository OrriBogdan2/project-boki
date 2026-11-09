class_name QuickNote
extends RefCounted
## F8 "Quick note": a one-line box at the bottom of the screen that does not pause an online match. Enter
## saves the line with where you were (game version, Hunter, Boki, match time, map position, graphics
## preset, fps) and a small screenshot into Feedback's queue; Esc cancels. The queue is sent when the rate
## card sends, on quit, or next launch (Feedback.flush).

const SHOT_W := 128             # px: the screenshot is shrunk to this width
const SHOT_QUALITY := 0.4       # JPEG quality of that screenshot

static var typing := false      # the box is open: the match ignores movement keys

static func open(host: Control) -> void:
	if typing:
		return
	typing = true
	var ctx := context()
	var shot := screenshot(host.get_viewport())
	var m := Game.main.screen_node() as Match if Game.main else null
	var was_paused := m != null and m.paused
	if m: m.paused = true       # an online match keeps running, an offline one waits
	var panel := UI.sheet(560)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	panel.position.y -= 60
	var v := UI.vbox(4)
	panel.add_child(v)
	var hint := "Quick note for the devs. Enter saves it with where you are, Esc cancels."
	v.add_child(UI.para(hint, UI.T_BODY, UI.MUTED))
	var line := LineEdit.new()
	line.placeholder_text = "What did you notice?"
	line.max_length = Feedback.NOTE_MAX
	v.add_child(line)
	var close := func() -> void:
		typing = false
		if m and is_instance_valid(m): m.paused = was_paused
		panel.queue_free()
	line.text_submitted.connect(func(text: String) -> void:
		if text.strip_edges() != "":
			Feedback.add_note(text.strip_edges(), ctx, shot)
		close.call())
	line.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_cancel"):
			line.accept_event()
			close.call())
	host.add_child(panel)
	line.grab_focus()

## Where and how the player is: Hunter, Boki, match time (s), map position (m), preset and fps.
static func context() -> Dictionary:
	var ctx := {"version": Net.VERSION, "preset": Settings.quality(), "fps": Engine.get_frames_per_second()}
	var m := Game.main.screen_node() as Match if Game.main else null
	if m and m.player:
		ctx["hunter"] = m.player.arch if m.player.arch != "" else m.player.cls
		ctx["boki"] = (m.player.kin as Kin).species if m.player.kin is Kin else "none"
		ctx["t"] = snappedf(m.time, 0.1)
		ctx["pos"] = [snappedf(m.player.pos.x, 0.1), snappedf(m.player.pos.z, 0.1)]
	return ctx

## The current frame as a small base64 JPEG, or "" when there is no picture (headless) or it would not fit.
static func screenshot(vp: Viewport) -> String:
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return ""
	img.resize(SHOT_W, maxi(1, SHOT_W * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	var b64 := Marshalls.raw_to_base64(img.save_jpg_to_buffer(SHOT_QUALITY))
	return b64 if b64.length() <= Feedback.SHOT_MAX else ""
