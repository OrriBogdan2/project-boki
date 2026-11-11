extends RefCounted
## --interact-prompt-check: the one interact prompt (InteractPrompt). In a real match two chests are in
## reach: one prompt shows, for the nearest, with a verb, the target and the live key cap. Rebinding F
## changes the cap at once. A hold action shows the ring filling; a line that only informs has no cap.
## One prompt at a time: it yields to a tutorial tip card. The Ways Out and the garden hub's Waystone
## give verb fields, never a sentence with a key in it. Never touches the save.

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
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "heart": true})
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
	widget.show_for(InteractPrompt.match_item(m, p, m.interact))
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
	widget.show_for(InteractPrompt.match_item(m, p, m.interact))
	var frac := widget.ring.frac
	ok(widget.ring.visible and is_equal_approx(frac, 0.6), "a hold shows the ring filling (%.2f)" % frac)
	var first: InputEvent = InputMap.action_get_events("interact")[0].duplicate()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_G
	Settings.rebind("interact", ev)
	widget.show_for(InteractPrompt.match_item(m, p, m.interact))
	ok(widget.cap_lbl.text == "G", "rebinding F to G changes the cap at once ('%s')" % widget.cap_lbl.text)
	Settings.rebind("interact", first)
	widget.show_for({"note": "This dock has closed"})
	var bare: bool = not widget.ring.visible and not widget.line.visible
	ok(widget.visible and bare, "a line that only informs has no cap and no ring")
	near["prog"] = 0.0
	m.tut = Tutorial.new(m)
	m.tut.intro = true
	widget.show_for(InteractPrompt.match_item(m, p, m.interact))
	ok(not widget.visible, "a tutorial tip card popping in: the prompt yields to it")
	near["prog"] = 0.3
	widget.show_for(InteractPrompt.match_item(m, p, m.interact))
	ok(widget.visible, "...but a hold under way keeps its ring")
	m.tut = null
	_ways_out(m, p, widget)
	var way := HubWaystone.new({"zone": GardenZones.HUB, "visit": {}})
	widget.show_for(way.label())
	ok(widget.line.text == "Travel  ·  Waystone" and widget.cap_lbl.text == Settings.key_cap("interact"),
		"the garden hub's Waystone: Travel, with the live key ('%s')" % widget.line.text)
	widget.show_for({})
	ok(not widget.visible, "nothing in reach: nothing shown")
	print("INTERACT-PROMPT-CHECK: %s" % ("PASS" if bad == 0 else "%d FAIL" % bad))
	Save.no_write = false
	main.get_tree().quit(0 if bad == 0 else 1)

## The Ways Out: the uplink seat, the Heart and its Gate, a lair's rune, a loose wisp: each a verb, no key in the text.
func _ways_out(m: Match, p: Hunter, widget: InteractPrompt) -> void:
	var key := Settings.key_cap("interact")
	var its: Array = []
	if m.exits:
		var x: Dictionary = m.exits.list[0]
		p.teleport(x["pos"] + Vector3(0.6, 0, 0.6))
		its.append(m.exits.interact_for(p))
	if m.heart and m.heart.site != Vector3.INF:
		m.heart.state = Heart.S.CARRIED
		m.heart.early_team = -1
		m.heart.charge = Heart.r("charge_s")
		m.heart.carrier = p
		p.teleport(m.heart.gate)
		its.append(m.heart.interact_for(p))
		m.heart.carrier = null
	ok(its.size() == 2, "the match has an uplink and the Heart Gate to prompt for (%d)" % its.size())
	for it in its:
		var shown: bool = not it.is_empty()
		widget.show_for(it)
		var txt := "%s %s" % [String(it.get("verb", "")), String(it.get("note", ""))]
		var no_key := not txt.contains("Hold %s" % key) and not txt.contains("Press %s" % key)
		ok(shown and widget.visible and not it.has("label") and no_key,
			"a Ways Out prompt (%s) uses the widget's fields: '%s'" % [it.get("kind", "?"), txt.strip_edges()])
