extends RefCounted
## --modes-check: the expedition modes (docs/decisions/0084-modes-solos-play-space.md). Never touches the save.
##   1. Data.mode_opts: trios are 10 squads of three (30 hunters), solos 20 hunters on their own.
##   2. a trios match starts with 30 hunters in 10 squads of three; a solos match with 20, each on their own.
##   3. the expedition panel shows a Trios card and a Solos card, one plain line each; a press picks and
##      remembers the mode (Data.saved_mode) and the next match is that mode; the online lobby opens on it.

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("MODES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_mode_opts()
	await _match("trios", 30, 10)
	await _match("solos", 20, 20)
	await _panel()
	print("MODES ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)


func _mode_opts() -> void:
	ok(Data.MODES == ["trios", "solos"], "the modes a player can queue for: trios and solos")
	ok(Data.mode_opts("trios") == {"teams": 10, "squad": 3, "total": 30}, "trios: 10 squads of three")
	ok(Data.mode_opts("solos") == {"teams": 20, "squad": 1, "total": 20}, "solos: 20 hunters on their own")
	ok(Data.saved_mode() == "trios", "a fresh save queues trios")


## A match in a mode, built and paused at the start: its hunter and squad counts.
func _match(mode: String, hunters: int, squads: int) -> void:
	var m := Match.new()
	main.add_child(m)
	var o := {"tier": 0, "seed": 4101, "autoplay": true}
	o.merge(Data.mode_opts(mode))
	await m.start(o)
	m.set_process(false)
	var teams := {}
	for h in m.hunters:
		teams[h.team] = int(teams.get(h.team, 0)) + 1
	ok(
		m.hunters.size() == hunters and teams.size() == squads,
		"%s: %d hunters in %d squads (want %d in %d)" % [mode, m.hunters.size(), teams.size(), hunters, squads]
	)
	m.queue_free()
	for i in 3:
		await main.get_tree().process_frame


func _panel() -> void:
	var hm = await main._hb_home()
	ExpeditionPanel.open(hm)  # (the panel itself: a fresh save would get the starter Relic first)
	await main.get_tree().process_frame
	_cards(hm.panel_host, "the expedition panel")
	var rolling := _texts(hm.panel_host).filter(func(t): return String(t).to_lower().contains("rolling"))
	ok(rolling.is_empty(), "no rolling session on the panel")
	_card(hm.panel_host, "solos").gui_input.emit(_click())
	await main.get_tree().process_frame
	ok(Data.saved_mode() == "solos", "a Solos card press queues and remembers solos")
	ExpeditionPanel.open(hm)
	await main.get_tree().process_frame
	var picked := _card(hm.panel_host, "solos").get_theme_stylebox("panel") as UiFrame
	ok(picked != null and picked.edge_w == 2, "the picked card wears the accent edge (Solos)")
	hm.queue_free()
	var lobby: Control = load("res://scripts/ui/lobby.gd").new()
	main.add_child(lobby)
	await main.get_tree().process_frame
	ok(
		lobby.mode == "solos" and lobby.mode_btns.has("solos") and lobby.mode_btns.has("trios"),
		"the online lobby offers Trios and Solos and opens on the last pick (%s)" % lobby.mode
	)
	lobby.queue_free()
	Save.d["exp_mode"] = "trios"


## Both cards, each with its one plain line (Data.MODE_LINES).
func _cards(root: Node, where: String) -> void:
	ok(_card(root, "trios") != null and _card(root, "solos") != null, "%s: a Trios card and a Solos card" % where)
	var texts := _texts(root)
	ok(texts.has(Data.MODE_LINES["trios"]) and texts.has(Data.MODE_LINES["solos"]), "%s: one line per card" % where)


func _card(n: Node, mode: String) -> Control:
	if n.has_meta("mode") and n.get_meta("mode") == mode:
		return n
	for c in n.get_children():
		var f := _card(c, mode)
		if f:
			return f
	return null


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		out.append_array(_texts(c))
	return out
