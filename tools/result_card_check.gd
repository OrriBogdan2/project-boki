extends RefCounted
## --result-card-check: the garden games' shared result card (scripts/ui/game_result_card.gd).
##   1. it shows the game, the placing, the prize lines, and per Boki the joy and stats it gained (stat icons)
##   2. every card is the same size and place, with one Boki or three and one prize line or three, inside 1280x720
##   3. one click closes it

var main: Node
var fails := 0

func ok(what: String, cond: bool) -> void:
	printerr("RESULTCARD %-62s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		fails += 1

func run(m: Node) -> void:
	main = m
	var root_ui := Control.new()
	root_ui.size = Vector2(1280, 720)
	main.add_child(root_ui)
	var recs: Array = []
	for n in ["Pebble", "Moss", "Dot"]:
		var rec := {"name": n, "stats": {"power": 3, "speed": 4}, "needs": {"joy": 50.0}}
		recs.append(rec)
	var before := GameResultCard.snap(recs)
	recs[0]["needs"]["joy"] = 58.0
	recs[0]["stats"]["speed"] = 5
	recs[1]["needs"]["joy"] = 45.0
	var small := _open(root_ui, before.slice(0, 1), [["+3 gems", UI.GOLD]])
	var big := _open(root_ui, before, [["+3 gems", UI.GOLD], ["Prize: Rope, Ball", UI.GOLD], ["Crown!", UI.TEAL]])
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var texts := _texts(big)
	ok("shows the game, the placing and the prize",
			texts.has("Tumble") and texts.has("Pebble wins") and texts.has("Prize: Rope, Ball"))
	ok("shows the joy a Boki gained and lost", texts.has("Joy +8") and texts.has("Joy -5") and texts.has("Joy +0"))
	var glyphs := big.find_children("*", "Control", true, false).filter(func(c): return c is Icons.Glyph)
	ok("shows the stat it gained with its icon",
			glyphs.size() == 1 and glyphs[0].id == StatGlint.ICON["speed"] and texts.has("+1"))
	ok("every card is the same size", small.size == big.size and big.size == GameResultCard.SIZE)
	ok("and in the same place", small.position == big.position)
	var view := Rect2(Vector2.ZERO, Vector2(1280, 720))
	ok("and fits 1280x720", view.encloses(Rect2(big.global_position, big.size)))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	big.gui_input.emit(click)
	await main.get_tree().process_frame
	ok("one click closes it", not is_instance_valid(big) and is_instance_valid(small))
	root_ui.queue_free()
	print("RESULTCARD DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _open(root_ui: Control, before: Array, prize: Array) -> Control:
	var data := {"game": "Tumble", "place": "Pebble wins", "prize": prize, "before": before}
	return GameResultCard.open(_Home.new(root_ui), data)

func _texts(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)

class _Home:
	var root_ui: Control
	func _init(ui: Control) -> void:
		root_ui = ui
