class_name PartyView
extends Control
## The party screen (docs/specs/PARTY.md): make a party or join one with a code, see the three seats, ready up.
## Expeditions are always trios: the leader's Find match queues whoever is here and the matchmaker fills the
## rest. A fourth friend is refused ("full") and waits for the next expedition. The state is Net.party's.

const SEATS := 3                 # an expedition squad (Extraction is always trios)
const CODE_LEN := 5              # characters in an invite code
const TAG_COLORS := {"Ready": UI.GOOD, "Leader": UI.GOLD, "Not ready": UI.MUTED}
const ENDED := {
	"gone": "Your party ended.",
	"dropped": "You are no longer in that party.",
	"ticket": "Your search ended.",
}
const ERRORS := {
	"tutorial": "Finish the tutorial first.",
	"not_found": "No party has that code.",
	"full": "That party has 3 already. One friend waits for the next expedition.",
	"busy": "That party is already out on an expedition.",
	"version": "Update the game to play with this party.",
	"rate_limited": "Too many tries. Wait a minute.",
	"not_ready": "Everyone else has to be ready first.",
	"network": "Can't reach the matchmaker.",
}

var party: Party
var body: VBoxContainer
var note := ""                   # why the party ended, shown until the next action
var code_in: LineEdit

func setup(_opts: Dictionary) -> void:
	party = Net.party

## The three seats for a party card: one dictionary per seat, open seats last.
## {name, hunter, tags}; `my_hunter` is your own pick (the matchmaker does not send the others').
static func seats(members: Array, my_hunter: String) -> Array:
	var out: Array = []
	for m in members:
		var tags: Array = []
		if m["leader"]:
			tags.append("Leader")
		if m["ready"]:
			tags.append("Ready")
		elif not m["leader"]:
			tags.append("Not ready")
		out.append({"name": m["name"], "hunter": my_hunter if m["you"] else "Picks at the drop", "tags": tags})
	while out.size() < SEATS:
		out.append({"name": "Open seat", "hunter": "A friend or a stranger takes it", "tags": []})
	return out

func _ready() -> void:
	Sfx.play_music("title")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var pb := UI.scroll_panel("Party", 560, func(): Game.goto("title"), "Back")
	center.add_child(pb[0])
	UI.pop_in(pb[0])
	UI.subtitle(pb[1], "Expeditions take 3. We fill the rest.")
	body = UI.vbox(10)
	pb[1].add_child(body)
	party.changed.connect(_refresh)
	party.ended.connect(_on_ended)
	_refresh()

func _exit_tree() -> void:
	if party.changed.is_connected(_refresh):
		party.changed.disconnect(_refresh)
		party.ended.disconnect(_on_ended)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("menu") and not Overlay.is_open():
		get_viewport().set_input_as_handled()
		Game.goto("title")

func _on_ended(why: String) -> void:
	note = ENDED.get(why, "")
	_refresh()

func _refresh() -> void:
	for c in body.get_children():
		c.queue_free()
	if party.state == Party.State.NONE:
		_build_start()
	else:
		_build_card()
	if note != "":
		body.add_child(UI.para(note, UI.T_SMALL, UI.ACCENT_HI))
	elif party.error != "":
		body.add_child(UI.para(ERRORS.get(party.error, "Something went wrong. Try again."), UI.T_SMALL, UI.ACCENT_HI))

func _named(node: Control, id: String) -> Control:
	node.name = id
	return node

func _build_start() -> void:
	var can := Party.can_join()
	var intro := "Make a party and share its code, or join a friend's."
	body.add_child(UI.para(intro if can else ERRORS["tutorial"]))
	var make := _named(UI.primary("Make a party", _make, 200, "bond"), "MakeBtn") as Button
	make.disabled = not can
	body.add_child(make)
	body.add_child(UI.section("Join with a code"))
	var row := UI.hbox(8)
	code_in = LineEdit.new()
	code_in.name = "CodeIn"
	code_in.max_length = CODE_LEN
	code_in.placeholder_text = "Invite code"
	code_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_in.text_submitted.connect(func(_t): _join())
	row.add_child(code_in)
	var join := _named(UI.button("Join", _join, 120), "JoinBtn") as Button
	join.disabled = not can
	row.add_child(join)
	body.add_child(row)

func _build_card() -> void:
	if party.code != "":
		var head := UI.hbox(10)
		head.add_child(UI.label("Invite code", UI.T_SMALL, UI.MUTED))
		var shown := UI.label(party.code, 28, UI.GOLD, UI.big)
		shown.name = "Code"
		shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(shown)
		head.add_child(UI.ghost("Copy", func(): DisplayServer.clipboard_set(party.code)))
		body.add_child(head)
	var mine := ClassUnlock.online_arch(Arch.of_save())
	var list := UI.vbox(6)
	for i in SEATS:
		list.add_child(_seat_row(i, seats(party.members, Arch.label(mine))[i]))
	body.add_child(list)
	body.add_child(UI.para(_status_line()))
	body.add_child(_actions())

func _seat_row(i: int, seat: Dictionary) -> Control:
	var open: bool = seat["name"] == "Open seat"
	var row := UI.card(UI.CARD, 10, 12)
	row.name = "Seat%d" % i
	var h := UI.hbox(12)
	row.add_child(h)
	var who := UI.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UI.label(seat["name"], UI.T_BODY, UI.FAINT if open else UI.INK, UI.semi))
	who.add_child(UI.label(seat["hunter"], 14, UI.MUTED))
	h.add_child(who)
	for t in seat["tags"]:
		h.add_child(UI.tag(t, TAG_COLORS[t]))
	return row

func _status_line() -> String:
	if party.state == Party.State.PLAYING:
		return "Joining the expedition..."
	if party.state == Party.State.QUEUED:
		return "Looking for a squad. Place %d in line, about %d seconds." % [party.queue_position, party.eta_s]
	if party.members.size() >= SEATS:
		return "Three in. A fourth friend waits for the next expedition."
	return "Not full? We fill the rest with other hunters."

func _actions() -> Control:
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END
	var leave := _named(UI.ghost("Leave party", _leave, 0, "back"), "LeaveBtn")
	row.add_child(leave)
	if party.state == Party.State.PLAYING:
		return row
	if party.state == Party.State.QUEUED:
		if party.is_leader():
			row.add_child(_named(UI.button("Cancel search", func(): await party.cancel_queue(), 160), "CancelBtn"))
	elif party.is_leader():
		var others_ready := party.members.all(func(m): return m["ready"] or m["you"])
		var find := _named(UI.primary("Find match", _ready_up, 180, "portal"), "FindBtn") as Button
		find.disabled = not others_ready
		row.add_child(find)
	else:
		var text := "I'm not ready" if party.is_ready() else "I'm ready"
		row.add_child(_named(UI.primary(text, func(): _ready_up(not party.is_ready()), 180, "check"), "ReadyBtn"))
	return row

func _make() -> void:
	note = ""
	await party.create()
	_refresh()

func _join() -> void:
	note = ""
	await party.join(code_in.text)
	_refresh()

func _ready_up(on := true) -> void:
	await party.set_ready(on)
	_refresh()

func _leave() -> void:
	note = ""
	await party.leave()
