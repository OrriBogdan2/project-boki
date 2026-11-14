extends RefCounted
## --ui-scale-check: every step of the Interface size slider changes the interface size, at 720p, 1080p and a
## small window (playtest 11-13: nothing changed past 115%), and at its top the layout still has the 1100x640
## space the menus need. Never touches the real settings file.

const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540)]
const STEP := 0.05  # the slider's step (overlay.gd "Interface size")
const LAYOUT_MIN := Vector2(1100, 640)  # px (logical): the least space the menus are laid out for

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("UISCALE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	var was := float(Settings.v.get("ui_scale", 1.0))
	var root: Window = m.get_tree().root
	for px in WINDOWS:
		root.size = px
		await m.get_tree().process_frame
		var last := 0.0
		var grows := true
		var user := Settings.UI_SCALE_MIN
		while user <= Settings.UI_SCALE_MAX + 0.001:
			Settings.set_v("ui_scale", user, false)
			var f := root.content_scale_factor
			grows = grows and f > last + 0.001
			last = f
			user += STEP
		var room := Vector2(root.size) / last
		ok(grows, "%dx%d: every slider step grows the interface (top %.3f)" % [px.x, px.y, last])
		ok(
			room.x >= LAYOUT_MIN.x - 0.5 and room.y >= LAYOUT_MIN.y - 0.5,
			"%dx%d: at the top the layout has %s" % [px.x, px.y, room]
		)
	Settings.set_v("ui_scale", was, false)
	print("UISCALE done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
