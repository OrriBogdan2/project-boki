extends RefCounted
## --hob-check: Hob is a person on the farm and talks face to face (item 89), and the second Mask comes from him
## (item 87). FarmHob, HobModel, HobTalk, HobOffer, TalkBox; lines in content/rules/farm_builder.json "talk".
##   1. a new farm: Hob (the HobModel) waits by the market stall with his name over him; the first goal is to
##      meet him and the reminder line names him
##   2. the first arrival: the camera swings over to him while he waves and calls out, STAYS there for 5 s with
##      no input (a "Click to continue" hint at the bottom, input free), and returns within 1 s of a click
##   3. talking: the talk box with his portrait and name, one line at a time; you stand still; he points at the
##      stall and the camera looks there and stays until the next line; after the last line he is met (no name
##      tag) and the axe is next; a press held for a second skips every later look (CamLook)
##   4. the second Mask: no second Mask on a fresh save after the first expedition; not offered before the house
##      is down, then a "!" and "By the way... I see you found a Vex Relic"; the pick shows exactly Kael, Cinder and
##      Meeko, each with portrait, name and title and a role, and one clip (the one in focus); taking Meeko opens
##      her (and nothing else) and the short Mask moment plays; no reveal pops up after it
##   5. "Not now" keeps the offer; a save that already owns a second Mask is never offered one
##   6. real work: after Skip tutorial the house site goes up while Hob hammers (a swing every swing_s: the bar and
##      the walls move, the materials are spent) and is done in bounded time; with no materials he does not
##      hammer, the site says what it needs and he says it too; the normal tutorial path still builds
## With --shots-dir=<dir> (a renderer): hob_1_calls_you_over, hob_2_camera_intro, hob_3_dialogue_box,
## hob_4_points_at_stall, hob_5_offer_line, hob_6_three_masks,
## hob_6b_signature, hob_6c_dash, hob_7_mask_moment, hob_8_mask_name.

const SECOND := ["juggernaut", "ashwick", "tender"]    # owner order, class_unlock.json second_picks

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
	FarmUnlocks.rules()["base_mode"] = false      # walks the old farm
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
	await _skip_check()
	await _real_work()
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
	# 12 m: the nearest free tile depends on the new farm's random wild trees and rocks (hob-spot-check tests the rule)
	var off := Vector2(hob.node.position.x - stall.x, hob.node.position.z - stall.z).length()
	ok(hob.node is HobModel and off < 12.0,
			"Hob is a person standing by the market stall (at his spot, his clear ring apart from it) %.1f m" % off)
	ok(hob.node.tag.visible and hob.node.tag.text == FarmBuilder.full_name(), "his name shows over him")
	ok(FarmTutorial.current() == "hob" and home.guide.hint_text().contains("Hob")
			and not home.guide.hint_text().contains("Hob:"),
			"the first goal: meet him (%s)" % home.guide.hint_text())
	ok(ClassUnlock.second_pending() and ClassUnlock.open_ids() == ["archer", "gunslinger"],
			"after the first expedition no second Relic is owned yet (Vex and Lace are open)")
	# 2. the camera swing: it holds until a click
	var look: CamLook = hob.chat.look
	await _wait(func(): return hob.chat.intro_on and look.phase == CamLook.Phase.HOLD, 12.0)
	var focus: Vector3 = home.ppos
	var framed: Vector3 = hob.chat.frame(focus)
	var him: Vector3 = hob.node.position
	ok(Vector2(framed.x - him.x, framed.z - him.z).length() < 0.5 and hob.node.pose == "wave"
			and hob.node.bubble.visible and hob.node.bubble.text == String(hob.chat.rules()["call"]),
			"first arrival: the camera swings over to him while he waves and calls '%s'" % hob.node.bubble.text)
	await _shot("hob_1_calls_you_over", 0.3)
	await _shot("hob_2_camera_intro", 0.4)
	await main.get_tree().create_timer(5.0).timeout
	framed = hob.chat.frame(focus)
	ok(hob.chat.intro_on and look.phase == CamLook.Phase.HOLD
			and Vector2(framed.x - him.x, framed.z - him.z).length() < 0.5,
			"5 s with no input: the camera is still on him")
	ok(look._text.text.contains("continue") and look._card.modulate.a > 0.9 and home.panel_open == ""
			and not look.locked(),
			"the hint shows ('%s') and you are not locked" % look._text.text)
	_click()
	var back_s := await _wait(func(): return not hob.chat.intro_on, 3.0)
	ok(not hob.chat.intro_on and back_s < 1.0 and hob.chat.frame(focus) == focus
			and bool(Save.d["tutorial"].get("hob_intro", false)),
			"a click and the camera is back on you in %.2f s, once" % back_s)
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
		await _advance(box)
	await _frames(2)
	ok(box.text.text == String(intro[2]["text"]) and hob.node.pose == "point"
			and hob.node.point_at.distance_to(stall) < 0.5 and look.active(),
			"line by line; on the stall line he points at it")
	await _wait(func(): return look.phase == CamLook.Phase.HOLD, 3.0)
	await _shot("hob_4_points_at_stall", 0.1)
	await main.get_tree().create_timer(5.0).timeout
	var mid: Vector3 = hob.chat.frame(home.ppos)
	ok(look.phase == CamLook.Phase.HOLD and Vector2(mid.x - stall.x, mid.z - stall.z).length() < 0.5,
			"and the camera stays on the stall for 5 s with no input")
	for i in intro.size() * 2:
		if hob.chat.talking():
			await _advance(box)
	await _frames(3)
	ok(not hob.chat.talking() and home.panel_open == "" and FarmTutorial.did("hob") and not hob.node.tag.visible,
			"after the last line: met, his name tag gone")
	ok(FarmTutorial.current() == "axe", "the next goal is the axe")
	back_s = await _wait(func(): return not look.active(), 3.0)
	ok(not look.active() and back_s < 1.0 and hob.chat.frame(home.ppos) == home.ppos,
			"after the last line the camera is back on you in %.2f s" % back_s)
	await _frames(40)
	hob.talk()
	await _frames(2)
	ok(hob.chat.talking() and hob.chat.box.text.text == FarmTutorial.hint_text(FarmTutorial.current()),
			"later he explains the step you're on: '%s'" % hob.chat.box.text.text)
	home._close_panel()
	await _frames(2)
	ok(not hob.chat.talking(), "Esc ends the talk")

