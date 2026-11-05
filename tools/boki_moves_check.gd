extends RefCounted
## --boki-moves-check: the new-Boki screen leads with the Boki and shows its moves as tiles (item 82).
##   1. every species with moves gets one tile per ability plus a gold bond tile, each with its name only
##   2. hovering (mouse) or focusing (keyboard/controller) a tile opens its tip; leaving it closes it
##   3. a tip is short: the name, what it does, then when or how it is used (cooldown or the Fuse key)
##   4. the reveal card holds the tiles and no paragraph longer than one sentence
## Never touches the save.

const MAX_TIP_LINES := 4       # name + what it does + when/cooldown (+ nothing else)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOKIMOVES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_every_species(main)
	await _hover_and_focus(main)
	await _reveal_card(main)
	print("BOKIMOVES DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## 1 + 3: tiles per species, names only, short tips.
func _every_species(main: Node) -> void:
	var n := 0
	for sid in Data.KIN:
		var sp: Dictionary = Data.KIN[sid]
		var want: int = sp.get("abilities", []).filter(func(a): return KinLib.ability(String(a)) != null).size()
		var has_bond := KinLib.merge(String(sp.get("ultimate", ""))) != null
		var bm := BokiMoves.new(String(sid), Save.new_kin(String(sid), "", 7))
		main.add_child(bm)
		var right := bm.tiles.size() == want + (1 if has_bond else 0)
		var short := true
		for t in bm.tips:
			var lines: PackedStringArray = String(t).split("\n")
			short = short and lines.size() >= 2 and lines.size() <= MAX_TIP_LINES
		if not right or not short:
			ok(false, "%s: %d tiles (want %d), tips short: %s" % [sid, bm.tiles.size(), want + int(has_bond), short])
		if has_bond:
			var last: String = bm.tips[bm.tips.size() - 1]
			if not last.contains(Settings.key_caps("ultimate")):
				ok(false, "%s: the bond tip names the Fuse key" % sid)
		bm.queue_free()
		n += 1
	ok(n > 0, "checked %d species: one tile per move plus the bond tile, tips of 2-%d lines" % [n, MAX_TIP_LINES])

## 2: hover and focus open the tip; leaving closes it.
func _hover_and_focus(main: Node) -> void:
	var bm := BokiMoves.new("cindle", Save.new_kin("cindle", "", 7))
	var holder := CanvasLayer.new()
	main.add_child(holder)
	holder.add_child(bm)
	bm.position = Vector2(300, 400)
	await main.get_tree().process_frame
	ok(not bm.tip.visible, "no tip until you point at a tile")
	bm.tiles[0].mouse_entered.emit()
	ok(bm.tip.visible and bm.shown == 0, "hovering the first tile opens its tip")
	ok(bm.tip.global_position.y + bm.tip.get_combined_minimum_size().y <= bm.tiles[0].get_global_rect().position.y,
		"the tip sits above the tile")
	bm.tiles[0].mouse_exited.emit()
	ok(not bm.tip.visible, "moving off closes it")
	var last := bm.tiles.size() - 1
	bm.tiles[last].grab_focus()
	await main.get_tree().process_frame
	ok(bm.tip.visible and bm.shown == last, "focusing the bond tile (keyboard/controller) opens its tip")
	bm.tiles[last].release_focus()
	await main.get_tree().process_frame
	ok(not bm.tip.visible, "losing focus closes it")
	holder.queue_free()

## 4: the reveal card is short: tiles instead of move paragraphs, one sentence of description.
func _reveal_card(main: Node) -> void:
	var rv := KinReveal.new("cindle", Save.new_kin("cindle", "", 4242))
	main.add_child(rv)
	await main.get_tree().process_frame
	var shown := rv.moves != null and rv.moves.is_inside_tree() and rv.moves.tiles.size() >= 2
	ok(shown, "the reveal card shows the move tiles")
	var long := 0
	for l in rv.info.find_children("*", "Label", true, false):
		if not rv.moves.is_ancestor_of(l) and String(l.text).count(". ") >= 1:
			long += 1
	ok(long == 0, "no multi-sentence paragraph on the card (%d)" % long)
	rv.queue_free()
