extends RefCounted
## --settings-size-check: the Settings panel keeps one size on every category tab, in a 720p and a small
## window (playtest 11-13: changing category resized the whole panel), and sits inside the window.
## Never touches the real save.

const WINDOWS := [Vector2i(1280, 720), Vector2i(960, 540)]
const SETTLE := 20  # frames for the panel and its scroll to size themselves
const SAME_PX := 1.0  # px: the panel may differ this much between tabs (rounding)

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("SETSIZE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	for px in WINDOWS:
		m.get_tree().root.size = px
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
			var inside := m.get_viewport().get_visible_rect().encloses(r)
			ok(same and inside, "%dx%d %s: panel %s (first tab %s), inside the window" % [px.x, px.y, t, r.size, first])
		Overlay.close()
		await m.get_tree().process_frame
	print("SETSIZE done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
