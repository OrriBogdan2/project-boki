extends RefCounted
## --lpage-fit-check: the practice loadout panel (L) fits the screen. At each window size (16:9 720p,
## 1080p, 1440p and 16:10) with the default UI scale, every control on the panel lies inside the
## viewport (the Boki list scrolls: the list itself is inside, and scrolled to its end it shows its last
## entry), and the panel header names the hunter with their portrait (not their title).
## Run with a temporary XDG_DATA_HOME. Prints LPAGEFIT PASS/FAIL lines and quits 1 on a failure.

const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(2560, 1440), Vector2i(1920, 1200)]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LPAGEFIT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("thief"))
	var A := m.arena
	A.give_glove("blink", 0)
	A.give_glove("grapple", 1)
	for sz in SIZES:
		main.get_window().size = sz
		for i in 3:
			await main.get_tree().process_frame
		A.open_menu()
		for i in 3:
			await main.get_tree().process_frame
		_fits(A, sz)
		await _scrolls_to_end(A, sz)
		A.close_menu()
	A.open_menu()
	await main.get_tree().process_frame
	_header(A)
	A.close_menu()
	print("LPAGEFIT DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Every visible control of the open panel lies inside the visible viewport.
func _fits(A: Arena, sz: Vector2i) -> void:
	var view := A.menu_layer.get_viewport().get_visible_rect().grow(0.5)
	var out: Array = []
	var bottom := 0.0
	for c in A.menu_layer.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or _in_list(ctl):
			continue
		var r := ctl.get_global_rect()
		bottom = maxf(bottom, r.end.y)
		if not view.encloses(r):
			out.append("%s %s" % [ctl.get_class(), _text(ctl)])
	ok(out.is_empty(), "%dx%d: every control inside the %dx%d view (lowest edge %d)%s" % [
		sz.x, sz.y, int(view.size.x), int(view.size.y), int(bottom),
		"" if out.is_empty() else "  outside: " + ", ".join(out.slice(0, 8))])

## A control inside the scrolling Boki list (judged by the list, which must itself be inside the view).
func _in_list(c: Control) -> bool:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer: return true
		p = p.get_parent()
	return false

## Scrolled to its end, the Boki list shows its last entry ("None") whole.
func _scrolls_to_end(A: Arena, sz: Vector2i) -> void:
	var sc: ScrollContainer = A.menu_layer.find_children("boki_list", "ScrollContainer", true, false)[0]
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await A.menu_layer.get_tree().process_frame
	var grid := sc.get_child(0) as Control
	var last := grid.get_child(grid.get_child_count() - 1) as Button
	ok(sc.get_global_rect().grow(0.5).encloses(last.get_global_rect()) and last.text == "None",
		"%dx%d: the Boki list scrolls to its last entry (%d entries, %d px shown of %d)" % [
		sz.x, sz.y, grid.get_child_count(), int(sc.size.y), int(grid.size.y)])

## The header shows the hunter's name and a portrait, and no title.
func _header(A: Arena) -> void:
	var hd: Control = A.menu_layer.find_children("menu_header", "", true, false)[0]
	var texts := " ".join(hd.find_children("*", "Label", true, false).map(func(l): return (l as Label).text))
	ok(texts.contains(HeroTitle.base_name("thief")), "header names the hunter (%s)" % texts.strip_edges())
	ok(not texts.contains(HeroTitle.title("thief")), "header does not show the title")
	ok(hd.find_child("portrait", false, false) != null, "header has the portrait")

func _text(c: Control) -> String:
	if c is Label: return "'%s'" % (c as Label).text.left(24)
	if c is Button: return "'%s'" % (c as Button).text.left(24)
	return ""
