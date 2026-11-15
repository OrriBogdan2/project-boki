extends RefCounted
## --lpage-drag-check: the practice loadout panel (L) takes a press-and-hold drag between the two glove rows
## (SlotDrag, with real input). Holding a glove you don't wear and dropping it on the other row wears it there;
## dragging the glove you wear onto the other row swaps the two; a drop on its own row changes nothing.
## Run with a temporary XDG_DATA_HOME. Prints LPAGEDRAG PASS/FAIL lines and quits 1 on a failure.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LPAGEDRAG %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("thief"))
	var A := m.arena
	A.give_glove("blink", 0)
	A.give_glove("grapple", 1)
	A.open_menu()
	await _frames(main, 3)
	await _drag(main, A, {"slot": 0, "id": "blink"}, {"slot": 1, "id": "frost"})
	ok(A.gloves == ["grapple", "blink"] and m.player.gear[0]["id"] == "grapple",
		"the worn glove dropped on the other row: the gloves swap (%s)" % [A.gloves])
	await _drag(main, A, {"slot": 0, "id": "frost"}, {"slot": 1, "id": "grapple"})
	ok(A.gloves == ["grapple", "frost"],
		"a glove you don't wear, dropped on the other row: worn there (%s)" % [A.gloves])
	await _drag(main, A, {"slot": 1, "id": "blink"}, {"slot": 1, "id": "grapple"})
	ok(A.gloves == ["grapple", "frost"], "dropped on its own row: nothing changes")
	A.close_menu()
	print("LPAGEDRAG DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Presses on one glove button, moves onto another and lets go (the panel rebuilds after a drop).
func _drag(main: Node, A: Arena, from: Dictionary, to: Dictionary) -> void:
	var drag: SlotDrag = A.menu_layer.find_children("*", "SlotDrag", true, false)[-1]
	var vp := main.get_viewport()
	_mouse(vp, true, _at(drag, from))
	var mv := InputEventMouseMotion.new()
	mv.position = _at(drag, to)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(mv, true)
	await _frames(main, 1)
	_mouse(vp, false, _at(drag, to))
	await _frames(main, 2)

func _at(drag: SlotDrag, key: Dictionary) -> Vector2:
	for c in drag._slots:
		if is_instance_valid(c) and drag._slots[c]["key"] == key:
			return SlotDrag._rect(c).get_center()
	return Vector2(-1, -1)

func _mouse(vp: Viewport, down: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	vp.push_input(ev, true)

func _frames(main: Node, k: int) -> void:
	for i in k:
		await main.get_tree().process_frame
