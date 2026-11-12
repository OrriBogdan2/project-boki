extends "res://tools/abyss_check.gd"
## --hold-teach-check: teaching that chopping and gliding are HOLD actions (HoldTeach, HoldPrompt).
##   1. home: tap F at a tree twice -> the ring flashes, "Hold" pops, then the "Hold F to chop" hint shows;
##      hold F -> the axe keeps swinging, the tree comes down and the hold counts
##   2. match: the jump press is never a tap; tap Space mid-air -> the ring flashes and "Hold" pops beside you;
##      a second tap -> "Hold Space to glide" in the message lane; hold Space -> the glider stays open and counts
##   3. the tutorial texts say HOLD (the farm step waiting for a held chop: farm_tutorial_check);
##      after DONE_N finished holds an action stops teaching (no pop, no hint)
## The real input actions are pressed (Input.action_press) and HoldTeach's clock is stepped by hand.
## Puts the player's "hold_done" setting back afterwards. Prints "ACHECK ok|FAIL ..." and "ACHECK DONE, failures: N".

const DT := 0.05  # s per home step (the tool swing's own checks use the same)
const TAP_FRAMES := 2  # home steps a tap is held (0.1 s, under HoldTeach.TAP_S)
const REST_S := 1.6  # s between home taps: the swing a tap started finishes and the tool goes away
const AIR_TAP := 6  # match steps a tapped Space is held (0.1 s)
const HIGH := 60.0  # m: the glide cases start this far up so they never land mid-case

var main_node: Node


func run(main: Node) -> void:
	main_node = main
	Save.no_write = true
	var holds0: Dictionary = (Settings.get_v(HoldTeach.SETTING) as Dictionary).duplicate()
	Settings.set_v(HoldTeach.SETTING, {}, false)
	HoldTeach.reset_session()
	HoldTeach.clock = 100.0
	await _home_chop()
	await main.get_tree().process_frame
	_match_glide()
	_texts()
	_taught()
	HoldTeach.clock = -1.0
	Settings.set_v(HoldTeach.SETTING, holds0)
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


static func _press(action: String, down: bool) -> void:
	if down and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not down and Input.is_action_pressed(action):
		Input.action_release(action)


## Any Label under `n` whose text contains `s` (the home toast).
func _shows(n: Node, s: String) -> bool:
	if n is Label and (n as Label).text.contains(s):
		return true
	for c in n.get_children():
		if _shows(c, s):
			return true
	return false


# ------------------------------------------------------------------ 1. home: chop
func _home_frame(home, hg: HomeGather, down: bool) -> void:
	var fresh: bool = down and not Input.is_action_pressed("interact")
	_press("interact", down)
	if fresh:
		hg.use(home.interact)  # what home does with a fresh press at a tree
	HoldTeach.clock += DT
	hg.tick(DT)


func _home_chop() -> void:
	Save.d = Save.fresh()
	var k := Save.new_kin("cindle", "Pip")
	k["starter"] = true
	Care.ensure(k)
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true}
	HomeLayout.ensure(Save.d)
	var home = await main_node._hb_home()
	home._close_panel()
	home.set_process(false)  # the check is the frame loop: home's own would press nothing anyway
	var hg: HomeGather = home.hg
	HomeGather.give_tool("axe")
	var tile := -1
	var stand := Vector3.INF
	for i in home.hb.wild_t:
		if home.hb.wild_t[i] != "tree":
			continue
		var b := hg.beside(i, HomeLayout.LANDING)
		if b != Vector3.INF and int(hg.find(Vector2(b.x, b.z)).get("i", -1)) == i:
			tile = i
			stand = b
			break
	ok(tile >= 0, "home: there is a tree to chop")
	if tile < 0:
		return
	home.ppos = stand
	home.player.position = stand
	home.interact = hg.find(Vector2(stand.x, stand.z))
	var pair: Array = hg.prompt_pair(home.interact)
	ok(
		String(pair[0]) == "Hold " + Settings.key_cap("interact") and HoldPrompt.is_hold(String(pair[0])),
		"home: the tree's prompt reads 'Hold %s %s' (%s)" % [Settings.key_cap("interact"), pair[1], str(pair)]
	)
	var row := HoldPrompt.key_hints([pair], 14, UI.INK, hg.ring_fill, hg.ring_action)
	var one: Node = row.get_child(0)
	ok(
		one.get_child_count() == 3 and one.get_child(1) is HoldPrompt.Cap,
		"home: the prompt row is 'Hold' + the ring cap + the words"
	)
	row.free()
	for n in 2:
		for i in TAP_FRAMES:
			_home_frame(home, hg, true)
		_home_frame(home, hg, false)
		if n == 0:
			ok(
				HoldTeach.taps("chop") == 1 and HoldTeach.flash("chop") > 0.0 and HoldTeach.pop("chop") >= 0.0,
				"home: a tap at the tree flashes the ring and pops 'Hold' (taps %d)" % HoldTeach.taps("chop")
			)
			ok(not HoldTeach.hinted("chop"), "home: one tap is not yet worth the hint line")
		for i in int(REST_S / DT):
			_home_frame(home, hg, false)
	var hint := HoldTeach.hint("chop")
	ok(hint == "Hold %s to chop" % Settings.key_cap("interact"), "home: the hint is '%s'" % hint)
	ok(HoldTeach.hinted("chop") and _shows(home, hint), "home: the second tap shows the hint on screen")
	ok(HoldTeach.count("chop") == 0, "home: taps never count as a finished hold")
	var hits0 := int(hg.damage.get(tile, 0))
	for i in int(2.5 / DT):
		_home_frame(home, hg, true)
		if not home.hb.wild_t.has(tile):
			break
	_home_frame(home, hg, false)
	ok(
		not home.hb.wild_t.has(tile) or int(hg.damage.get(tile, 0)) > hits0 + 1,
		(
			"home: holding F chops on (hits %d -> %d, felled %s)"
			% [hits0, int(hg.damage.get(tile, 0)), not home.hb.wild_t.has(tile)]
		)
	)
	ok(HoldTeach.count("chop") == 1, "home: the hold counts once (saved: %s)" % str(Settings.get_v(HoldTeach.SETTING)))
	_press("interact", false)
	home.queue_free()


