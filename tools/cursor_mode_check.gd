extends RefCounted
## --cursor-mode-check: the OS cursor's mode in every screen state (CursorMode). A live match, the
## Training Area, the Arena and the Duel room (unpaused) hide it and, with Settings "Keep cursor in
## window" (default on), confine it; the Esc menu, the hunter picker, the kit card, the loadout
## menu, the duel menu, the results screen of a real match (where the lobby, farm and title carry on) show it. With
## the setting off a fight only hides it. Headless has no cursor to read back, so the asserts read
## CursorMode.current, which is the mode the game asked the OS for.

var bad := 0
const OPTS := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
const CONFINED := Input.MOUSE_MODE_CONFINED_HIDDEN
const SHOWN := Input.MOUSE_MODE_VISIBLE

func ok(cond: bool, what: String) -> void:
	print("CURSOR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _is(want: int, what: String) -> void:
	ok(CursorMode.current == want, "%s: mode %d (want %d)" % [what, CursorMode.current, want])

func _start(main: Node, extra: Dictionary) -> Match:
	var o: Dictionary = OPTS.duplicate()
	o.merge(extra, true)
	var m := Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	await main.get_tree().process_frame
	return m

func run(main: Node) -> void:
	var tree := main.get_tree()
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["cls"] = "medium"
	d["arch"] = "gunslinger"
	d["classes"] = ClassUnlock.legacy()
	Save.d = d
	Settings.reset_all()
	ok(bool(Settings.get_v("cursor_confine")), "Keep cursor in window is on by default")
	CursorMode.menu()
	_is(SHOWN, "the lobby, farm and title (before a match)")
	var m := await _start(main, {"training": true, "practice": true})
	_is(CONFINED, "Training Area, live")
	var pr := Practice.of(m)
	(pr.bar_btns["hero"] as Button).pressed.emit()
	ok(m.paused, "the picker pauses the game")
	_is(SHOWN, "Training Area, hunter picker")
	PracticeHero.close(pr)
	_is(CONFINED, "Training Area, picker closed")
	var was: Node = main.get("current")
	main.set("current", m)         # (the Esc menu finds the match through the current screen)
	Overlay.open_pause("match")
	_is(SHOWN, "Training Area, pause menu")
	Overlay.open_settings()
	_is(SHOWN, "Training Area, settings")
	Overlay.close()
	_is(CONFINED, "Training Area, menu closed")
	Settings.set_v("cursor_confine", false)
	CursorMode.aim()
	_is(Input.MOUSE_MODE_HIDDEN, "Training Area, setting off: hidden only")
	Settings.set_v("cursor_confine", true)
	CursorMode.aim()
	main.set("current", was)
	m.queue_free()
	await tree.process_frame
	m = await _start(main, Match.arena_opts("gunslinger"))
	_is(CONFINED, "Arena, live")
	m.arena.toggle_card()
	_is(SHOWN, "Arena, kit card")
	m.arena.toggle_card()
	_is(CONFINED, "Arena, card closed")
	m.arena.open_menu()
	_is(SHOWN, "Arena, loadout menu")
	m.arena.close_menu()
	_is(CONFINED, "Arena, menu closed")
	m.queue_free()
	await tree.process_frame
	m = await _start(main, Match.duel_opts())
	_is(CONFINED, "Duel room, live")
	m.duel.open_menu()
	_is(SHOWN, "Duel room, menu")
	m.duel.close_menu()
	_is(CONFINED, "Duel room, menu closed")
	m.queue_free()
	await tree.process_frame
	m = await _start(main, {"teams": 2, "squad": 1, "tier": 0, "seed": 77, "no_drop": true})
	_is(CONFINED, "a real match, live")
	m._finish()
	_is(SHOWN, "a real match, results screen")
	m.queue_free()
	print("CURSOR DONE, failures: %d" % bad)
	tree.quit()
