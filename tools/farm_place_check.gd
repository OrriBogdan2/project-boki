extends RefCounted
## --farm-place-check: Enter on "Fill it up", Hob's relic timing and the hunger gate
## (PLAYTEST-1108 items 27, 28 and 31). Never touches the real save.
##   1. Enter presses "Fill it up" like a click, every time, and never leaves the panel stuck
##   2. Hob's relic only after all 12 steps, on a fresh save and on a save reloaded mid-tutorial
##   3. the hunger gate says how many meals a too-hungry partner needs, feeds it on the spot, updates live and
##      offers Go the moment the line is crossed

var bad := 0
var main: Node
var shots := ""

func ok(cond: bool, what: String) -> void:
	print("FPLACE %s %s" % ["ok  " if cond else "FAIL", what])
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
	main.get_tree().root.size = Vector2i(1280, 720)
	await _enter()
	await _relic()
	await _hunger()
	print("FPLACE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _home():
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	Care.ensure(k)
	d["roster"].append(k)
	k["starter"] = true
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(Save.d)
	var home = await main._hb_home()
	await _frames(3)
	print("FPLACE home up, panel_host=%s" % [home.panel_host])
	home._close_panel()
	return home

## A key press and release, a frame apart like a real keyboard.
func _key(code: Key) -> void:
	for down in [true, false]:
		if not down:
			await _frames(1)
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		main.get_viewport().push_input(ev)

func _click(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	main.get_viewport().push_input(mv)
	await _frames(2)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		main.get_viewport().push_input(ev)

func _tutorial_home(done: Array):
	var home = await _home()
	Save.d["tutorial"]["home"] = true
	FarmSpotlight.reset()
	for id in done:
		FarmTutorial.mark(id)
	FarmTutorial.detect()
	return home

## Runs the guide's poll and lets the spotlight catch up.
func _poll(home) -> void:
	home.guide.tick(0.6)
	await _frames(3)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

# ------------------------------------------------------------------ Enter
func _enter() -> void:
	var home = await _home()
	Save.d["items"]["kibble"] = 6
	Save.d["feeders"] = [{"id": "f1", "kind": "trough", "x": 40.0, "z": 30.0, "food": [], "auto": false}]
	var f: Dictionary = Save.d["feeders"][0]
	home.hecon.open_feeder(f)
	await _frames(2)
	ok(home.panel_open != "", "the trough panel is open")
	await _key(KEY_ENTER)
	await _frames(3)
	ok(Econ.fill(f) > 0, "Enter on the trough panel fills it (%d meals in)" % Econ.fill(f))
	ok(home.panel_open == "", "filling it puts you back in the world (%s)" % home.panel_open)
	home.hecon.open_feeder(f)
	await _frames(2)
	var b: Button = _primary(home)
	ok(b != null and b.text == "Done" and not b.disabled, "a full trough: Enter is Done, never a dead button")
	await _key(KEY_ENTER)
	await _frames(3)
	ok(home.panel_open == "", "Enter on a full trough closes it")
	Save.d["items"]["kibble"] = 0
	f["food"] = []
	home.hecon.open_feeder(f)
	await _frames(2)
	await _key(KEY_ENTER)
	await _frames(3)
	ok(home.panel_open != "" and Econ.fill(f) == 0,
		"an empty pantry: Enter says so and keeps the panel (nothing to do)")
	home._close_panel()
	home.queue_free()
	await _frames(2)

func _tile_click() -> InputEvent:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev

# ------------------------------------------------------------------ Hob's relic
func _relic() -> void:
	# a fresh save: mid-tutorial, no offer; the last step done: the offer
	var home = await _tutorial_home([])
	ClassUnlock.choose_starters(["gunslinger"])
	Game.apply_result({"arch": "gunslinger", "extracted": true, "why": "extracted", "knocks": 0, "kills": 0,
			"gems": 0, "seeds": {}, "stats": {}, "lvl": 1, "caught": [], "kin_runs": [], "tutorial": true, "tonics": 0})
	ok(ClassUnlock.second_pending(), "the second relic is owed (the first expedition came home)")
	ok(FarmTutorial.active() and not home.hob.chat.offer_due(), "a fresh farm: no relic while the tutorial runs")
	for st in FarmTutorial.steps():
		if st["id"] != "expedition":
			FarmTutorial.mark(st["id"])
	ok(FarmTutorial.active() and not home.hob.chat.offer_due(), "every step but the last: still no relic")
	# quit mid-tutorial and come back
	Save.save_game()
	var json := JSON.stringify(Save.d)
	home.queue_free()
	await _frames(2)
	Save.d = JSON.parse_string(json)
	Save.migrate(Save.d)
	home = await main._hb_home()
	await _frames(3)
	home._close_panel()
	ok(FarmTutorial.active() and not home.hob.chat.offer_due(), "reloaded mid-tutorial: still no relic")
	FarmTutorial.mark("expedition")
	ok(not FarmTutorial.active() and home.hob.chat.offer_due(), "all steps done: the relic is offered")
	home.queue_free()
	await _frames(2)

# ------------------------------------------------------------------ hunger
func _hunger() -> void:
	var home = await _home()
	var rec: Dictionary = Save.active_kin()
	rec["starve"] = 24.0 * 3600.0
	Care.ensure(rec)
	rec["needs"]["food"] = 5.0               # a day without food: an empty belly (not "full right now")
	var crops: Array = Data.CROPS.keys()
	rec["likes"]["food"] = crops[0]          # likes are seeded from the random uid: pin them so kibble is never
	rec["likes"]["hates"] = crops[1]         # the hated food (refused) nor the loved one (fills more)
	Save.d["items"]["kibble"] = 5
	ok(HungerGate.meals_needed(rec) == 2, "24 h of starving: two meals (%d)" % HungerGate.meals_needed(rec))
	home._confirm_start()
	await _frames(2)
	var gate := _find_gate(home)
	await _shot("hunger_1_needs_two", 0.3)
	ok(gate != null and home.panel_open == "Too hungry to go", "the Too hungry panel is up with the gate")
	ok(_texts(gate).any(func(t): return t.contains("needs 2 more meals")),
		"it says exactly what it needs: %s" % [_texts(gate)])
	ok(_button(gate, "Go") == null, "no Go while it is too hungry")
	var feed := _button(gate, "Feed")
	ok(feed != null and not feed.disabled, "a Feed button is right there")
	feed.pressed.emit()
	await _frames(2)
	await _shot("hunger_2_one_meal_left", 0.2)
	ok(_texts(gate).any(func(t): return t.contains("needs 1 more meal.")), "one meal in: the count drops live")
	ok(home.panel_open == "Too hungry to go", "the panel is still the same one")
	rec["needs"]["food"] = 10.0
	_button(gate, "Feed").pressed.emit()
	await _frames(2)
	ok(HungerGate.meals_needed(rec) == 0 and _button(gate, "Go") != null, "past the line: Go is offered, no reopening")
	ok(Save.d["items"]["kibble"] == 3, "two kibble were used")
	var enter_b: Button = _primary(home)
	ok(enter_b != null and enter_b.text == "Go" and not enter_b.disabled, "Enter would press Go")
	# something else feeding it (a feeder) also moves the gate without a click
	home._close_panel()
	rec["starve"] = 20.0 * 3600.0
	home._confirm_start()
	await _frames(2)
	gate = _find_gate(home)
	ok(_texts(gate).any(func(t): return t.contains("needs 1 more meal.")), "20 h: one meal")
	Care.fed(rec)
	await _frames(60)
	ok(_button(gate, "Go") != null, "fed from elsewhere: the gate notices on its own")
	home._close_panel()
	home.queue_free()
	await _frames(2)

func _primary(home) -> Button:
	for ch in home.panel_host.get_children():
		if ch.has_meta("primary"):
			return ch.get_meta("primary")
	return null

func _find_gate(n: Node) -> HungerGate:
	if n is HungerGate:
		return n
	for c in n.get_children():
		var r := _find_gate(c)
		if r != null:
			return r
	return null

func _texts(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		if not c.is_queued_for_deletion():
			_texts(c, out)
	return out

func _button(n: Node, starts: String) -> Button:
	if n is Button and (n as Button).text.begins_with(starts) and not n.is_queued_for_deletion():
		return n
	for c in n.get_children():
		var r := _button(c, starts)
		if r != null:
			return r
	return null

func _shot(file: String, secs: float) -> void:
	if shots == "":
		return
	await main.get_tree().create_timer(secs).timeout
	main.get_viewport().get_texture().get_image().save_png(shots.path_join(file + ".png"))
