extends RefCounted
## --squad-chat-check: squad text chat (SquadChat). Four clients with their own peer ids, two squads of
## two, joined by a loopback that works like the relay (a line goes to everyone but the sender, tagged
## with the sender's peer id): a line typed by one Hunter reaches the teammate and neither rival. Also:
## nothing on screen until someone writes, Enter opens and Esc closes, five lines at most, a line fades
## after 8 s, a muted player (MuteList), one cleaned line, and no chat for an offline squad.

const ROSTER := [
	{"peer": "1", "name": "Ada", "team": 0}, {"peer": "2", "name": "Bo", "team": 0},
	{"peer": "3", "name": "Cy", "team": 1}, {"peer": "4", "name": "Di", "team": 1},
]
var bad := 0
var clients: Array = []

func ok(cond: bool, what: String) -> void:
	print("SQUADCHAT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	MuteList.clear()
	_join_all(main)
	var ada: SquadChat = clients[0]
	var bo: SquadChat = clients[1]
	ok(ada.lines_shown() == 0 and not ada.input.visible, "nothing is on screen until someone writes")
	_enter(ada)
	ok(ada.typing and ada.input.visible, "Enter opens the input")
	_esc(ada)
	ok(not ada.typing and not ada.input.visible, "Esc closes it")
	_say(ada, "push north")
	ok(ada.lines_shown() == 1 and bo.lines_shown() == 1, "the line shows to the sender and the teammate")
	ok(clients[2].lines_shown() == 0 and clients[3].lines_shown() == 0, "and not to either rival")
	ok(_text(bo, 0) == "Ada: push north", "the teammate sees who said it (%s)" % _text(bo, 0))
	_say(clients[2], "rival here")
	var shown := clients.map(func(c): return c.lines_shown())
	var di := _text(clients[3], 0)
	var kept := _text(bo, 0) == "Ada: push north"
	ok(shown == [1, 1, 1, 1] and di == "Cy: rival here" and kept, "a rival's line reaches only its own teammate")
	_fade(bo)
	_mute_cap_off()
	_offline(main)
	for c in clients:
		c.free()
	MuteList.clear()
	print("SQUADCHAT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _join_all(main: Node) -> void:
	for r in ROSTER:
		var c := SquadChat.new()
		c.roster = ROSTER
		c.me = String(r["peer"])
		main.add_child(c)
		c.send = func(d): _relay(c, d)
		clients.append(c)

## What relay.gd does with a match or lobby emit: everyone but the sender gets it, "from" is the sender.
func _relay(sender: SquadChat, d: Dictionary) -> void:
	for c in clients:
		if c != sender:
			c.receive(SquadChat.TOPIC, d, sender.me)

func _say(c: SquadChat, text: String) -> void:
	_enter(c)
	c.input.text = text
	c.input.text_submitted.emit(text)

func _enter(c: SquadChat) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = KEY_ENTER
	k.pressed = true
	c._unhandled_input(k)

func _esc(c: SquadChat) -> void:
	var a := InputEventAction.new()
	a.action = "menu"
	a.pressed = true
	c._input(a)

func _text(c: SquadChat, i: int) -> String:
	return (c.box.get_child(i) as Label).text

func _fade(bo: SquadChat) -> void:
	var line := bo.box.get_child(0) as Label
	bo._process(SquadChat.FADE_S - 0.5)
	ok(line.modulate.a == 1.0, "a line is fully there just before 8 s")
	bo._process(SquadChat.FADE_OUT_S + 1.0)
	ok(line.modulate.a == 0.0, "and gone once it has faded")
	_enter(bo)
	bo._process(0.0)
	ok(line.modulate.a == 1.0, "typing brings the recent lines back")
	_esc(bo)

func _mute_cap_off() -> void:
	var ada: SquadChat = clients[0]
	var bo: SquadChat = clients[1]
	var before := ada.lines_shown()
	MuteList.toggle("Bo")
	_say(bo, "hi")
	ok(MuteList.has("Bo") and ada.lines_shown() == before, "a muted teammate's line is hidden")
	MuteList.toggle("Bo")
	_say(bo, "hi again")
	ok(_text(ada, ada.lines_shown() - 1) == "Bo: hi again", "unmuted, they can talk again")
	for i in 8:
		_say(bo, "line %d" % i)
	ok(ada.lines_shown() == SquadChat.SHOWN, "at most %d lines at once" % SquadChat.SHOWN)
	var capped := Prematch.clean_chat("x".repeat(500)).length()
	ok(Prematch.clean_chat("  a\nb  ") == "a b" and capped == Prematch.CHAT_MAX, "a line is one trimmed line, capped")


func _offline(main: Node) -> void:
	ok(SquadChat.attach(main, {"squad": 2}) == null, "an offline squad gets no chat")
