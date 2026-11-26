extends RefCounted
## --wisp-default-check: every player gets the Boki wisp and the C summon (the owner's wisp rule, decision 0172).
## Any settings file (none, one from before the wisps default, a 0.24.27 one with "off" saved) loads with wisps
## on, and a saved "off" does not come back. No menu's match opts (Training Grounds, Demo Match, a bot duel, the
## Test Zone, the tutorial, Heart Raid, an expedition, an online lobby start) turn them off. In a match started
## from the Training Grounds opts the Boki is a wisp, and a real C key press (C is both the Summon key and the
## Boki key) bursts it out on its own: the release sends no Sic, perks off. C again folds
## it back into the wisp with no Call back, and its perks are on again. Prints PASS/FAIL.

const DT := 1.0 / 60.0

var bad := 0
var main: Node


func run(main_node: Node) -> void:
	main = main_node
	_files()
	_menu_opts()
	await _c_key()
	print("WISPDEFAULT %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)


func ok(cond: bool, what: String) -> void:
	print("WISPDEFAULT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _files() -> void:
	var cases := {
		"no settings file": {},
		"a file from before the wisps default": {"boki_wisps": false},
		"a 0.24.27 file with off saved": {"boki_wisps": false, "wisps_v": 1},
		"a 0.24.27 file left on": {"boki_wisps": true, "wisps_v": 1},
	}
	for tag in cases:
		DirAccess.remove_absolute(Settings.path)
		var cf := ConfigFile.new()
		for key in cases[tag]:
			cf.set_value("s", key, cases[tag][key])
		if not (cases[tag] as Dictionary).is_empty():
			cf.save(Settings.path)
		Settings.load_file()
		ok(Settings.get_v("boki_wisps") == true, "%s: Boki ride as wisps" % tag)
	Settings.set_v("boki_wisps", false)  # (saves the file)
	Settings.load_file()
	ok(Settings.get_v("boki_wisps") == true, "a saved off does not come back on the next start")
	DirAccess.remove_absolute(Settings.path)
	Settings.load_file()


func _menu_opts() -> void:
	var lobby := {"net": {}, "seed": 1, "teams": 7, "squad": 3, "tier": 0}
	var home := {"teams": 7, "squad": 3, "total": Data.MATCH_PLAYERS, "tier": 0}
	var menus := {
		"Training Grounds": Match.arena_opts(),
		"Demo Match": Match.demo_opts(),
		"bot duel": Match.duel_opts(),
		"Test Zone": TestZone.opts(),
		"tutorial": TutorialResume.opts(),
		"Heart Raid": HeartRaid.opts(3),
		"expedition": home,
		"online lobby": lobby,
	}
	var m := Match.new()
	for tag in menus:
		m.opts = menus[tag]
		ok(KinWisp.mode(m), "%s: the match's own Boki ride as wisps" % tag)
	m.free()


## A real C key event (C is bound to both actions), read the way Match._process does: the Boki key poll,
## then the Summon press.
## True when it was a Boki-key tap (a Sic, or a Call back once it is out).
func _key_c(m: Match, down: bool) -> bool:
	await main.get_tree().process_frame  # (a fresh frame: "just pressed" is per frame, and m.step does not advance it)
	var ev := InputEventKey.new()
	ev.keycode = KEY_C
	ev.physical_keycode = KEY_C
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var tapped := KinCommand.poll(m.player, DT, false) == "tap"
	if tapped:
		KinCommand.tap(m.player)
	if Input.is_action_just_pressed("summon"):
		KinSummon.press(m.player)
	return tapped


func _steps(m: Match, n: int) -> void:
	for i in n:
		m.step(DT)


func _c_key() -> void:
	var m := Match.new()
	main.add_child(m)
	var o := Match.arena_opts()
	o["demo_kin"] = "cindle"
	m.start(o)
	m.set_process(false)
	_steps(m, 20)
	var p: Hunter = m.player
	var k: Kin = p.kin
	ok(k != null and k.wisp and k.state == "shoulder" and p.kin_carry_on(), "match start: a wisp, its perks on")
	var both: bool = Settings.key_cap("summon") == "C" and Settings.key_cap("throw") == "C"
	ok(both, "C is the Summon key and the Boki key (%s, %s)" % [Settings.key_cap("summon"), Settings.key_cap("throw")])
	await _key_c(m, true)
	_steps(m, 6)
	var sic: bool = await _key_c(m, false)
	_steps(m, 30)
	ok(not k.wisp and k.summon.out(), "C: the full Boki is out (window %.1f s)" % k.summon.left)
	ok(not sic, "...and the release sends no Sic at the cursor (the old C)")
	ok(not p.kin_carry_on(), "...its perks off while it is out")
	await _key_c(m, true)
	_steps(m, 6)
	var back: bool = await _key_c(m, false)
	ok(not back and k.summon.left == 0.0, "C again: it goes back, with no Call back on the release")
	_steps(m, 90)
	ok(k.wisp and k.state == "shoulder" and k.summon.cd > 0.0, "...it folds back into the wisp, cooling down")
	ok(p.kin_carry_on(), "...and its perks are on again")
	m.queue_free()
