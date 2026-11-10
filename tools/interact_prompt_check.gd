extends RefCounted
## --interact-prompt-check: the one interact prompt (InteractPrompt). In a real match two chests are in
## reach: one prompt shows, for the nearest, with a verb, the target and the live key cap. Rebinding F
## changes the cap at once. A hold action shows the ring filling; a line that only informs has no cap.
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("IPROMPT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _chest(m: Match, at: Vector3) -> Dictionary:
	var c := {"pos": at, "open": false, "prog": 0.0, "free": true}
	m.chests.append(c)
	return c

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.chests.clear()
	m.boxes.clear()
	m.wpicks.clear()
	m.shrines.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != m.player: h.teleport(m.player.pos + Vector3(60, 0, 0))
	var p := m.player
	var near := _chest(m, p.pos + Vector3(0.5, 0, 0))
	var far := _chest(m, p.pos + Vector3(-1.2, 0, 0))
	p.inp["aim"] = p.pos
	p.inp["interact"] = false
	for i in 30:
		m.time += Match.DT
		m._update_interact(Match.DT)
	var widget := InteractPrompt.new()
	main.add_child(widget)
	widget.show_for(InteractPrompt.match_item(p, m.interact))
	ok(is_same(m.interact.get("chest"), near), "two chests in reach: the target is the nearest")
	var said := widget.line.text
	var names_both := said.begins_with("Open") and said.contains("Chest")
	ok(widget.visible and names_both, "one prompt: verb and target ('%s')" % said)
	ok(widget.cap_lbl.text == Settings.key_cap("interact"), "the cap is the live binding ('%s')" % widget.cap_lbl.text)
	var shown := 0
	for n in main.get_tree().root.find_children("*", "PanelContainer", true, false):
		if n is InteractPrompt and (n as InteractPrompt).visible: shown += 1
	ok(shown == 1, "exactly one prompt is visible in the tree (%d)" % shown)
	far["prog"] = 0.4
	near["prog"] = 0.6
	widget.show_for(InteractPrompt.match_item(p, m.interact))
	var frac := widget.ring.frac
	ok(widget.ring.visible and is_equal_approx(frac, 0.6), "a hold shows the ring filling (%.2f)" % frac)
	var first: InputEvent = InputMap.action_get_events("interact")[0].duplicate()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_G
	Settings.rebind("interact", ev)
	widget.show_for(InteractPrompt.match_item(p, m.interact))
	ok(widget.cap_lbl.text == "G", "rebinding F to G changes the cap at once ('%s')" % widget.cap_lbl.text)
	Settings.rebind("interact", first)
	widget.show_for({"note": "This dock has closed"})
	var bare: bool = not widget.ring.visible and not widget.line.visible
	ok(widget.visible and bare, "a line that only informs has no cap and no ring")
	widget.show_for({})
	ok(not widget.visible, "nothing in reach: nothing shown")
	print("INTERACT-PROMPT-CHECK: %s" % ("PASS" if bad == 0 else "%d FAIL" % bad))
	Save.no_write = false
	main.get_tree().quit(0 if bad == 0 else 1)
