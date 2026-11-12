class_name HobTalk
extends RefCounted
## Talking to Hob face to face (FarmHob owns one; his lines: content/rules/farm_builder.json "talk"). Walk up and
## press interact: the talk box opens (TalkBox, his portrait and name), you both turn to each other and the
## camera eases toward him. What he says:
##   - once the tutorial is over and the second Mask is on offer (ClassUnlock.second_pending): "By the way..." and
##     the pick of three (HobOffer); taking one plays the short Mask moment (MaskBeat)
##   - otherwise: blueprints he drew up (FarmBuilder), then the build menu or goodbye
## When a line is about something (a "show"), he points at it and the camera looks there for a moment.

const TALK := "Hob"            # Home.panel_open while you talk: you stand still and no prompt shows
const TALK_ZOOM := 0.8         # the home camera's zoom while you talk (Home.HOME_ZOOM after)
const FACE_K := 0.45           # how far the camera's focus moves from you toward him while you talk

var hob: FarmHob
var box: TalkBox = null
var offer: HobOffer = null

func _init(owner_hob: FarmHob) -> void:
	hob = owner_hob

func rules() -> Dictionary:
	return FarmBuilder.rules()["talk"]

func talking() -> bool:
	return box != null and is_instance_valid(box)

## The second Mask is his to offer: it's on offer and the tutorial is over.
func offer_due() -> bool:
	return ClassUnlock.second_pending() and not FarmTutorial.active()

## Starts a conversation: what he has to say now (see the file's doc).
func start() -> void:
	if talking() or not is_instance_valid(hob.node):
		return
	var h = hob.h
	var first := not bool(FarmBuilder.state().get("met", false))
	var ids := FarmBuilder.draw_up()
	Save.save_game()
	h.panel_open = TALK
	h.cam.zoom_to = TALK_ZOOM
	_screen_clear(false)
	box = TalkBox.open(h, FarmBuilder.full_name(), HobModel.portrait(TalkBox.FACE_PX))
	box.line_shown.connect(_on_line)
	box.closed.connect(_closed)
	if offer_due():
		box.say(_offer_lines(), _show_offer)
	else:
		box.say(_blueprint_lines(ids, first), _menu_choice)

func _blueprint_lines(ids: Array, first: bool) -> Array:
	var out: Array = [{"text": FarmBuilder.line_for(ids, first)}]
	if not ids.is_empty():
		var names: Array = ids.map(func(i): return FarmUnlocks.name_of(String(i)))
		out.append({"text": "New blueprints: " + ", ".join(names) + "."})
	return out

func _offer_lines() -> Array:
	var worn := ClassUnlock.picks()
	var first_mask := HeroTitle.base_name(String(worn[0]) if not worn.is_empty() else "gunslinger")
	var out: Array = []
	for line in rules()["offer"]:
		out.append({"text": String(line["text"]).replace("{mask}", first_mask)})
	return out

## After the blueprint lines: open the build menu, or say goodbye.
func _menu_choice() -> void:
	var row := UI.hbox(12)
	row.add_child(UI.primary(String(rules()["build_menu"]), func():
		box.close()
		if hob.h.hb and not hob.h.hb.active:
			hob.h.hb.toggle(), 260))
	row.add_child(UI.ghost(String(rules()["bye"]), box.close, 140))
	box.show_extra(row)

func _show_offer() -> void:
	offer = HobOffer.new((ClassUnlock.state().get("second", []) as Array).duplicate(), rules(), "offer_title",
			ClassUnlock.choose_second, taken, later)
	box.show_extra(offer.build())

## The Mask is chosen (HobOffer): he hands it over and the short Mask moment plays.
func taken(id: String) -> void:
	box.clear_extra()
	box.say([{"text": String(rules()["offer_taken"])}], func(): _put_on(id))

## Not now: the offer waits (he keeps the "!" and calls now and then).
func later() -> void:
	box.clear_extra()
	box.say([{"text": String(rules()["offer_wait"])}], box.close)

func _put_on(id: String) -> void:
	box.close()
	var h = hob.h
	h.panel_open = TALK      # (you stay still through the Mask moment)
	_screen_clear(false)
	var relic := MaskRelic.make(id)
	h.add_child(relic)
	var hands := hob.node.global_position - hob.node.global_basis.z * 0.5 + Vector3.UP * 1.2
	relic.global_position = hands
	hob.node.pose = "idle"
	MaskBeat.play(relic, h.player, func(_body): _after_beat(id), false, true)

func _after_beat(id: String) -> void:
	ClassUnlock.reveal_done(id)      # (the beat was its reveal)
	Save.save_game()
	var h = hob.h
	if h.panel_open == TALK:
		h.panel_open = ""
	h.cam.zoom_to = h.HOME_ZOOM
	_screen_clear(true)
	h._refresh_top()

func _on_line(_i: int, line: Dictionary) -> void:
	hob.node.pose = String(line.get("pose", "talk"))

func _closed() -> void:
	var h = hob.h
	box = null
	offer = null
	if h.panel_open == TALK:
		h.panel_open = ""
	h.cam.zoom_to = h.HOME_ZOOM
	_screen_clear(true)
	if h.guide:
		h.guide.refresh()

## The hub bar and the goal line step aside while you talk (shown: true puts them back).
func _screen_clear(shown: bool) -> void:
	var h = hob.h
	if h.hub:
		h.hub.visible = shown
	if h.guide:
		h.guide.set_quiet(not shown)
	for label in [hob.node.tag, hob.node.mark, hob.node.bubble]:
		label.modulate.a = 1.0 if shown else 0.0

# ------------------------------------------------------------------ every frame
func tick(dt: float) -> void:
	var h = hob.h
	if talking():
		if h.panel_open != TALK:      # (Esc closed it)
			box.close()
			return
		hob.node.face_to = h.ppos
		var to: Vector3 = hob.node.position - h.ppos
		h.pface = atan2(-to.x, -to.z)

## The camera's focus: on you, drawn toward Hob while you talk.
func frame(focus: Vector3) -> Vector3:
	if not is_instance_valid(hob.node):
		return focus
	var him := Vector3(hob.node.position.x, focus.y, hob.node.position.z)
	var at := focus
	if talking() or offer != null:
		at = focus.lerp(him, FACE_K)
	return at
