extends RefCounted
## --mute-check: muting a player (MuteList) for you only, this session.
##   1. the list: toggling, session-only (nothing in the save)
##   2. the lobby: a muted teammate's chat line is dropped and hidden, an unmuted one's shows; the squad
##      row's Mute button flips it; their voice frame is dropped, an unmuted one's plays
##   3. the match: a muted player's squad ping from the net is dropped, an unmuted one's arrives; the Tab
##      scoreboard shows a Mute chip for net players only, and a click on it flips the mute
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MUTE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	MuteList.clear()
	_list()
	await _lobby(main)
	await _match(main)
	MuteList.clear()
	print("MUTE CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _list() -> void:
	ok(not MuteList.has("Wren"), "nobody is muted at first")
	ok(MuteList.toggle("Wren") and MuteList.has("Wren") and not MuteList.has("Pike"), "toggling mutes that name only")
	ok(not MuteList.toggle("Wren") and not MuteList.has("Wren"), "toggling again unmutes")
	ok(not Save.fresh().has("muted"), "the save carries no mute list")

func _lobby(main: Node) -> void:
	var o := {"teams": 10, "squad": 2, "tier": 0}
	Prematch.deal_mates(o)
	var view: Control = load("res://scripts/ui/prematch_view.gd").new()
	view.setup(o)
	main.add_child(view)
	await main.get_tree().process_frame
	view.pm.squad[1].merge({"name": "Wren", "peer": "p1", "bot": false}, true)     # the bot mate stands in for a player
	view._fill_squad()
	var chat := func(t: String) -> void: view._on_msg("chat", {"name": "Wren", "t": t}, "p1")
	chat.call("one")
	await main.get_tree().process_frame
	ok(_shown(view) == 1, "an unmuted teammate's chat line shows")
	var btn := _mute_button(view)
	ok(btn != null and btn.text == "Mute", "their squad row has a Mute button")
	btn.pressed.emit()
	ok(MuteList.has("Wren") and btn.text == "Muted" and _shown(view) == 0, "Mute silences them, hides old lines")
	chat.call("two")
	await main.get_tree().process_frame
	ok(_shown(view) == 0, "a muted teammate's chat line is dropped")
	var played: Array = []
	var voice := VoiceChat.new()
	voice.sink = func(from: String, _frame): played.append(from)
	var frame := PackedByteArray([1])
	ok(not voice.receive("Wren", frame) and played.is_empty(), "a muted teammate's voice frame is dropped")
	btn.pressed.emit()
	chat.call("three")
	await main.get_tree().process_frame
	ok(btn.text == "Mute" and _shown(view) == 2, "unmuting brings the first line back, a new one arrives")
	ok(voice.receive("Wren", frame) and played == ["Wren"], "an unmuted teammate's voice frame plays")
	view.queue_free()

func _shown(view: Control) -> int:
	return view.chat_log.get_children().filter(func(l): return l.visible).size()

func _mute_button(view: Control) -> Button:
	for chip in view.squad_box.get_children():
		for n in chip.find_children("*", "Button", true, false):
			return n
	return null

func _match(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var mate: Hunter = m.hunters.filter(func(h): return h != m.player and h.team == m.player.team)[0]
	var at: Vector3 = m.player.pos
	MuteList.toggle(mate.pname)
	m.squad_ping(mate, at, true)
	ok(m.pings.filter(func(q): return q.get("by") == mate).is_empty(), "a muted player's ping from the net is dropped")
	MuteList.toggle(mate.pname)
	m.squad_ping(mate, at, true)
	ok(m.pings.filter(func(q): return q.get("by") == mate).size() == 1, "an unmuted player's ping from the net arrives")
	var bot: Hunter = m.hunters.filter(func(h): return h != m.player and h != mate)[0]
	mate.ctrl = "remote"
	Input.action_press("scores")
	for i in 3:
		await main.get_tree().process_frame
	var chips: Dictionary = m.hud.score_mute.rects
	var others: bool = chips.has(bot.pname) or chips.has(m.player.pname)
	ok(chips.has(mate.pname) and not others, "the scoreboard has a Mute chip for net players only")
	var hit: Vector2 = (chips[mate.pname] as Rect2).get_center()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	ok(m.hud.score_mute.click(click, hit) and MuteList.has(mate.pname), "a click on the chip mutes them")
	var sm: ScoreMute = m.hud.score_mute
	ok(sm.over(hit) and not sm.over(Vector2(-5, -5)), "the chip owns the click: no shot through it")
	ok(m.hud.score_mute.click(click, hit) and not MuteList.has(mate.pname), "a second click unmutes")
	Input.action_release("scores")
	m.queue_free()
