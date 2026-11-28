extends RefCounted
## --title-check: the title screen (painted splashes, logo and a torn-strip menu: briefs/UI_STYLE.md).
## It builds; its menu has the items it should (a short list: Continue or New Game, Training
## Grounds, Play with Friends when online play or the matchmaker is there, Settings, Quit off the web) and
## nothing called "The story so far"; Save Files and Help are on the title's Settings page; Play with Your
## Boki is not on the title; the owner's Test Zone and Demo Match (with a save) sit on a corner chip, never
## in the list; up/down wraps through the list; the logo keeps its full height for the owner too;
## the first button is the big one and holds focus, the rest are
## strips, and pointing at one focuses it; no subtext, tagline or currency under the logo; the logo,
## the painted backdrop and the build version are there; and the screen stays inside a frame budget
## (headless only: with a window the number holds a software renderer's draw time). Never touches the real save
## or settings.

const BUDGET_MS := 12.0          # average CPU time per frame the title may take (headless)
const FRAMES := 150

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TITLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	await _pass()
	# a save with a Boki: the main button carries on
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(k); Save.d["active"] = k["uid"]
	await main.show_screen("title", {})     # (done once the old screen has faded out and the title is built)
	for i in 6: await main.get_tree().process_frame
	var ts: Node = main.screen_node()
	var labels: Array = ts.menu_labels() if ts and ts.has_method("menu_labels") else []
	ok(not labels.is_empty() and String(labels[0]) == "Continue", "with a save in progress the first item is Continue (%s)" % [labels])
	print("TITLE CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

## Builds the title, checks it, and measures it.
func _pass() -> void:
	await main.show_screen("title", {})     # (done once the old screen has faded out and the title is built)
	for i in 6: await main.get_tree().process_frame
	var ts: Node = main.screen_node()
	ok(ts != null and ts.get_script() == load("res://scripts/ui/title.gd"), "the title screen builds")
	if ts == null:
		return
	var labels: Array = ts.menu_labels()
	var has: bool = not Save.d["roster"].is_empty()
	var want: Array = ["Continue" if has else "New Game", "Training Grounds"]
	if Net.available() or Net.mm.addr != "": want.append("Play with Friends")
	want.append("Settings")
	if not OS.has_feature("web"): want.append("Quit")
	ok(labels == want, "menu items %s" % [labels])
	ok(labels.size() <= 5, "the big button and at most 4 rows (%d)" % labels.size())
	var gone := ["Play with Your Boki", "Party", "Save Files", "Help", "Test Zone", "Demo Match"]
	ok(not labels.any(func(l): return gone.has(l)), "none of the moved rows is in the list %s" % [gone])
	var admin_want: Array = []
	if Overlay.admin_allowed():
		admin_want.append("Test Zone")
		if has: admin_want.append("Demo Match")
	ok(ts.admin_labels() == admin_want, "the owner's corner chip holds %s (%s)" % [admin_want, ts.admin_labels()])
	var chip: Control = ts.find_child("AdminChip", true, false)
	ok((chip != null) == Overlay.admin_allowed(), "the corner chip shows only with AdminGate")
	if chip:
		chip.pressed.emit()
		await main.get_tree().process_frame
		var pop: Control = ts.admin_pop
		var news: Control = ts.find_child("News", true, false)
		var nr := news.get_global_rect()
		var clear: bool = not pop.get_global_rect().intersects(nr) and not chip.get_global_rect().intersects(nr)
		var pr: Rect2 = pop.get_global_rect()
		var menu_clear: bool = not _menu_buttons(ts).any(func(b): return b.get_global_rect().intersects(pr))
		ok(pop.visible and clear and menu_clear, "the chip opens its popover, clear of the News chip and the menu")
		chip.pressed.emit()
		await main.get_tree().process_frame
		var back_home: bool = ts.get_viewport().gui_get_focus_owner() == ts.main_btn
		ok(not pop.visible and back_home, "pressing the chip again closes it and focus goes back to the big button")
	var tall: bool = ts.get_viewport().get_visible_rect().size.y >= ts.SHORT_WIN
	var logo_h: float = ts.logo.custom_minimum_size.y
	ok(not tall or logo_h >= ts.LOGO_H, "the logo keeps its full height for everyone, the owner too (%d)" % logo_h)
	var rows := _menu_buttons(ts)
	var first: Button = rows[0]
	var end: Button = rows[rows.size() - 1]
	var wraps: bool = end.get_node(end.focus_next) == first and first.get_node(first.focus_previous) == end
	ok(wraps and first.get_node(first.focus_neighbor_bottom) == rows[1], "up/down walks the list in order and wraps")
	ok(labels.all(_title_case), "every menu item is in Title Case (playtest 11-13: \"New game\")")
	var texts := _texts(ts)
	ok(not texts.any(func(s): return String(s).to_lower().contains("story so far")), "no \"The story so far\" anywhere on the title")
	ok(not texts.any(func(s): return String(s).to_lower().contains("gems")), "no currency on the title")
	var controls := ts.find_children("*", "Control", true, false)
	var backdrop: bool = controls.any(func(c): return c is TitleBackdrop)
	ok(ts.logo.is_visible_in_tree() and backdrop, "the logo is up over the painted backdrop")
	ok(texts.has("v" + Net.VERSION), "the build version is shown (v%s)" % [Net.VERSION])
	var flat := ts.find_children("*", "Camera3D", true, false) + ts.find_children("*", "MeshInstance3D", true, false)
	ok(flat.is_empty(), "no 3D scene runs under the painted backdrop")
	var strips := _menu_buttons(ts)
	var focus: Control = ts.get_viewport().gui_get_focus_owner()
	var big: bool = strips[0].theme_type_variation == "MenuMain"
	ok(big and focus == strips[0], "the first button is the big one and holds focus")
	var main_lit: bool = strips[0].get_theme_stylebox("normal") == strips[0].get_theme_stylebox("hover", "MenuMain")
	var no_ring: bool = strips[0].get_theme_stylebox("focus") is StyleBoxEmpty
	ok(main_lit and no_ring, "the focused big button wears its hover ticket, no pill focus ring (as the strips)")
	ok(strips.slice(1).all(func(b): return b.theme_type_variation == "MenuItem"), "the other items are strips")
	ok(not ts.menu_col.get_children().any(func(c): return c is Label), "no subtext or tagline in the menu column")
	var lit: Button = strips[1]
	lit.mouse_entered.emit()
	var focused: bool = ts.get_viewport().gui_get_focus_owner() == lit
	var hover := lit.get_theme_stylebox("hover", "MenuItem")
	ok(focused and lit.get_theme_stylebox("normal") == hover, "pointing at a strip focuses and lights it")
	# Save Files and Help moved onto the Settings page opened from the title
	Overlay.ctx = "title"
	Overlay.open_settings()
	await main.get_tree().process_frame
	var page_texts := _texts(Overlay.host)
	ok(page_texts.has("Save Files") and page_texts.has("Help"), "the title's Settings page leads to Save Files and Help")
	Overlay.close()
	await main.get_tree().process_frame
	# the frame budget: wall time of a frame (headless, that is the CPU side: scene logic and animation)
	var times: Array = []
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		await main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	times = times.slice(10)
	var avg := 0.0
	for x in times: avg += float(x)
	avg /= maxf(1.0, times.size())
	times.sort()
	var p95: float = times[int(times.size() * 0.95)]
	if DisplayServer.get_name() == "headless":      # (with a window the number holds a software rasteriser's draw time)
		ok(avg < BUDGET_MS, "frame budget: %.2f ms average, %.2f ms p95 (budget %.0f ms)" % [avg, p95, BUDGET_MS])
	print("TITLE %d nodes" % _count(ts))

## Every word capitalised but the short joining ones ("Play with Your Boki").
func _title_case(label: String) -> bool:
	for w in label.split(" ", false):
		if not w in ["a", "an", "and", "of", "or", "the", "to", "with"] and w[0] != w[0].to_upper():
			return false
	return true

func _menu_buttons(ts: Node) -> Array:
	return ts.menu_col.get_children().filter(func(c): return c is Button)

func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label: out.append((n as Label).text)
	elif n is Button: out.append((n as Button).text)
	for ch in n.get_children(): out.append_array(_texts(ch))
	return out

func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children(): c += _count(ch)
	return c
