class_name DuelRing
extends RefCounted
## The Training Grounds duel ring: stand on the pad and press interact for its choices. Find a duel
## queues the online 1v1 line (OnlineSession), Fight a bot enters the sparring room. There is no
## 1v1 friend invite to offer yet: the friends lobby is a many-squad expedition room.

var m: Match
var layer: CanvasLayer = null
var body: VBoxContainer = null
var session: OnlineSession = null

## Opens the ring's choices over the match and pauses it.
static func open(match_node: Match) -> DuelRing:
	var ring := DuelRing.new()
	ring.m = match_node
	ring._build()
	return ring

func _build() -> void:
	m.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	layer = CanvasLayer.new()
	layer.layer = 40
	layer.set_meta("ring", self)  # the pad drops open()'s return; the layer keeps the ring alive
	m.add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var pb := UI.scroll_panel("Duel ring", 520, close, "Back")
	center.add_child(pb[0])
	body = pb[1]
	UI.pop_in(pb[0])
	if OnlineSession.configured():
		session = OnlineSession.get_session()
		session.changed.connect(_fill)
		layer.tree_exiting.connect(_unhook)
	_fill()

## Leaves the ring and the line, and gives the match back.
func close() -> void:
	if session:
		session.cancel()
	layer.queue_free()
	m.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

## The match is going away (back to the game, or into the duel found): stop listening to the line.
func _unhook() -> void:
	session.changed.disconnect(_fill)

func _searching() -> bool:
	return session != null and session.state in ["region", "queue", "connect", "wait"]

func _fill() -> void:
	for ch in body.get_children():
		body.remove_child(ch)
		ch.queue_free()
	if _searching():
		_fill_searching()
		return
	body.add_child(UI.para("Pick how to fight.", UI.T_BODY, UI.INK))
	if session != null:
		var blurb := "Queue for a 1v1 against another hunter. A bot fills in if the wait runs out."
		_choice("Find a duel", blurb, _find, "knock")
	_choice("Fight a bot", "The sparring room: set up your opponent and watch your numbers.", _fight_bot, "gear")
	if session != null and session.state == "error":
		body.add_child(UI.para(session.message, UI.T_SMALL, UI.BAD))

func _choice(title: String, blurb: String, cb: Callable, icon: String) -> void:
	var row := UI.card(UI.CARD, 10, 12)
	var h := UI.hbox(12)
	row.add_child(h)
	var txt := UI.vbox(1)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_child(UI.label(title, UI.T_BODY, UI.INK, UI.semi))
	txt.add_child(UI.label(blurb, 13, UI.MUTED))
	h.add_child(txt)
	h.add_child(UI.button("Go", cb, 90, icon))
	body.add_child(row)

func _fill_searching() -> void:
	var line := "Searching for a duel..."
	if session.state == "queue":
		line = "Searching for a duel: number %d in line" % maxi(session.place, 1)
	elif session.state != "region":
		line = session.message
	body.add_child(UI.para(line, UI.T_BODY, UI.INK))
	if session.state == "queue" and session.eta_s > 0:
		var wait := "About %d seconds. A bot fills the seat when the wait runs out." % session.eta_s
		body.add_child(UI.para(wait, UI.T_SMALL, UI.MUTED))
	body.add_child(UI.button("Cancel search", session.cancel, 180, "close"))

func _find() -> void:
	session.queue_for("duel")

func _fight_bot() -> void:
	Game.start_match(Match.duel_opts())