## A press held for a second skips the pan and every later one.
func _skip_check() -> void:
	var l := CamLook.new()
	main.add_child(l)
	l.watching = true
	var at := Vector3(5, 0, 5)
	ok(l.look(at), "a look starts")
	await _wait(func(): return l.phase == CamLook.Phase.HOLD, 3.0)
	Input.action_press("interact")
	await _wait(func(): return l.skip_rest, 3.0)
	Input.action_release("interact")
	ok(l.skip_rest and not l.look(at), "a press held for a second skips the rest: no later look starts")
	l.queue_free()

func _offer() -> void:
	var hob: FarmHob = home.hob
	ok(not hob.chat.offer_due() and not hob.node.mark.visible, "no Mask talk before the house is down")
	FarmTutorial.mark("axe")
	FarmTutorial.mark("chop")
	Work.add_mat("wood", 10)
	Work.add_mat("stone", 6)
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
	await _advance(box)
	await _advance(box)
	await _frames(2)
	ok(box.text.text == "Could I interest you in another?", "\"%s\"" % box.text.text)
	await _shot("hob_5_offer_line", 0.8)
	await _advance(box)
	await _advance(box)
	await _frames(3)
	var offer: HobOffer = hob.chat.offer
	var cards: Array = box.find_children("*", "PanelContainer", true, false).filter(
			func(c): return c.has_meta("mask_card"))
	var ids: Array = cards.map(func(c): return String(c.get_meta("mask_card")))
	ok(offer != null and ids == SECOND, "the offer shows exactly Kael, Cinder and Meeko (%s)" % str(ids))
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
	offer.focus(2)
	await _frames(2)
	var clips := box.find_children("*", "AbilityClip", true, false).filter(
			func(c): return not c.is_queued_for_deletion())
	var slots: Array = clips.map(func(c): return (c as AbilityClip).slot)
	ok(slots == ["lmb", "e", "dash"] and clips.all(func(c): return (c as AbilityClip).id == "tender"),
			"the Relic in focus (Meeko) loops its attack, healing ring and dash (%s)" % str(slots))
	ok(clips.filter(func(c): return (c as AbilityClip).visible).size() == 1, "one clip shows at a time")
	offer.show_clip(2)
	var dash: AbilityClip = clips[2]
	ok(dash.visible and not (clips[0] as AbilityClip).visible and dash.t == 0.0,
			"the reel moves on to the dash, from its start")
	offer.show_clip(0)
	var marker_off: bool = not is_instance_valid(home.guide.marker) or not home.guide.marker.visible
	var tracker_off: bool = home.guide.tracker == null or not home.guide.tracker.visible
	ok(tracker_off and marker_off and not home.guide.hint_box.visible
			and hob.node.mark.modulate.a == 0.0, "the Goals card, the goal line and the world prompts step aside")
	var pick_rect: Rect2 = (offer.root as Control).get_global_rect()
	var screen: Rect2 = main.get_viewport().get_visible_rect()
	ok(screen.size == Vector2(1280, 720) and screen.encloses(pick_rect),
			"the pick fits a 1280x720 screen (%s)" % pick_rect)
	await _shot("hob_6_three_masks", 1.6)
	offer.show_clip(1)
	await _shot("hob_6b_signature", 1.2)
	offer.show_clip(2)
	await _shot("hob_6c_dash", 1.0)
	offer.pick("tender")
	ok(ClassUnlock.open_ids() == ["archer", "gunslinger", "tender"] and not ClassUnlock.second_pending(),
			"taking Meeko opens her and no one else (%s)" % str(ClassUnlock.open_ids()))
	await _advance(box)
	await _advance(box)
	await _frames(3)
	var beats: Array = home.find_children("*", "MaskBeat", true, false)
	ok(beats.size() == 1 and (beats[0] as MaskBeat).short and home.panel_open == HobTalk.TALK,
			"the short Mask moment plays (you stand still)")
	await _shot("hob_7_mask_moment", 1.0)
	await _wait(func(): return (beats[0] as MaskBeat).name_box != null, 10.0)
	await _shot("hob_8_mask_name", 0.3)
	await _wait(func(): return home.find_children("*", "MaskBeat", true, false).is_empty(), 16.0)
	await _frames(5)
	ok(home.panel_open == "" and ClassUnlock.pending_reveal().is_empty()
			and home.find_children("*", "ClassReveal", true, false).is_empty(),
			"then the farm again: no reveal pops up")
	ok(not hob.chat.offer_due() and not hob.node.mark.visible, "and no more offer")
	# (the farm tutorial has no Goals card at all: FarmGuide builds it after day one)
	var tracker_back: bool = home.guide.tracker.visible if home.guide.tracker != null else FarmTutorial.active()
	ok(tracker_back and home.guide.hint_box.visible and hob.node.tag.modulate.a == 1.0,
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

## A new farm with the intro over and only Hob working (no Boki takes a swing).
func _worksite_farm() -> FarmHob:
	await _new_farm()
	Work.set_prio("craft", 0)
	var hob: FarmHob = home.hob
	await _wait(func(): return hob.chat.intro_on, 12.0)
	_click()
	await _wait(func(): return not hob.chat.busy(), 3.0)
	return hob


## Hob's hammering builds the house (or he says why not). Only Hob works here: no Boki takes a swing.
func _real_work() -> void:
	var hob := await _worksite_farm()
	home.guide.skip()
	await _frames(3)
	var e := FarmHob.house_entry()
	var u := int(e["u"])
	var cost := FarmSites.build_cost("house")
	var wood0 := FarmSites.have("wood")
	var stone0 := FarmSites.have("stone")
	ok(FarmSites.is_site(e) and FarmSites.have("wood") >= int(cost["wood"]) and not FarmSites.stalled(e),
			"skip tutorial: the house is a site with its materials (%d wood, %d stone)"
			% [FarmSites.have("wood"), FarmSites.have("stone")])
	await _wait(func(): return hob.node.pose == "hammer", 25.0)
	var swing_s := float(hob.rules()["swing_s"])
	var got0 := int(e["site"]["got"])
	var t := await _wait(func(): return int(FarmSites.entry(u)["site"]["got"]) > got0, swing_s + 2.0)
	var bar := home.hb.nodes[u].get_node("Bar") as Sprite3D
	ok(hob.node.pose == "hammer" and int(FarmSites.entry(u)["site"]["got"]) == got0 + 1,
			"Hob hammers and a swing lands on the house after %.1f s (every %.1f s)" % [t, swing_s])
	ok(int(bar.get_meta("k", 0)) > 0 and FarmSites.have("wood") < wood0,
			"the bar moved and the first materials were spent")
	var rise0 := _rise(u)
	hob.rules()["swing_s"] = 0.4      # (the pace is checked above; this keeps the run short)
	await _wait(func(): return int(FarmSites.entry(u)["site"]["got"]) >= 9, swing_s + 9.0 * 0.4 + 4.0)
	ok(_rise(u) > rise0 + 0.5, "the walls rise as he works (%.2f m -> %.2f m at 9/12)" % [rise0, _rise(u)])
	var t_all := await _wait(func(): return not FarmSites.has_site(FarmHob.house_entry()), 12.0 * 0.4 + 6.0)
	ok(not FarmSites.has_site(FarmHob.house_entry()) and Progress.stat("fb_built") >= 1,
			"with nobody helping the house is done in %.1f s" % t_all)
	ok(FarmSites.have("wood") == wood0 - int(cost["wood"]) and FarmSites.have("stone") == stone0 - int(cost["stone"]),
			"and its materials were spent as it went (%d wood, %d stone left)"
			% [FarmSites.have("wood"), FarmSites.have("stone")])
	hob.rules()["swing_s"] = swing_s
	await _wait_stalled()
	await _tutorial_path()

## No materials: the house waits, Hob stands by it with his hands down and says what it needs.
func _wait_stalled() -> void:
	var hob := await _worksite_farm()
	ClassUnlock.state()["second"] = []      # (no Mask offer and no new blueprints: a "!" over him is for the site)
	home.guide.skip()
	FarmBuilder.draw_up()
	for m in FarmSites.MATS:
		FarmSites.pay({m: FarmSites.have(m)})
	await _wait(func(): return hob.node.position.distance_to(hob.pos) < 0.1 and hob.node.pose == "idle", 25.0)
	var e := FarmHob.house_entry()
	var u := int(e["u"])
	var need := FarmSites.need_text(e)
	await _wait(func(): return false, float(hob.rules()["swing_s"]) + 2.0)
	var tag := home.hb.nodes[u].get_node_or_null("Need") as Label3D
	ok(need.begins_with("Needs") and hob.waiting() and hob.node.pose == "idle"
			and int(FarmSites.entry(u)["site"]["got"]) == 0,
			"no materials: Hob does not hammer and the house stays at 0 swings (%s)" % need)
	ok(tag != null and tag.visible and tag.text == need and hob.node.mark.visible,
			"the label over the site says '%s' and his '!' shows" % need)
	ok(hob.wait_line().contains(need.to_lower()) and hob.node.position.distance_to(HomeLayout.deco_center(e)) < 8.0,
			"he stands by it and says '%s'" % hob.wait_line())
	FarmSites.top_up(e)
	var got0 := int(e["site"]["got"])
	await _wait(func(): return int(FarmSites.entry(u)["site"]["got"]) > got0, float(hob.rules()["swing_s"]) + 3.0)
	var hammering: bool = hob.node.pose == "hammer" and not hob.node.mark.visible
	ok(not hob.waiting() and int(FarmSites.entry(u)["site"]["got"]) > got0 and hammering,
			"given the materials he starts hammering again")

## The normal tutorial: the house is placed by hand, your own swings still count, Hob adds his.
func _tutorial_path() -> void:
	var hob := await _worksite_farm()
	Work.add_mat("wood", 10)
	Work.add_mat("stone", 6)
	ok(home.guide.place_house(), "tutorial: the house is placed as a site")
	home._sync_fixtures()
	FarmTutorial.detect()
	var e := FarmHob.house_entry()
	var u := int(e["u"])
	await _wait(func(): return hob.node.pose == "hammer", 25.0)
	_stand_by(HomeLayout.deco_center(e))
	FarmSites.player_swing(home.hw, e)
	ok(int(FarmSites.entry(u)["site"]["got"]) == 1, "your own swing still adds one")
	hob.swing_t = 0.0
	await _frames(2)
	ok(int(FarmSites.entry(u)["site"]["got"]) == 2, "and Hob's swing adds one more")

# ------------------------------------------------------------------ helpers
## How tall the house site's walls stand so far (its "Rise" box), in metres.
func _rise(u: int) -> float:
	var r := home.hb.nodes[u].find_child("Rise", true, false) as MeshInstance3D
	return r.get_aabb().size.y if r else 0.0

## One press on the talk box: it waits out a camera move first.
func _advance(box: TalkBox) -> void:
	await _wait(func(): return not box.frozen, 3.0)
	box.advance()

func _click() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	main.get_viewport().push_input(ev)

func _stand_by(at: Vector3) -> void:
	home.ppos = at + Vector3(1.2, 0, 1.2)
	home.player.position = home.ppos

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## Waits for `cond`, at most `secs` of the home's own clock (its frame step is capped at 0.05 s, so slow frames
## on a loaded box do not use the wait up before the game got there); returns the game seconds it took.
func _wait(cond: Callable, secs: float) -> float:
	var t := 0.0
	while not cond.call() and t < secs:
		await main.get_tree().process_frame
		t += minf(main.get_process_delta_time(), 0.05)
	return t

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