# ------------------------------------------------------------------ 2. match: glide
func _air_frame(down: bool) -> void:
	var was := Input.is_action_pressed("jump")
	_press("jump", down)
	for k in ["fire", "glide_btn", "sec", "sec_hold", "dash"]:
		h.inp[k] = false
	h.inp["glide_press_only"] = true
	h.inp["glide"] = down
	h.inp["jump"] = down and not was
	m.step(Match.DT)
	HoldTeach.clock += Match.DT
	HoldTeach.match_tick(m)


func _lane_has(s: String) -> bool:
	return str(m.hud.msgs._shown).contains(s) or str(m.hud.msgs._waiting).contains(s)


func _match_glide() -> void:
	m = Match.new()
	main_node.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	w = m.world
	h = m.player
	for o in m.hunters:
		if o != h:
			o.ctrl = "idle"
			o.teleport(h.pos + Vector3(60, 0, 60))
	m.opts["god"] = true
	# the jump: Space pressed on the ground is a jump, never a tap
	_reset(w.random_ground() + Vector3(0, 0.3, 0), Vector3.ZERO)
	for i in 60:
		_air_frame(false)
	for i in AIR_TAP:
		_air_frame(true)
	for i in 3:
		_air_frame(false)
	ok(HoldTeach.taps("glide") == 0, "match: the press that jumps is not a glide tap")
	for i in 90:
		_air_frame(false)
	# mid-air taps
	_reset(w.random_ground() + Vector3(0, HIGH, 0), Vector3.ZERO)
	h.coyote = 0.0
	for i in 4:
		_air_frame(false)
	for n in 2:
		for i in AIR_TAP:
			_air_frame(true)
		_air_frame(false)
		if n == 0:
			ok(
				HoldTeach.taps("glide") == 1 and HoldTeach.showing("glide") and HoldTeach.pop("glide") >= 0.0,
				"match: a tapped Space mid-air flashes the ring and pops 'Hold' (taps %d)" % HoldTeach.taps("glide")
			)
			ok(not h.gliding, "match: a tap leaves the glider shut (the hold rule stays)")
		for i in 20:
			_air_frame(false)
	var hint := HoldTeach.hint("glide")
	ok(
		hint == "Hold Space to glide" or not Settings.key_cap("jump").begins_with("SPACE"),
		"match: the hint is '%s'" % hint
	)
	ok(HoldTeach.hinted("glide") and _lane_has(hint), "match: the second tap puts the hint in the message lane")
	ok(HoldTeach.count("glide") == 0 and not h.grounded, "match: taps never count (still in the air)")
	var open_t := 0.0
	for i in 60:
		_air_frame(true)
		open_t += Match.DT if h.gliding else 0.0
	_air_frame(false)
	ok(open_t >= HoldTeach.GLIDE_DONE_S, "match: holding Space keeps the glider open (%.2fs)" % open_t)
	ok(HoldTeach.count("glide") == 1, "match: the held glide counts once")
	_press("jump", false)
	m.queue_free()


# ------------------------------------------------------------------ 3. texts, and done teaching
func _texts() -> void:
	var tut: Dictionary = _json("res://content/rules/tutorial.json")
	var glide_line := ""
	for s in tut["steps"]:
		if String(s[0]) == "glide":
			glide_line = String(s[1])
	ok(glide_line.contains("HOLD"), "the match tutorial's glide line says HOLD ('%s')" % glide_line)
	ok(FarmTutorial.hint_text("chop").contains("HOLD"), "the farm tutorial's chop hint says HOLD")
	# the farm's chop step waiting for a held chop: tools/farm_tutorial_check.gd


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _taught() -> void:
	HoldTeach.reset_session()
	Settings.set_v(HoldTeach.SETTING, {"glide": HoldTeach.DONE_N}, false)
	var said := []
	for n in 3:
		HoldTeach.key("glide", true, true, true, func(t): said.append(t))
		HoldTeach.clock += 0.1
		HoldTeach.key("glide", false, true, true, func(t): said.append(t))
		HoldTeach.clock += 0.5
	ok(
		HoldTeach.taps("glide") == 3 and said.is_empty() and HoldTeach.pop("glide") < 0.0,
		"after %d finished glides a tap gets no pop and no hint" % HoldTeach.DONE_N
	)
	HoldTeach.key("glide", true, true, true, func(t): said.append(t))
	HoldTeach.clock += 0.1
	HoldTeach.key("glide", false, true, true, func(t): said.append(t))
	ok(HoldTeach.flash("glide") > 0.0, "... but the ring still flashes")
	HoldTeach.reset_session()
