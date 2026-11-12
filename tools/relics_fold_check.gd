extends RefCounted
## --relics-fold-check: the first visit to the expedition panel and the Relics page (docs/UI_FIRST15.md 5.5).
##   1. first visit (only the first Where open): the expedition panel shows the picked Relic, one Where and Start;
##      other Relics, locked drops, Boki, match settings and the mode links are folded, each one click away
##   2. the Relics page shows the picked and open Relics; the locked ones fold and the fold shows every one
##   3. once a second drop is open nothing is folded, on either screen
##   4. at 1280x720 no Relic name is cut or wrapped, on the Relics tiles or the expedition cards
## Reads the real panels on the farm. Never touches the save.

const FOLD_TEXTS := ["Match", "Boki you bring", "Conditions", "Training Grounds"]
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RELICSFOLD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	var tree := main.get_tree()
	Save.no_write = true
	tree.root.size = Vector2i(1280, 720)
	var hm = await _farm(main, 0)
	hm._open_expedition()
	await _frames(tree)
	var host: Node = hm.panel_host
	ok(ExpFold.first_visit(), "a fresh save is on its first visit")
	var cards := _cards(host)
	var shown := _shown(cards)
	ok(cards.size() == Arch.ids().size() and shown.size() == 1 and shown[0].get_meta("arch") == Arch.of_save(),
			"the expedition panel shows only the picked Relic (%d of %d)" % [shown.size(), cards.size()])
	var tiers := _where_tiles(host)
	ok(_shown(tiers).size() == 1, "and one Where (%d shown of %d)" % [_shown(tiers).size(), tiers.size()])
	ok(FOLD_TEXTS.all(func(t): return not _visible_text(host, t)), "no Boki, match or mode link shows")
	var start := _button(host, "Start expedition")
	ok(start != null and start.is_visible_in_tree(), "Start shows")
	_button(host, "All Relics").pressed.emit()
	_button(host, "Locked drops").pressed.emit()
	_button(host, "More: Boki, match and modes").pressed.emit()
	await _frames(tree)
	ok(_shown(_cards(host)).size() == Arch.ids().size(), "the fold brings back every Relic")
	ok(_shown(_where_tiles(host)).size() == Data.TIERS.size(), "and every Where")
	ok(FOLD_TEXTS.all(func(t): return _visible_text(host, t)), "and Boki, match and the mode links")
	_names_whole(host, tree, "expedition", func(id): return HunterPickRow.name_of(id))
	hm._close_panel()
	HomeClasses.open(hm, Arch.of_save())
	await _frames(tree)
	var me := Arch.of_save()
	var tiles: Array = (hm.get_meta("classes_grid") as GridContainer).get_children()
	var want := tiles.filter(func(t): return _lit(t, me))
	ok(tiles.size() == Arch.ids().size() and _shown(tiles).size() == want.size() and want.size() < tiles.size(),
			"the Relics page shows %d of %d tiles on a first visit" % [_shown(tiles).size(), tiles.size()])
	_button(hm.panel_host, "Locked Relics").pressed.emit()
	await _frames(tree)
	ok(_shown(tiles).size() == tiles.size(), "the fold shows every Relic tile")
	_names_whole(hm.panel_host, tree, "Relics page", func(id): return Arch.name_of(id))
	hm.queue_free()
	await _frames(tree)
	# a second drop is open: nothing is folded
	hm = await _farm(main, int(Data.TIERS[1]["unlock"]))
	ok(not ExpFold.first_visit(), "with a second drop open it is no longer a first visit")
	hm._open_expedition()
	await _frames(tree)
	var host2: Node = hm.panel_host
	var whole := _shown(_cards(host2)).size() == Arch.ids().size() and _button(host2, "All Relics") == null
	ok(whole and _visible_text(hm.panel_host, "Match"), "the expedition panel is whole")
	hm._close_panel()
	HomeClasses.open(hm, Arch.of_save())
	await _frames(tree)
	var all_tiles: Array = (hm.get_meta("classes_grid") as GridContainer).get_children()
	var unfolded := _button(hm.panel_host, "Locked Relics") == null
	ok(_shown(all_tiles).size() == all_tiles.size() and unfolded, "and so are the tiles")
	hm.queue_free()
	print("RELICSFOLD DONE, failures: %d" % bad)
	tree.quit()

func _lit(tile: Node, me: String) -> bool:
	return tile.get_meta("class_status") in ["open", "ready"] or tile.get_meta("arch") == me

func _frames(tree: SceneTree, n := 12) -> void:
	for i in n: await tree.process_frame

## The farm on a fresh save that has made it out `extracts` times, one Boki, Vex picked.
func _farm(main: Node, extracts: int) -> Node:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["arch"] = "gunslinger"
	d["cls"] = Arch.weight("gunslinger")
	d["extracts"] = extracts
	Save.d = d
	var hm = await main._hb_home()
	await _frames(main.get_tree(), 30)
	return hm

func _walk(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children(): _walk(c, out)
	return out

func _cards(host: Node) -> Array:
	return _walk(host, []).filter(func(n): return n is PanelContainer and n.has_meta("arch"))

## The Where tiles: the cards that carry a drop's name.
func _where_tiles(host: Node) -> Array:
	var names: Array = Data.TIERS.map(func(t): return String(t["name"]))
	var out: Array = []
	for l in _walk(host, []).filter(func(n): return n is Label and names.has(n.text)):
		var p: Node = l
		while p != null and not p is PanelContainer: p = p.get_parent()
		if p != null and not out.has(p): out.append(p)
	return out

func _shown(nodes: Array) -> Array:
	return nodes.filter(func(n): return (n as Control).is_visible_in_tree())

func _visible_text(host: Node, text: String) -> bool:
	var want := text.to_lower()
	var labels := _walk(host, []).filter(func(n): return n is Label or n is Button)
	return labels.any(func(n): return n.text.to_lower() == want and n.is_visible_in_tree())

func _button(host: Node, text: String) -> Button:
	for n in _walk(host, []):
		if n is Button and n.text.begins_with(text): return n
	return null

## Every Label carrying a Relic's name is one line, as wide as its text, and inside the window.
func _names_whole(host: Node, tree: SceneTree, where: String, name_of: Callable) -> void:
	var seen := 0
	var cut: Array = []
	for id in Arch.ids():
		var nm: String = name_of.call(id)
		for n in _walk(host, []):
			if not (n is Label and n.text == nm and n.is_visible_in_tree()): continue
			var l: Label = n
			seen += 1
			var fs := l.get_theme_font_size("font_size")
			var w := l.get_theme_font("font").get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if l.size.x + 0.5 < w or l.get_line_count() > 1 or l.get_global_rect().end.x > tree.root.size.x:
				cut.append("%s (%.0f of %.0f px, %d lines)" % [nm, l.size.x, w, l.get_line_count()])
	var note := "" if cut.is_empty() else " cut: " + str(cut)
	ok(seen >= Arch.ids().size() and cut.is_empty(), "%s: all %d Relic names whole at 1280x720%s" % [where, seen, note])
