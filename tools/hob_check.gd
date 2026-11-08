extends RefCounted
## --hob-check: Hob is a person on the farm and talks face to face (item 89), and the second Mask comes from him
## (item 87). FarmHob, HobModel, HobTalk, HobOffer, TalkBox; lines in content/rules/farm_builder.json "talk".
##   1. a new farm: Hob (the HobModel) waits by the market stall with his name over him; the first goal is to
##      meet him and the reminder line names him
##   2. the first arrival: the camera swings over to him while he waves and calls out, then comes back
##   3. talking: the talk box with his portrait and name, one line at a time; you stand still; he points at the
##      stall and the camera looks there; after the last line he is met (no name tag) and the axe is next
##   4. the second Mask: no second Mask on a fresh save after the first expedition; not offered before the house
##      is down, then a "!" and "By the way... I see you found a Vex Relic"; the pick shows exactly Kael, Meeko and
##      Cinder, each with portrait, name and title and a role, and one clip (the one in focus); taking Meeko opens
##      her (and nothing else) and the short Mask moment plays; no reveal pops up after it
##   5. "Not now" keeps the offer; a save that already owns a second Mask is never offered one
## With --shots-dir=<dir> (a renderer): hob_1_calls_you_over, hob_2_camera_intro, hob_3_dialogue_box,
## hob_4_points_at_stall, hob_5_offer_line, hob_6_three_masks, hob_7_mask_moment, hob_8_mask_name.

const SECOND := ["juggernaut", "tender", "ashwick"]

var main: Node
var bad := 0
var shots := ""
var home = null

