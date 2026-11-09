extends RefCounted
## --garden-card-check: the Boki card in base mode (GARDEN.md 8, DECISIONS "show only what's needed").
## Off: the old tabbed card. On: one glance (name, species and lean chips, mood, best friend and rival, the last
## two journal lines); the stats and tabs are behind More; a tap on a friend closes the card and the camera
## rests on that Boki for a moment. It reads the record only.
## --garden-card-shots --shots-dir=<dir> [--size=WxH]: three different Boki's cards (needs a renderer).

var fails := 0

func ok(cond: bool, what: String) -> void:
	print("GARDENCARD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1

## The card's texts: the old card is only queued for deletion until the frame ends, so it is skipped.
func _live(home, type: String) -> Array:
	var kids: Array = home.panel_host.get_children().filter(func(c): return not c.is_queued_for_deletion())
	return kids[-1].find_children("*", type, true, false) if not kids.is_empty() else []

func _texts(home) -> Array:
	return _live(home, "Label").map(func(l): return (l as Label).text) + _live(home, "Button").map(func(b): return (b as Button).text)

func _button(home, txt: String) -> Button:
	for b in _live(home, "Button"):
		if (b as Button).text == txt:
			return b
	return null

func _home(m: Node):
	Save.no_write = true
	Save.d = Save.fresh()
	for pair in [["zapple", "Pip"], ["cindle", "Ember"], ["puddlet", "Drip"], ["pebbit", "Rocky"]]:
		var kin := Save.new_kin(pair[0], pair[1])
		Save.d["roster"].append(kin)
	Save.d["active"] = Save.d["roster"][0]["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	var home = await m._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await m.get_tree().process_frame
	home._close_panel()
	return home

## Pip likes Ember a lot and Drip a little, dislikes Rocky; it ate twice and leans Fire.
func _story(roster: Array) -> void:
	var pip: Dictionary = roster[0]
	pip["bonds"] = {roster[1]["uid"]: 0.8, roster[2]["uid"]: 0.6, roster[3]["uid"]: -0.7}
	Evo.eat(pip, "emberberry")
	pip["journal"] = [{"t": 1.0, "food": "kibble", "n": 1, "up": []}, {"t": 2.0, "food": "emberberry", "n": 1, "up": ["Fire"]},
			{"t": 3.0, "food": "kibble", "n": 3, "up": []}]

func _shots(m: Node, home) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			m.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	if is_instance_valid(m.fade):
		await m.fade.reveal(0.05)
	FarmUnlocks.rules()["base_mode"] = true
	var roster: Array = Save.d["roster"]
	_story(roster)
	roster[1]["bonds"] = {roster[0]["uid"]: 0.8}
	for i in 3:
		home._open_kin(roster[i])
		for f in 12:
			await m.get_tree().process_frame
		await m.get_tree().create_timer(0.6).timeout      # the portraits render once, a frame after they are made
		m.get_viewport().get_texture().get_image().save_png(dir.path_join("card_%d.png" % i))
		print("GARDENCARDSHOT ", roster[i]["name"])
	m.get_tree().quit()

func run(m: Node, mode := "check") -> void:
	var home = await _home(m)
	if mode == "shots":
		await _shots(m, home)
		return
	var rules: Dictionary = FarmUnlocks.rules()
	var roster: Array = Save.d["roster"]
	var pip: Dictionary = roster[0]
	_story(roster)
	home._open_kin(pip)
	ok(_button(home, "More") == null and _texts(home).has("Care"), "off: the tabbed card, no More button")
	rules["base_mode"] = true
	GardenCard.more = false
	home._open_kin(pip)
	var t: Array = _texts(home)
	ok(t.has("Pip"), "on: the name")
	ok(t.has("Echolop") and t.has("Echo"), "on: species and element chips: %s" % str(t))
	ok(t.any(func(s): return s.begins_with("Leans ")), "on: the lean chip")
	ok(["HAPPY", "CONTENT", "QUIET", "GLUM"].any(func(w): return t.has(w)), "on: a mood word")
	ok(t.has("Ember") and not t.has("Drip") and t.has("BEST FRIEND"), "on: the closest friend is Ember (Drip is a weaker bond)")
	ok(t.has("Rocky") and t.has("RIVAL"), "on: the rival is Rocky")
	var i3 := t.find("ate 3 × Boki kibble")
	ok(i3 >= 0 and t.find("ate Emberberry: Fire lean up") > i3 and not t.has("ate Boki kibble"), "on: the last two journal lines, newest first")
	ok(not t.has("Training") and not t.has("Growth") and not t.has("Stats  ·  cap 25".to_upper()), "on: no tabs or stats")
	ok(t.size() <= 30, "on: the glance and the care buttons stay short (%d texts)" % t.size())
	var more := _button(home, "More")
	ok(more != null, "on: a More button")
	more.pressed.emit()
	t = _texts(home)
	ok(t.has("Training") and t.has("Care") and not t.has("BEST FRIEND") and _button(home, "Less") != null, "More: the old tabs, Less to come back")
	_button(home, "Less").pressed.emit()
	ok(_texts(home).has("BEST FRIEND"), "Less: the glance again")
	var cs: Array = GardenCard.pair(roster[2])
	ok((cs[0] as Dictionary).is_empty() and (cs[1] as Dictionary).is_empty(), "a Boki with no bonds has no friend or rival")
	ok(_texts(home).has("none yet") == false, "Pip has both, so no 'none yet'")
	home._open_kin(roster[3])
	ok(_texts(home).count("none yet") == 2 and _texts(home).has("No lean yet"), "no bonds, no meals: 'none yet' twice, 'No lean yet'")
	home._open_kin(pip)
	var tap: Button = null
	for b in _live(home, "Button"):
		if (b as Button).tooltip_text == "Find Ember in the garden":
			tap = b
	ok(tap != null, "the friend's portrait is a button")
	tap.pressed.emit()
	var k: Dictionary = {}
	for kd in home.kins:
		if kd["rec"]["name"] == "Ember":
			k = kd
	var here := Vector3(3.0, 0.0, 4.0)
	var f := GardenCard.framed(here, 0.1)
	ok(home.panel_open == "" and not k.is_empty() and is_equal_approx(f.x, k["pos"].x) and is_equal_approx(f.z, k["pos"].z),
			"tap: the card closes and the camera rests on Ember")
	ok(String((k["emote"] as Label3D).text) == "Ember", "tap: Ember's name floats over it")
	f = GardenCard.framed(here, GardenCard.LOOK_S + 1.0)
	ok(GardenCard.framed(here, 0.1) == here, "after a few seconds the camera is back on the player")
	rules["base_mode"] = false
	GardenCard.more = false
	home.queue_free()
	await m.get_tree().process_frame
	print("GARDENCARD DONE, failures: %d" % fails)
	m.get_tree().quit(1 if fails > 0 else 0)
