class_name HobTalk
extends RefCounted
## Talking to Hob face to face (FarmHob owns one; his lines: content/rules/farm_builder.json "talk"). Walk up and
## press interact: the talk box opens (TalkBox, his portrait and name), you both turn to each other and the
## camera eases toward him. What he says:
##   - the first time on a new farm: who he is, the stall, the house spot and the axe (the farm tutorial's start)
##   - while the tutorial runs: the step you're on, pointing at where it happens
##   - once the house is down and the second Mask is on offer (ClassUnlock.second_pending): "By the way..." and
##     the pick of three (HobOffer); taking one plays the short Mask moment (MaskBeat)
##   - otherwise: blueprints he drew up (FarmBuilder), then the build menu or goodbye
## When a line is about something (a "show"), he points at it and the camera looks there for a moment. On the
## first arrival the camera also swings over to him for a moment while he waves and calls you over.

const TALK := "Hob"            # Home.panel_open while you talk: you stand still and no prompt shows
const TALK_ZOOM := 0.8         # the home camera's zoom while you talk (Home.HOME_ZOOM after)
const EASE_S := 0.6            # s the camera takes to swing over to him and back on the first arrival
const FACE_K := 0.45           # how far the camera's focus moves from you toward him while you talk

var hob: FarmHob
var box: TalkBox = null
var offer: HobOffer = null
var intro_t := -1.0            # s into the first-arrival camera swing, -1 when none
var show_t := -1.0             # s into a line's look at something, -1 when none
var show_at := Vector3.INF

func _init(owner_hob: FarmHob) -> void:
	hob = owner_hob

func rules() -> Dictionary:
	return FarmBuilder.rules()["talk"]

func talking() -> bool:
	return box != null and is_instance_valid(box)

## Talking, or swinging the camera over on the first arrival (he holds his own pose then).
func busy() -> bool:
	return talking() or intro_t >= 0.0

## The second Mask is his to offer: it's on offer, and the house is down (or there is no tutorial).
func offer_due() -> bool:
	return ClassUnlock.second_pending() and (not FarmTutorial.active() or FarmTutorial.did("house"))

## Starts a conversation: what he has to say now (see the file's doc).
func start() -> void:
	if talking() or not is_instance_valid(hob.node):
		return
	var h = hob.h
	var first := not bool(FarmBuilder.state().get("met", false))
	var ids := FarmBuilder.draw_up()
	FarmTutorial.event("hob")
	Save.save_game()
	h.panel_open = TALK
	h.cam.zoom_to = TALK_ZOOM
	_screen_clear(false)
	box = TalkBox.open(h, FarmBuilder.full_name(), HobModel.portrait(TalkBox.FACE_PX))
	box.line_shown.connect(_on_line)
	box.closed.connect(_closed)
	if offer_due():
		box.say(_offer_lines(), _show_offer)
	elif first and FarmTutorial.active():
		box.say(rules()["intro_base" if FarmUnlocks.base_mode() else "intro"], box.close)
	elif FarmTutorial.current() != "" and FarmTutorial.current() != "hob":
		box.say(_step_lines(FarmTutorial.current()), box.close)
	else:
		box.say(_blueprint_lines(ids, first), _menu_choice)

func _step_lines(step: String) -> Array:
	return [{"text": FarmTutorial.hint_text(step), "at": hob.h.guide.target(step) if hob.h.guide else Vector3.INF}]

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
	offer = HobOffer.new(self)
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
	var at: Vector3 = line.get("at", _where(String(line.get("show", ""))))
	show_at = at
	show_t = 0.0 if at.x != INF else -1.0
	hob.node.point_at = at
	hob.node.pose = "point" if at.x != INF else String(line.get("pose", "talk"))

## Where a line's "show" is on this farm (INF when it isn't there).
func _where(what: String) -> Vector3:
	var h = hob.h
	match what:
		"stall":
			var stalls := HomeLayout.fixtures(Save.d, "stall")
			return HomeLayout.deco_center(stalls[0]) if not stalls.is_empty() else Vector3.INF
		"house":
			return h.guide.target("house") if h.guide else Vector3.INF
		"tree":
			return h.guide.target("chop") if h.guide else Vector3.INF
		"portal":
			return h.spots["portal"]
	return Vector3.INF

func _closed() -> void:
	var h = hob.h
	box = null
	offer = null
	show_t = -1.0
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
	if show_t >= 0.0:
		show_t += dt
		if show_t > float(rules()["show_s"]):
			show_t = -1.0
			if talking():
				hob.node.pose = "talk"
	_intro(dt)

## The first arrival: once the screen is clear, the camera swings over to him while he waves and calls you over.
func _intro(dt: float) -> void:
	var h = hob.h
	if intro_t < 0.0:
		var tut: Dictionary = Save.d["tutorial"]
		var clear: bool = h.panel_open == "" and not h.building_now and bool(tut.get("home", false))
		var met := bool(FarmBuilder.state().get("met", false))
		if met or bool(tut.get("hob_intro", false)) or not clear or not FarmTutorial.active():
			return
		tut["hob_intro"] = true
		intro_t = 0.0
		h.cam.zoom_to = TALK_ZOOM
		hob.node.pose = "wave"
		hob.node.face_to = h.ppos
		hob.node.shout(String(rules()["call"]))
		Sfx.play("ping", hob.node.position, -6.0)
		return
	intro_t += dt
	if intro_t > float(rules()["intro_pan_s"]) + EASE_S * 2.0:
		intro_t = -1.0
		h.cam.zoom_to = h.HOME_ZOOM

## The camera's focus: on you, drawn toward Hob while you talk (and toward what he points at), and over to him
## on the first arrival.
func frame(focus: Vector3) -> Vector3:
	if not is_instance_valid(hob.node):
		return focus
	var him := Vector3(hob.node.position.x, focus.y, hob.node.position.z)
	var at := focus
	if intro_t >= 0.0:
		var hold := float(rules()["intro_pan_s"])
		var k := smoothstep(0.0, EASE_S, intro_t) * (1.0 - smoothstep(EASE_S + hold, EASE_S * 2.0 + hold, intro_t))
		at = focus.lerp(him, k)
	elif talking() or offer != null:
		at = focus.lerp(him, FACE_K)
	if show_t >= 0.0 and show_at.x != INF:
		var span := float(rules()["show_s"])
		var k := smoothstep(0.0, 0.4, show_t) * (1.0 - smoothstep(span - 0.4, span, show_t))
		at = at.lerp(Vector3(show_at.x, focus.y, show_at.z), k)
	return at
