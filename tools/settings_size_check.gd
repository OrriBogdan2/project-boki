extends RefCounted
## --settings-size-check: the Settings panel keeps one size on every category tab, in a 720p and a small
## window and two ultrawides (playtest 11-13: changing category resized the whole panel), and sits inside the
## window's safe area, also while the search box lists rows from every tab.
## Never touches the real save.

const WINDOWS := [Vector2i(1280, 720), Vector2i(2560, 1080), Vector2i(3440, 1440)]  # 720p, two ultrawides
const SETTLE := 20  # frames for the panel and its scroll to size themselves
const SAME_PX := 1.0  # px: the panel may differ this much between tabs (rounding)
const SEARCHES := ["e", "zzzz"]  # a long result list (most rows), and no result

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("SETSIZE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	# Settings scales the UI by the window, a 64 px stub when headless: the layout the game would use is set by hand
	m.get_tree().root.size_changed.disconnect(Settings._apply_ui_scale)
	var win := m.get_window()
	win.content_scale_factor = 1.0
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for px in WINDOWS:
		win.content_scale_size = Vector2i((Vector2(px) / minf(px.y / 720.0, px.x / 1240.0)).round())
		Overlay.tab = Overlay.SETTINGS_TABS[0]
		Overlay.open_settings()
		var first := Vector2.ZERO
		for t in Overlay.SETTINGS_TABS:
			Overlay.tab = t
			Overlay._show_settings()  # what a tab click does
			for i in SETTLE:
				await m.get_tree().process_frame
			var shell: Control = Overlay.host.get_child(Overlay.host.get_child_count() - 1)
			var r := shell.get_global_rect()
			if first == Vector2.ZERO:
				first = r.size
			var same := absf(r.size.x - first.x) <= SAME_PX and absf(r.size.y - first.y) <= SAME_PX
			var safe := HudStyle.safe_rect(m.get_viewport().get_visible_rect().size)
			ok(same and safe.encloses(r), "%dx%d %s: panel %s (first %s), safe area" % [px.x, px.y, t, r.size, first])
		for q in SEARCHES:
			Overlay.search = q
			Overlay._show_settings()
			for i in SETTLE:
				await m.get_tree().process_frame
			var shell: Control = Overlay.host.get_child(Overlay.host.get_child_count() - 1)
			var r := shell.get_global_rect()
			var same := absf(r.size.x - first.x) <= SAME_PX and absf(r.size.y - first.y) <= SAME_PX
			var inside := HudStyle.safe_rect(m.get_viewport().get_visible_rect().size).encloses(r)
			ok(same and inside, "%dx%d search '%s': panel %s, in the safe area" % [px.x, px.y, q, r.size])
		Overlay.search = ""
		Overlay.close()
		await m.get_tree().process_frame
	win.content_scale_size = Vector2i.ZERO
	print("SETSIZE done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
