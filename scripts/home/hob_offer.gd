class_name HobOffer
extends RefCounted
## Hob's second-Mask offer (HobTalk shows it over the talk box): exactly the three Masks of the second pick
## (ClassUnlock.second_picks: Kael, Meeko, Cinder) side by side, each with its portrait, name and title and a
## plain one-line role, and under them a loop of the Mask in focus on the training dummy: its attack, its
## signature ability ("signature" in the rules) and its dash, one clip after the other (only one plays: the
## cards are painted portraits, so the pick never stalls). Hover or click a card to look at it; "Take" picks it,
## ClassUnlock.choose_second opens it, and HobTalk plays the short Mask moment. "Not now" lets it wait.

const CARD_W := 230.0          # px
const FACE_PX := 110.0
const CLIP := Vector2(300, 130)      # px: the focused Mask's ability clip

var chat: HobTalk
var ids: Array = []
var focus_i := 0
var cards: Array = []          # PanelContainer per id
var preview: Control           # holds the focused Mask's clips
var reel: Array = []           # the focused Mask's clips (attack, signature, dash); one shows at a time
var reel_i := 0
var turn: Timer                # one loop long: moves the reel on
var take_button: Button
var root: Control

func _init(talk: HobTalk) -> void:
	chat = talk
	ids = ClassUnlock.second_picks()

## The pick: the three cards, the focused Mask's clip, Take and Not now.
func build() -> Control:
	var v := UI.vbox(12)
	v.set_meta("mask_offer", true)
	var head := UI.title(String(chat.rules()["offer_title"]), 26, UI.INK)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in ids.size():
		var card := _card(String(ids[i]), i)
		cards.append(card)
		row.add_child(card)
	preview = CenterContainer.new()
	preview.custom_minimum_size.y = CLIP.y + 48.0
	v.add_child(preview)
	var btns := UI.hbox(12)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_child(UI.ghost(String(chat.rules()["offer_later"]), chat.later, 160))
	take_button = UI.primary("", func(): pick(String(ids[focus_i])), 260)
	btns.add_child(take_button)
	v.add_child(btns)
	root = v
	take_button.call_deferred("grab_focus")      # (Enter takes the Relic in focus)
	for id in ids:
		WardenGlb.fetch(String(id))      # (their models, read off the main thread before a clip needs one)
	focus(0)
	return v

func _card(id: String, i: int) -> PanelContainer:
	var col := Arch.color(id)
	var card := UI.card(Color(0.07, 0.065, 0.1, 0.96), 12)
	card.custom_minimum_size.x = CARD_W
	card.set_meta("mask_card", id)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func(): focus(i))
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.double_click:
			pick(id))
	var v := UI.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var face := ClassCard.portrait(id, FACE_PX)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(face)
	var nm := UI.label(HunterViewer.display_name(id), 19, col, UI.semi)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size.x = CARD_W - 24.0
	v.add_child(nm)
	var role := UI.para(String((chat.rules()["roles"] as Dictionary).get(id, "")), UI.T_SMALL, UI.MUTED)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.custom_minimum_size.x = CARD_W - 24.0
	role.set_meta("mask_role", id)
	v.add_child(role)
	return card

## Puts the focus on the i-th Mask: its card lights up and its clip plays under the cards.
func focus(i: int) -> void:
	focus_i = posmod(i, ids.size())
	var id := String(ids[focus_i])
	for j in cards.size():
		var edge := Arch.color(String(ids[j]))
		if j == focus_i:
			UI.set_card_border(cards[j], Color(edge, 0.95), 2)
		else:
			UI.set_card_border(cards[j], Color(edge, 0.25), 1)
	for c in preview.get_children():
		c.queue_free()
	reel.clear()
	for slot in ["lmb", String((chat.rules()["signature"] as Dictionary).get(id, "rmb")), "dash"]:
		var clip := AbilityClip.make(id, slot, CLIP)
		preview.add_child(clip)
		reel.append(clip)
	turn = Timer.new()
	turn.wait_time = AbilityClip.LOOP_S
	turn.autostart = true
	turn.timeout.connect(func(): show_clip(reel_i + 1))
	preview.add_child(turn)
	show_clip(0)
	take_button.text = String(chat.rules()["offer_take"]).replace("{name}", HeroTitle.base_name(id))

## Shows the k-th clip of the reel from its start; the others wait (a clip not built yet keeps building).
func show_clip(k: int) -> void:
	reel_i = posmod(k, reel.size())
	for j in reel.size():
		var clip: AbilityClip = reel[j]
		clip.visible = j == reel_i
		if clip.model != null:
			clip.play(j == reel_i)
	(reel[reel_i] as AbilityClip).restart()
	if turn.is_inside_tree():
		turn.start()

## Takes this Mask (once; anything not on offer is refused).
func pick(id: String) -> void:
	if not ClassUnlock.choose_second(id):
		return
	Sfx.play("unlock", null, -6.0)
	chat.taken(id)
