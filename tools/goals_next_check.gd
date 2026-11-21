extends "res://tools/new_player_flow_check.gd"
## --goals-next-check: the Goals card always has a next step. A fresh save is played through the tutorial
## match, the farm tutorial, Hob's second Relic and the first expedition; at every moment the card is
## recorded, and from the first hub arrival on it must list one to three rows (never empty, never more).
## Never touches the real save.

func run(m: Node) -> void:
	main = m
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	main.get_window().size = Vector2i(1280, 720)
	await _prologue()
	await _hatch()
	var home = await _tutorial_match()
	_goals("first hub arrival")
	await _farm_tutorial(home)
	_goals("farm tutorial done")
	await _second_relic(home)
	_goals("second Relic taken")
	await _first_expedition(home)
	_goals("back from the first expedition")
	print("GOALS DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)

func _goals(moment: String) -> void:
	var rows := GoalTracker.lines()
	var shown := rows.map(func(r): return "%s [%s %d/%d]" % [r["text"], r["source"], r["have"], r["need"]])
	print("GOALS %s: %s" % [moment, " | ".join(shown)])
	ok(rows.size() >= 1 and rows.size() <= 3, "%s: %d goal rows (1 to 3)" % [moment, rows.size()])
	ok(rows.all(func(r): return String(r["text"]) != ""), "%s: every row says what to do" % moment)
