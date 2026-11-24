class_name SquadChat
extends Control
## Squad text chat in an online match. Enter types, Enter sends, Esc closes. The last SHOWN lines stay
## FADE_S seconds, then fade; nothing is on screen until someone writes. A line rides Net.chat (the match
## room): the relay hands it to everyone in the room, so each client keeps it only when the sender is on
## its own team and not muted (MuteList). The lobby has its own one-line chat (PrematchView).

const TOPIC := "chat"
const SHOWN := 5            # lines on screen at once
const FADE_S := 8.0         # s a line stays fully visible
const FADE_OUT_S := 1.0     # s it then takes to fade away
const FONT := 18            # px

var roster: Array = []      # online roster entries {peer, name, team}
var me := ""                # my peer id
var m: Match = null         # while typing your Hunter holds still (Match.paused)
var send: Callable = Net.chat
var typing := false
var input: LineEdit
var box: VBoxContainer


## Puts chat under `parent` when this is an online squad (opts["net"] carries the roster); else nothing.
static func attach(parent: Node, opts: Dictionary, in_match: Match) -> SquadChat:
	if not opts.has("net"):
		return null
	var c := SquadChat.new()
	c.roster = opts["net"].get("roster", [])
	c.me = Net.me
	c.m = in_match
	parent.add_child(c)
	return c


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_top = 0.55
	box.anchor_bottom = 0.55
	box.offset_left = 18.0
	box.offset_right = 520.0
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(box)
	input = LineEdit.new()
	input.max_length = Prematch.CHAT_MAX
	input.placeholder_text = "Tell your squad (Enter sends, Esc closes)"
	input.add_theme_font_size_override("font_size", FONT)
	input.text_submitted.connect(_submit)
	input.visible = false
	box.add_child(input)
	Net.message.connect(receive)


func _exit_tree() -> void:
	if Net.message.is_connected(receive):
		Net.message.disconnect(receive)
	if typing:
		close()


func _process(delta: float) -> void:
	for l in box.get_children():
		if l == input:
			continue
		var age: float = l.get_meta("age") + delta
		l.set_meta("age", age)
		l.modulate.a = 1.0 if typing else clampf((FADE_S + FADE_OUT_S - age) / FADE_OUT_S, 0.0, 1.0)
	if typing and Overlay.is_open():
		close()


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo or k.physical_keycode not in [KEY_ENTER, KEY_KP_ENTER]:
		return
	if team_of(me) >= 0 and not typing and not Overlay.is_open():
		open()
		get_viewport().set_input_as_handled()


func _input(e: InputEvent) -> void:
	if typing and e.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()


func lines_shown() -> int:
	return box.get_child_count() - 1


func team_of(peer: String) -> int:
	for r in roster:
		if String(r["peer"]) == peer:
			return int(r["team"])
	return -1


func name_of(peer: String) -> String:
	for r in roster:
		if String(r["peer"]) == peer:
			return String(r["name"])
	return "Hunter"


## A chat message from the relay: shown when the sender is a teammate and not muted.
func receive(topic: String, data, from: String) -> void:
	if topic != TOPIC or typeof(data) != TYPE_DICTIONARY or from == me or team_of(me) < 0:
		return
	var who := name_of(from)
	if team_of(from) == team_of(me) and not MuteList.has(who):
		show_line(who, Prematch.clean_chat(String(data.get("t", ""))), UI.INK)


func open() -> void:
	typing = true
	input.visible = true
	input.grab_focus.call_deferred()
	if m:
		m.paused = true


func close() -> void:
	typing = false
	input.clear()
	input.visible = false
	input.release_focus()
	if m and not Overlay.is_open():
		m.paused = false


func show_line(who: String, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = "%s: %s" % [who, text]
	l.add_theme_font_size_override("font_size", FONT)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("age", 0.0)
	box.add_child(l)
	box.move_child(l, box.get_child_count() - 2)      # above the input row
	while lines_shown() > SHOWN:
		var oldest := box.get_child(0)
		box.remove_child(oldest)
		oldest.queue_free()


func _submit(text: String) -> void:
	text = Prematch.clean_chat(text)
	close()
	if text != "":
		show_line(name_of(me), text, UI.ACCENT_HI)
		send.call({"t": text})