func ok(cond: bool, what: String) -> void:
	print("HOBCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	if main.fade:
		main.fade.reveal(0.05)
	main.get_tree().root.size = Vector2i(1280, 720)      # (the smallest screen we lay out for)
	await _first_arrival()
	await _offer()
	await _later_and_legacy()
	print("HOBCHECK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A new farm after the tutorial expedition, Vex worn, the second Mask on offer.
func _new_farm(tutorial := true) -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	if not tutorial:
		d["tutorial"]["day1_done"] = true
	Save.d = d
	HomeLayout.ensure(Save.d)      # (a farm-start island)
	d["tutorial"]["home"] = true     # (the welcome is behind us)
	ClassUnlock.choose_starters(["gunslinger"])
	Game.apply_result({"arch": "gunslinger", "extracted": true, "why": "extracted", "knocks": 0, "kills": 0,
			"gems": 0, "seeds": {}, "stats": {}, "lvl": 1, "caught": [], "kin_runs": [], "tonics": 0, "tutorial": true})
	if home:
		home.queue_free()
		await main.get_tree().process_frame
	home = await main._hb_home()
	await _wait(func(): return home.hob != null and is_instance_valid(home.hob.node), 10.0)
	home._close_panel()

func _first_arrival() -> void:
	await _new_farm()
	var hob: FarmHob = home.hob
	var stall := HomeLayout.deco_center(HomeLayout.fixtures(Save.d, "stall")[0])
	ok(hob.node is HobModel and Vector2(hob.node.position.x - stall.x, hob.node.position.z - stall.z).length() < 4.0,
			"Hob is a person standing by the market stall")
	ok(hob.node.tag.visible and hob.node.tag.text == FarmBuilder.full_name(), "his name shows over him")
	ok(FarmTutorial.current() == "hob" and home.guide.hint_lbl.text.contains("Hob")
			and not home.guide.hint_lbl.text.contains("Hob:"),
			"the first goal: meet him (%s)" % home.guide.hint_lbl.text)
	ok(ClassUnlock.second_pending() and ClassUnlock.open_ids() == ["gunslinger"],
			"after the first expedition no second Mask is owned yet")
	# 2. the camera swing
	await _wait(func(): return hob.chat.intro_t > 0.7, 8.0)
	var focus: Vector3 = home.ppos
	var framed: Vector3 = hob.chat.frame(focus)
	var him: Vector3 = hob.node.position
	ok(Vector2(framed.x - him.x, framed.z - him.z).length() < 0.5 and hob.node.pose == "wave"
			and hob.node.bubble.visible and hob.node.bubble.text == String(hob.chat.rules()["call"]),
			"first arrival: the camera swings over to him while he waves and calls '%s'" % hob.node.bubble.text)
	await _shot("hob_1_calls_you_over", 0.3)
	await _shot("hob_2_camera_intro", 0.4)
	await _wait(func(): return hob.chat.intro_t < 0.0, 20.0)
	ok(hob.chat.frame(focus) == focus and bool(Save.d["tutorial"].get("hob_intro", false)),
			"then it comes back to you, once")
	# 3. talking
	_stand_by(hob.node.position)
	var it: Dictionary = hob.find(Vector2(home.ppos.x, home.ppos.z))
	ok(String(it.get("kind", "")) == "hob", "walking up to him: '%s'" % home._label_for(it))
	home._use(it)
	await _frames(3)
	var box: TalkBox = hob.chat.box
	ok(box != null and home.panel_open == HobTalk.TALK, "interact opens the talk box (you stand still)")
	if box == null:
		return
	var intro: Array = hob.chat.rules()["intro"]
	ok(_texts(box).has(FarmBuilder.full_name()) and box.find_children("*", "TextureRect", true, false).size() > 0
			and box.text.text == String(intro[0]["text"]), "his portrait, his name and his first line")
	await _shot("hob_3_dialogue_box", 0.9)
	for i in 4:      # (each line: one click finishes typing it, the next moves on)
		box.advance()
	await _frames(2)
	ok(box.text.text == String(intro[2]["text"]) and hob.node.pose == "point"
			and hob.node.point_at.distance_to(stall) < 0.5 and hob.chat.show_t >= 0.0,
			"line by line; on the stall line he points at it")
	await main.get_tree().create_timer(0.5).timeout
	await _shot("hob_4_points_at_stall", 0.1)
	var mid: Vector3 = hob.chat.frame(home.ppos)
	ok(Vector2(mid.x - home.ppos.x, mid.z - home.ppos.z).length() > 1.0, "and the camera looks over there")
	for i in intro.size() * 2:
		if hob.chat.talking():
			box.advance()
	await _frames(3)
	ok(not hob.chat.talking() and home.panel_open == "" and FarmTutorial.did("hob") and not hob.node.tag.visible,
			"after the last line: met, his name tag gone")
	ok(FarmTutorial.current() == "axe", "the next goal is the axe")
	await _frames(40)
	hob.talk()
	await _frames(2)
	ok(hob.chat.talking() and hob.chat.box.text.text == FarmTutorial.hint_text(FarmTutorial.current()),
			"later he explains the step you're on: '%s'" % hob.chat.box.text.text)
	home._close_panel()
	await _frames(2)
	ok(not hob.chat.talking(), "Esc ends the talk")

func _offer() -> void:
	var hob: FarmHob = home.hob
	ok(not hob.chat.offer_due() and not hob.node.mark.visible, "no Mask talk before the house is down")
	FarmTutorial.mark("axe")
	FarmTutorial.mark("chop")
	Work.add_mat("wood", 10)
	home.guide.place_house()
	home._sync_fixtures()
	FarmTutorial.detect()
	await _frames(3)
	ok(hob.chat.offer_due() and hob.node.mark.visible, "with the house down he has a '!' for you")
	hob.node.position = hob.pos
	_stand_by(hob.node.position)
	hob.talk()
	await _frames(2)
	var box: TalkBox = hob.chat.box
	ok(box.text.text == "By the way... I see you found a Vex Relic.", "\"%s\"" % box.text.text)
	box.advance()
	box.advance()
	await _frames(2)
	ok(box.text.text == "Could I interest you in another?", "\"%s\"" % box.text.text)
	await _shot("hob_5_offer_line", 0.8)
	box.advance()
	box.advance()
	await _frames(3)
	var offer: HobOffer = hob.chat.offer
	var cards: Array = box.find_children("*", "PanelContainer", true, false).filter(
			func(c): return c.has_meta("mask_card"))
	var ids: Array = cards.map(func(c): return String(c.get_meta("mask_card")))
	ok(offer != null and ids == SECOND, "the offer shows exactly Kael, Meeko and Cinder (%s)" % str(ids))
	var full := true
	var roles := true
	for c in cards:
		var id := String(c.get_meta("mask_card"))
		var faces: Array = c.find_children("*", "Control", true, false).filter(
				func(p): return p.has_meta("portrait_art"))
		full = full and not faces.is_empty() and _texts(c).has(HunterViewer.display_name(id))
		var role: Array = c.find_children("*", "Label", true, false).filter(func(l): return l.has_meta("mask_role"))
		roles = roles and not role.is_empty() and String((role[0] as Label).text).length() > 10
	ok(full, "each with its portrait, name and title")
	ok(roles, "and a one-line role")
	offer.focus(1)
	await _frames(2)
	var clips := box.find_children("*", "AbilityClip", true, false).filter(
			func(c): return not c.is_queued_for_deletion())
	ok(clips.size() == 1 and (clips[0] as AbilityClip).id == "tender", "one clip plays: the Relic in focus (Meeko)")
	var marker_off: bool = not is_instance_valid(home.guide.marker) or not home.guide.marker.visible
	ok(not home.guide.tracker.visible and marker_off and not home.guide.hint_box.visible
			and hob.node.mark.modulate.a == 0.0, "the Goals card, the goal line and the world prompts step aside")
	var pick_rect: Rect2 = (offer.root as Control).get_global_rect()
	var screen: Rect2 = main.get_viewport().get_visible_rect()
	ok(screen.size == Vector2(1280, 720) and screen.encloses(pick_rect),
			"the pick fits a 1280x720 screen (%s)" % pick_rect)
	await _shot("hob_6_three_masks", 1.6)
	offer.pick("tender")
	ok(ClassUnlock.open_ids() == ["gunslinger", "tender"] and not ClassUnlock.second_pending(),
			"taking Meeko opens her and nothing else (%s)" % str(ClassUnlock.open_ids()))
	box.advance()
	box.advance()
	await _frames(3)
	var beats: Array = home.find_children("*", "MaskBeat", true, false)
	ok(beats.size() == 1 and (beats[0] as MaskBeat).short and home.panel_open == HobTalk.TALK,
			"the short Mask moment plays (you stand still)")
	await _shot("hob_7_mask_moment", 1.0)
	await _wait(func(): return (beats[0] as MaskBeat).name_box != null, 6.0)
	await _shot("hob_8_mask_name", 0.3)
	await _wait(func(): return home.find_children("*", "MaskBeat", true, false).is_empty(), 10.0)
	await _frames(5)
	ok(home.panel_open == "" and ClassUnlock.pending_reveal().is_empty()
			and home.find_children("*", "ClassReveal", true, false).is_empty(),
			"then the farm again: no reveal pops up")
	ok(not hob.chat.offer_due() and not hob.node.mark.visible, "and no more offer")
	ok(home.guide.tracker.visible and home.guide.hint_box.visible and hob.node.tag.modulate.a == 1.0,
			"and the Goals card and the goal line are back")

func _later_and_legacy() -> void:
	await _new_farm(false)
	var hob: FarmHob = home.hob
	ok(hob.chat.offer_due(), "with no farm tutorial the offer is there at once")
	hob.talk()
	await _frames(2)
	hob.chat._show_offer()
	await _frames(2)
	hob.chat.later()
	for i in 4:
		if hob.chat.talking():
			hob.chat.box.advance()
	await _frames(3)
	ok(not hob.chat.talking() and ClassUnlock.second_pending() and hob.chat.offer_due(), "'Not now' keeps the offer")
	# a save that already owns a second Mask (the old flow): nothing offered, it keeps it
	var c := ClassUnlock.state()
	c["second"] = []
	c["open"] = ["gunslinger", "juggernaut"]
	ok(not ClassUnlock.second_pending() and not hob.chat.offer_due() and ClassUnlock.is_open("juggernaut"),
			"a save that already has its second Mask keeps it and is not offered another")

# ------------------------------------------------------------------ helpers
func _stand_by(at: Vector3) -> void:
	home.ppos = at + Vector3(1.2, 0, 1.2)
	home.player.position = home.ppos

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _wait(cond: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await main.get_tree().process_frame

func _shot(file: String, secs: float) -> void:
	if shots == "":
		return
	await main.get_tree().create_timer(secs).timeout
	main.get_viewport().get_texture().get_image().save_png(shots.path_join(file + ".png"))

func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	for ch in n.get_children():
		out.append_array(_texts(ch))
	return out
