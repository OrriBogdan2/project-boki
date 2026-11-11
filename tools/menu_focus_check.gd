extends RefCounted
## --menu-focus-check: every button in the menus (Esc menu, Settings, Save files, Inventory, the
## title's list) is pointed at and focused at once (the worst case); its drawn rect (scale and
## focus ring included) must stay inside its panel and the window, at 1920x1080, 1280x720, 2560x1440
## and 1024x768. --shots-dir=<dir> (GPU) writes a picture per menu and size with the pointed button
## lit. Never touches the real save.

const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(2560, 1440), Vector2i(1024, 768)]
const MENUS := ["pause", "pause_title", "settings", "saves", "inventory"]
const SHOT_WORDS := ["Save and quit", "Settings", "Resume", "Quit"]      # the buttons that get a picture
const SETTLE := 0.15         # seconds for the hover tween to land
const SLOP := 0.5            # px of float noise allowed

var bad := 0
var checked := 0
var main: Node
var shots := ""

func ok(cond: bool, what: String) -> void:
	if not cond:
		printerr("MENUFOCUS FAIL ", what)
		bad += 1

func run(m: Node) -> void:
	main = m
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots-dir="):
			shots = arg.substr(12)
			DirAccess.make_dir_recursive_absolute(shots)
	Save.no_write = true
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	main.show_screen("title", {})
	# Settings scales the UI by the window, a 64 px stub when headless: the layout size is set by hand
	main.get_tree().root.size_changed.disconnect(Settings._apply_ui_scale)
	main.get_window().content_scale_factor = 1.0
	var last := Vector2.ZERO
	for px in SIZES:
		# the menus lay out at window / ui factor (Settings._apply_ui_scale), so 1080p, 720p and 1440p
		# share one 1280x720 layout: it is checked once, and a 4:3 window checks a different one
		var f := minf(minf(px.y / 720.0, px.x / 1240.0), minf(px.y / 640.0, px.x / 1100.0))
		var layout := Vector2(px) / f
		if layout.is_equal_approx(last):
			continue
		last = layout
		var win := main.get_window()
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_size = Vector2i(layout.round())
		await _settle(0.3)
		await _title(px)
		for menu in MENUS:
			await _menu(menu, px)
	print("MENUFOCUS CHECK DONE, buttons %d, failures: %d" % [checked, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _settle(secs: float) -> void:
	await main.get_tree().create_timer(secs).timeout

## The drawn rect of a control: its scale, pivot and focus ring included.
func _drawn(b: Button) -> Rect2:
	var t := b.get_global_transform()
	var r := Rect2(Vector2.ZERO, b.size)
	var f := b.get_theme_stylebox("focus") as StyleBoxFlat
	if f:
		r = r.grow_individual(f.expand_margin_left, f.expand_margin_top, f.expand_margin_right, f.expand_margin_bottom)
	var box := Rect2(t * r.position, Vector2.ZERO)
	for c in [r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
		box = box.expand(t * c)
	return box

func _buttons(n: Node, out: Array) -> void:
	if n is Button and n.is_visible_in_tree() and n.focus_mode != Control.FOCUS_NONE:
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)

## Point at and focus each button in turn; it must stay inside `bound` (its panel) and the window.
func _each(root: Node, bound: Control, what: String, px: Vector2i) -> void:
	var list: Array = []
	_buttons(root, list)
	var win := Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size).grow(SLOP)
	var want := Vector2(px) / minf(minf(px.y / 720.0, px.x / 1240.0), minf(px.y / 640.0, px.x / 1100.0))
	var seen := win.size - Vector2(SLOP, SLOP) * 2.0
	ok(seen.is_equal_approx(want), "%s %dx%d: layout is %s, wanted %s" % [what, px.x, px.y, seen, want])
	for b: Button in list:
		var sc := b.get_parent()
		while sc and not sc is ScrollContainer:
			sc = sc.get_parent()
		if sc:
			(sc as ScrollContainer).ensure_control_visible(b)      # a list scrolls to what is pointed at
		b.mouse_entered.emit()
		b.grab_focus()
		await _settle(SETTLE)
		var r := _drawn(b)
		var inside := bound.get_global_rect().grow(SLOP).encloses(r)
		ok(inside, "%s %dx%d: '%s' leaves its panel (%s)" % [what, px.x, px.y, b.text, r])
		ok(win.encloses(r), "%s %dx%d: '%s' leaves the window (%s)" % [what, px.x, px.y, b.text, r])
		checked += 1
		if shots != "" and SHOT_WORDS.any(func(w): return b.text.begins_with(w)):
			await _snap("%s_%s_%dx%d" % [what, b.text.left(8).to_snake_case(), px.x, px.y])
		b.mouse_exited.emit()
		b.release_focus()

func _snap(file: String) -> void:
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(shots.path_join(file + ".png"))

func _title(px: Vector2i) -> void:
	main.show_screen("title", {})
	await _settle(2.5)
	var ts: Node = main.screen_node()
	await _each(ts.menu_col, ts.menu_col, "title", px)
	print("MENUFOCUS title done, %d buttons so far" % checked)

func _menu(menu: String, px: Vector2i) -> void:
	match menu:
		"pause": Overlay.open_pause("home")
		"pause_title": Overlay.open_pause("title")
		"settings": Overlay.open_settings()
		"saves": Overlay.open_saves()
		"inventory": Overlay.open_inventory()
	await _settle(0.5)
	var panel: Control = Overlay.host.get_child(0) if Overlay.host.get_child_count() > 0 else null
	ok(panel != null, "%s opens" % menu)
	if panel:
		await _each(panel, panel, menu, px)
	Overlay.close()
	print("MENUFOCUS %s done, %d buttons so far" % [menu, checked])
	await _settle(0.1)
