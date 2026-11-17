class_name HobOffer
extends RefCounted
## A pick of Relics: Hob's second-Relic offer (HobTalk shows it over the talk box: the second pick still to make,
## Kael, Cinder and Meeko minus one already taken) and the first-Relic pick (Hatch: Lace, Kael or Vex), side by
## side, each with its portrait, name and title and a plain one-line role, and under them a loop of the Relic in
## focus on the training dummy: its attack, its signature ability ("signature" in the rules, else its right
## button) and its dash, one clip after the other (only one plays: the cards are painted portraits, so the pick
## never stalls). Hover a card to look at it; clicking it (or Enter on it) asks "Take Cinder?", and "Yes" picks it:
## `choose` opens it (ClassUnlock.choose_second or choose_starters) and `done` carries on (HobTalk plays the
## short Relic moment). "Back" (or Esc) closes the question.
## "Not now" lets it wait, when there is a `later` to call (the first pick has none).

const CARD_W := 230.0  # px
const FACE_PX := 110.0
const CLIP := Vector2(300, 130)  # px: the focused Mask's ability clip
const ASK_FACE_PX := 56.0  # the question's small portrait
const ASK_GAP := 28.0  # px: the question's distance from the screen's bottom edge
const ASK_LAYER := 100  # above every panel it can be asked over

var rules: Dictionary  # the farm builder's "talk" lines (title, roles, button text)
var title_key: String
var choose: Callable  # (id) -> bool: makes the pick
var done: Callable  # (id): the pick was made
var later: Callable  # () : "Not now" (invalid: no such button)
var ids: Array = []
var focus_i := 0
var cards: Array = []  # PanelContainer per id
var preview: Control  # holds the focused Mask's clips
var reel: Array = []  # the focused Mask's clips (attack, signature, dash); one shows at a time
var reel_i := 0
var turn: Timer  # one loop long: moves the reel on
var root: Control
var asking: Control  # the "Take Cinder?" question, while it is up (UI.Modal)
var yes_button: Button


func _init(
	offer_ids: Array,
	talk_rules: Dictionary,
	title: String,
	make_pick: Callable,
	on_done: Callable,
	on_later := Callable()
) -> void:
	ids = offer_ids
	rules = talk_rules
	title_key = title
	choose = make_pick
	done = on_done
	later = on_later


## The pick: the three cards, the focused Mask's clip and Not now.
func build() -> Control:
	var v := UI.vbox(12)
	v.set_meta("mask_offer", true)
	var head := UI.title(String(rules[title_key]), 26, UI.INK)
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
	if later.is_valid():
		var btns := UI.hbox(12)
		btns.alignment = BoxContainer.ALIGNMENT_CENTER
		btns.add_child(UI.ghost(String(rules["offer_later"]), later, 160))
		v.add_child(btns)
	root = v
	cards[0].call_deferred("grab_focus")  # (the arrow keys move along the cards, Enter asks about one)
	for id in ids:
		WardenGlb.fetch(String(id))  # (their models, read off the main thread before a clip needs one)
	focus(0)
	return v


func _card(id: String, i: int) -> PanelContainer:
	var col := Arch.color(id)
	var card := UI.card(Color(UI.NIGHT, 0.96), 12)
	card.custom_minimum_size.x = CARD_W
	card.set_meta("mask_card", id)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_entered.connect(func(): focus(i))
	card.focus_entered.connect(func(): focus(i))
	card.gui_input.connect(
		func(ev):
			var clicked: bool = ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
			var keyed: bool = (
				not ev.is_echo() and (ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact"))
			)
			if clicked or keyed:
				card.accept_event()
				ask(id)
	)
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
	var role := UI.para(String((rules["roles"] as Dictionary).get(id, "")), UI.T_SMALL, UI.MUTED)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.custom_minimum_size.x = CARD_W - 24.0
	role.set_meta("mask_role", id)
	v.add_child(role)
	v.add_child(ClassCard.howto_box(id, CARD_W - 24.0, 12))
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
	for slot in ["lmb", String((rules["signature"] as Dictionary).get(id, "rmb")), "dash"]:
		var clip := AbilityClip.make(id, slot, CLIP)
		preview.add_child(clip)
		reel.append(clip)
	turn = Timer.new()
	turn.wait_time = AbilityClip.LOOP_S
	turn.autostart = true
	turn.timeout.connect(func(): show_clip(reel_i + 1))
	preview.add_child(turn)
	show_clip(0)


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


## "Take Cinder?": a small question at the bottom centre (the cards stay in view), with the Relic's portrait,
## "Yes, take Cinder" and "Back". Esc is Back (UI.Modal). Anything not on offer is not asked about.
func ask(id: String) -> void:
	if is_instance_valid(asking) or not ids.has(id):
		return
	var name_txt := HeroTitle.base_name(id)
	var layer := CanvasLayer.new()
	layer.layer = ASK_LAYER
	asking = UI.Modal.new()
	asking.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	asking.mouse_filter = Control.MOUSE_FILTER_STOP  # (the cards behind wait while it is up)
	asking.tree_exited.connect(layer.queue_free)
	layer.add_child(asking)
	var panel := UI.card(Color(UI.NIGHT, 0.98), 14)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -ASK_GAP
	UI.set_card_border(panel, Color(Arch.color(id), 0.95), 2)
	asking.add_child(panel)
	var row := UI.hbox(14)
	panel.add_child(row)
	var face := ClassCard.portrait(id, ASK_FACE_PX)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var head := UI.title(String(rules["offer_ask"]).replace("{name}", name_txt), 22, UI.INK)
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(head)
	row.add_child(UI.ghost(String(rules["offer_back"]), asking.queue_free, 100))
	yes_button = UI.primary(String(rules["offer_yes"]).replace("{name}", name_txt), _yes.bind(id), 220)
	row.add_child(yes_button)
	root.add_child(layer)
	UI.pop_in(panel)
	yes_button.grab_focus.call_deferred()


func _yes(id: String) -> void:
	asking.queue_free()
	pick(id)


## Takes this Relic (once; anything not on offer is refused).
func pick(id: String) -> void:
	if not choose.call(id):
		return
	UI.pick_taken()
	done.call(id)
