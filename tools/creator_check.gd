extends RefCounted
## --creator-check: a new player's creator shows Sex, Height, Build and Shroud colour first, "More" opens the
## rest (the menu's Change your look shows all of them), and the Name your Boki card has one text box (the
## Boki's) with the idea chips and no stale subtitle (docs/UI_FIRST15.md 5.6). Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CREATOR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var tree := main.get_tree()
	tree.root.size = Vector2i(1280, 720)
	var hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	for i in 4: await tree.process_frame
	hx._show_create()
	var first: Array = Unmasked.FIRST_ROWS.map(func(r): return Unmasked.ROWS[r][1])
	ok(first == ["Sex", "Height", "Build", "Shroud colour"], "the first rows are %s" % str(first))
	var shown := _labels(hx.create_box)
	ok(shown == first, "a new save's creator shows only those: %s" % str(shown))
	var more := _button(hx.create_box, "More")
	ok(more != null, "and a More button")
	if more: more.pressed.emit()
	for i in 3: await tree.process_frame
	ok(_labels(hx.create_box).size() == Unmasked.ROWS.size(), "More opens all %d rows" % Unmasked.ROWS.size())
	ok(_button(hx.create_box, "More") == null, "and the button goes")
	hx.queue_free()
	await tree.process_frame
	hx = load("res://scripts/ui/hatch.gd").new()
	hx.edit_only = true
	main.add_child(hx)
	for i in 4: await tree.process_frame
	ok(_labels(hx.create_box).size() == Unmasked.ROWS.size(), "Change your look from the menu shows every row")
	hx.queue_free()
	await tree.process_frame
	# the name card
	hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	for i in 4: await tree.process_frame
	hx._looks_good()
	hx.chosen = 0
	hx._start_hatch()
	hx._show_name()
	await tree.process_frame
	var boxes: Array = hx.ui.find_children("*", "LineEdit", true, false)
	ok(boxes.size() == 1, "the name card has one text box (%d)" % boxes.size())
	ok(not hx.sub_lbl.visible or not hx.sub_lbl.text.contains("Every Boki"), "no stale subtitle under the title")
	var texts: Array = _texts(hx.ui)
	ok(not texts.has("Your name") and texts.has("Ideas"), "no second name row; the idea chips stay")
	hx.queue_free()
	print("CREATOR CHECK DONE, failures: %d" % bad)
	tree.quit()

## The row labels (the 120 px-wide ones) of the creator card.
func _labels(card: Control) -> Array:
	var names: Array = Unmasked.ROWS.map(func(r): return r[1])
	return _texts(card).filter(func(t): return names.has(t))

func _button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == text: return b
	return null

func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label: out.append((n as Label).text)
	elif n is Button: out.append((n as Button).text)
	for c in n.get_children(): out.append_array(_texts(c))
	return out
