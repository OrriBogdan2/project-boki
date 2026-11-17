extends RefCounted
## --expedition-arrows-check: the expedition panel's pickers never close it (owner playtest 11-17).
##   1. with one Boki the Boki card's arrows are greyed and a grey line says there is no other Boki
##   2. pressing them anyway (or the Right key on a focused one) keeps the panel open
##   3. with two Boki the arrows work, the panel stays open and a fold you opened (Details) stays open
## Reads the real panel on the farm. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("EXPARROWS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	var tree := main.get_tree()
	Save.no_write = true
	tree.root.size = Vector2i(1280, 720)
	var hm = await _farm(main)
	hm._open_expedition()
	await _frames(tree)
	var arrows := _arrows(hm.panel_host)
	ok(arrows.size() == 2, "one Boki: the Lead card has a previous and a next arrow (%d)" % arrows.size())
	ok(arrows.all(func(b): return b.disabled), "one Boki: both arrows are greyed")
	ok(_has_text(hm.panel_host, "No other Boki yet"), "one Boki: a grey line says there is no other Boki")
	for i in 2:
		var tip: String = _arrows(hm.panel_host)[i].tooltip_text
		_arrows(hm.panel_host)[i].pressed.emit()
		await _frames(tree)
		ok(hm.panel_open == "Expedition" and hm.panel_host.get_child_count() > 0, "pressing %s keeps the panel open" % tip)
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(tree)
	ok(hm.panel_open == "Expedition", "the Right key keeps the panel open")
	var other := Save.new_kin("zapple", "Glint")
	Save.d["roster"].append(other)
	hm._open_expedition()
	await _frames(tree)
	arrows = _arrows(hm.panel_host)
	ok(arrows.size() >= 2 and arrows.all(func(b): return not b.disabled), "two Boki: the arrows work")
	var details := _button(hm.panel_host, "Details")
	details.pressed.emit()
	_arrows(hm.panel_host)[1].pressed.emit()
	await _frames(tree)
	ok(hm.panel_open == "Expedition" and Save.d["active"] == other["uid"], "two Boki: next picks the other one, panel open")
	ok(_button(hm.panel_host, "Fewer details") != null, "and Details is still open after the pick")
	hm._close_panel()
	hm._open_expedition()
	await _frames(tree)
	ok(_button(hm.panel_host, "Details") != null, "a fresh open starts with Details shut")
	hm.queue_free()
	print("EXPARROWS DONE, failures: %d" % bad)
	tree.quit()

func _frames(tree: SceneTree, n := 12) -> void:
	for i in n: await tree.process_frame

func _farm(main: Node) -> Node:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["arch"] = "gunslinger"
	d["cls"] = Arch.weight("gunslinger")
	Save.d = d
	ClassUnlock.choose_starters(["gunslinger"])
	var hm = await main._hb_home()
	await _frames(main.get_tree(), 30)
	return hm

func _walk(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children(): _walk(c, out)
	return out

## The Boki card's previous and next buttons (the ones with the "Boki" tips).
func _arrows(host: Node) -> Array:
	return _walk(host, []).filter(func(n): return n is Button and n.tooltip_text.ends_with(" Boki"))

func _has_text(host: Node, text: String) -> bool:
	return _walk(host, []).any(func(n): return n is Label and n.text == text and n.is_visible_in_tree())

func _button(host: Node, text: String) -> Button:
	for n in _walk(host, []):
		if n is Button and n.text.begins_with(text): return n
	return null
