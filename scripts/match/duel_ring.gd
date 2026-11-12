class_name DuelRing
extends RefCounted
## The Training Grounds duel ring: stand on the pad and press interact for its two ways to fight 1v1.
## Fight a bot opens the duel room's sparring bot; Duel online opens the Play online lobby on its duel
## line (scripts/ui/lobby.gd), where a friend who does the same, or the next hunter in line, is your rival.

var m: Match
var layer: CanvasLayer = null

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
	layer.set_meta("ring", self)      # the pad drops open()'s return; the layer keeps the ring alive
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
	var body: VBoxContainer = pb[1]
	UI.pop_in(pb[0])
	body.add_child(UI.para("Pick who you fight, one on one.", UI.T_BODY, UI.INK))
	_choice(body, "Fight a bot", "The duel room: set up your opponent and watch your numbers.", fight_bot, "gear")
	var online := "Join the duel line in Play online. A friend who joins it too, or the next hunter waiting,"
	online += " is your rival."
	_choice(body, "Duel online", online, duel_online, "bond")

## Leaves the ring and gives the match back.
func close() -> void:
	layer.queue_free()
	m.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _choice(body: VBoxContainer, title: String, blurb: String, cb: Callable, icon: String) -> void:
	var row := UI.card(UI.CARD, 10, 12)
	var h := UI.hbox(12)
	row.add_child(h)
	var txt := UI.vbox(1)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_child(UI.label(title, UI.T_BODY, UI.INK, UI.semi))
	var sub := UI.label(blurb, 13, UI.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_child(sub)
	h.add_child(txt)
	h.add_child(UI.button("Go", cb, 90, icon))
	body.add_child(row)

func fight_bot() -> void:
	Game.start_match(Match.duel_opts())

func duel_online() -> void:
	Game.goto("lobby", {"duel": true})
