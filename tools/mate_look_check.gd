extends RefCounted
## --mate-look-check: F1, F2 and F3 are rebindable "look at teammate N" holds (MateLook).
##   1. the three actions are on F1, F2, F3 and listed in Controls; the admin panel no longer takes F1
##   2. a 3-player squad: F1 / F2 swing the focus to those teammates, F3 (no third teammate) does nothing
##   3. a 4-player squad: F3 looks at teammate 3; the card names them; letting go returns to you
##   4. a menu or pause swallows the hold
## Run with a temporary XDG_DATA_HOME.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MATELOOK %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for i in 3:
		var a := "mate_look_%d" % (i + 1)
		var keys := [KEY_F1, KEY_F2, KEY_F3]
		var listed := Settings.ACTIONS.any(func(x): return x[0] == a)
		var on_key: bool = Settings.slots(a)[0] == "key:%d" % keys[i]
		ok(on_key and listed, "%s: on F%d, in Controls" % [a, i + 1])
	_squad(main, 3)
	_squad(main, 4)
	print("MATELOOK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _squad(main: Node, n: int) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": n, "tier": 0, "length": 1e9, "seed": 4242,
		"no_drop": true})
	m.set_process(false)
	var ml := m.mate_look
	var mates := ml.mates()
	ok(mates.size() == n - 1, "squad %d: %d teammates" % [n, mates.size()])
	var own := Vector3(1, 0, 2)
	var stay := ml.focus(own, 1.0) == own and ml.looking == null and not ml.card.visible
	ok(stay, "squad %d: nothing held, the view stays on you" % n)
	for i in 3:
		Input.action_press(ml.ACTIONS[i])
		var f := ml.focus(own, 1.0)
		if i < mates.size():
			var mate: Hunter = mates[i]
			var named := ml.name_lbl.text.begins_with(mate.pname)
			var there: bool = ml.looking == mate and f == mate.render_pos(1.0)
			ok(there and ml.card.visible and named, "squad %d: F%d looks at %s" % [n, i + 1, mate.pname])
		else:
			ok(ml.looking == null and f == own, "squad %d: F%d has nobody to look at" % [n, i + 1])
		Input.action_release(ml.ACTIONS[i])
	ok(ml.focus(own, 1.0) == own and not ml.card.visible, "squad %d: let go, back to you" % n)
	Input.action_press(ml.ACTIONS[0])
	m.paused = true
	ok(ml.focus(own, 1.0) == own, "squad %d: paused, the hold is ignored" % n)
	m.paused = false
	Input.action_release(ml.ACTIONS[0])
	m.queue_free()
