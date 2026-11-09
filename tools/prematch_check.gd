extends RefCounted
## --prematch-check: the pre-match lobby (Prematch, PrematchView, docs/decisions/0019-prematch-lobby.md).
## The 30 s countdown and the lock at 0, picks refused once locked (and for a Hunter that isn't open),
## the admin toggle (Settings lobby_enabled) and which matches get a lobby, the squad the lobby and the
## loading screen share, the options the match starts with, chat lines, the voice hook, and the screen.

var bad := 0
const EXPEDITION := {"teams": 10, "squad": 2, "tier": 0}

func ok(cond: bool, what: String) -> void:
	print("PREMATCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	d["name"] = "Tester"
	d["arch"] = "gunslinger"
	var c := ClassUnlock.fresh()                    # two Hunters open, the rest still shut
	c["picks"] = ["gunslinger"]
	c["open"] = ["gunslinger", "bulwark"]
	d["classes"] = c
	Save.d = d
	_countdown()
	_pick_lock()
	_toggle()
	_squad_and_launch()
	_chat_and_voice()
	await _screen(main)
	print("PREMATCH DONE, failures: %d" % bad)
	main.get_tree().quit()

func _countdown() -> void:
	var pm := Prematch.new(EXPEDITION.duplicate())
	ok(Prematch.DURATION == 30.0 and pm.left == 30.0, "the lobby starts at 30 seconds")
	pm.tick(10.0)
	ok(is_equal_approx(pm.left, 20.0) and not pm.locked, "10 s later 20 s are left, picks still open")
	pm.tick(19.9)
	ok(not pm.locked, "0.1 s before the end picks are still open")
	pm.tick(0.2)
	ok(pm.left == 0.0 and pm.locked, "at 0 the timer stops and picks lock")
	var goes := 0
	for i in 400:
		if pm.tick(0.01): goes += 1
	ok(goes == 1, "after the lock hold the match loads, exactly once (%d)" % goes)

func _pick_lock() -> void:
	var open := Arch.ids().filter(func(a): return ClassUnlock.is_open(a))
	var shut := Arch.ids().filter(func(a): return not ClassUnlock.is_open(a))
	var pm := Prematch.new(EXPEDITION.duplicate())
	ok(not open.is_empty() and pm.pick != "", "you start on your saved Hunter (%s)" % pm.pick)
	var other: String = String(open.filter(func(a): return a != pm.pick)[0]) if open.size() > 1 else pm.pick
	ok(pm.choose(other) and pm.pick == other, "an open Hunter can be picked before the lock")
	if not shut.is_empty():
		ok(not pm.choose(String(shut[0])) and pm.pick == other, "a Hunter that isn't open is refused")
	pm.tick(Prematch.DURATION)
	var before := pm.pick
	var swapped := pm.choose(String(open[0]) if String(open[0]) != before else String(open[open.size() - 1]))
	ok(not swapped and pm.pick == before, "after the lock a pick changes nothing")

func _toggle() -> void:
	var was: Variant = Settings.v.get("lobby_enabled")
	Settings.v.erase("lobby_enabled")
	var on_by_default: bool = Settings.get_v("lobby_enabled") and Prematch.wanted(EXPEDITION)
	ok(on_by_default, "on by default: an expedition gets the lobby")
	Settings.v["lobby_enabled"] = false
	ok(not Prematch.wanted(EXPEDITION), "lobby_enabled off: no lobby, the plain loading screen")
	Settings.v["lobby_enabled"] = true
	for k in ["tutorial", "training", "arena", "duel", "demo_match", "autoplay"]:
		var o := EXPEDITION.duplicate()
		o[k] = true
		ok(not Prematch.wanted(o), "%s never gets the lobby" % k)
	ok(not Prematch.wanted({"teams": 1, "squad": 1}), "a one-team match (training) never gets the lobby")
	if was == null: Settings.v.erase("lobby_enabled")
	else: Settings.v["lobby_enabled"] = was

func _squad_and_launch() -> void:
	var o := EXPEDITION.duplicate()
	Prematch.deal_mates(o)
	ok(o["mates"].size() == 1 and Arch.exists(String(o["mates"][0]["arch"])), "a duo is dealt one bot mate")
	var again := (o["mates"] as Array).duplicate(true)
	Prematch.deal_mates(o)
	ok(o["mates"] == again, "mates are dealt once")
	var solo := {"teams": 10, "squad": 1}
	Prematch.deal_mates(solo)
	ok(not solo.has("mates"), "solo has no mates")
	var sq := Prematch.squad_of(o, "gunslinger")
	var you_first: bool = sq.size() == 2 and sq[0]["you"] and sq[0]["arch"] == "gunslinger" and not sq[1]["you"]
	ok(you_first, "the squad is you first, then your mate")
	var pm := Prematch.new(o)
	var open := Arch.ids().filter(func(a): return ClassUnlock.is_open(a) and a != pm.pick)
	var other: String = String(open[0]) if not open.is_empty() else pm.pick
	pm.choose(other)
	pm.tick(Prematch.DURATION)
	var lo := pm.launch_opts()
	var kept: bool = lo["arch"] == other and Save.d["arch"] == other and lo["mates"] == o["mates"]
	ok(kept, "the locked pick is what the match starts with and what is saved")

func _chat_and_voice() -> void:
	ok(Prematch.clean_chat("  push north\nnow  ") == "push north now", "a chat line is trimmed and one line")
	var capped := Prematch.clean_chat("x".repeat(500)).length()
	ok(capped == Prematch.CHAT_MAX, "a chat line is capped at %d characters" % Prematch.CHAT_MAX)
	var v := VoiceChat.new()
	var seen: Array = []
	v.set_talking(true)
	ok(v.talking and not v.available(), "without a transport the hook only tracks talking")
	v.transport = func(on: bool): seen.append(on)
	v.set_talking(false)
	ok(v.available() and seen == [false] and not v.talking, "a transport gets push-to-talk changes")

func _screen(main: Node) -> void:
	var o := EXPEDITION.duplicate()
	Prematch.deal_mates(o)
	var view: Control = load("res://scripts/ui/prematch_view.gd").new()
	view.setup(o)
	main.add_child(view)
	await main.get_tree().process_frame
	ok(view.grid.get_child_count() == Arch.ids().size(), "the screen shows every Hunter")
	ok(view.squad_box.get_child_count() == 2, "the screen shows your squad")
	ok(view.timer_label.text == "0:30", "the screen counts down from 0:30 (%s)" % view.timer_label.text)
	_declutter(view)
	var line_only: bool = not view.chat_scroll.visible and not view.chat_in.visible and view.chat_hint.visible
	ok(line_only, "the chat is one 'Enter to chat' line until a message comes")
	view._show_chat_line(true)
	ok(view.chat_in.visible and not view.chat_hint.visible, "Enter opens the input in place of the line")
	var ink: Color = view.timer_label.get_theme_color("font_color")
	ok(view.note_label.text == "" and ink == UI.INK, "30 s out: plain digits, no note")
	view.pm.left = 4.0
	view._tick_label()
	ok(view.timer_label.get_theme_color("font_color") != ink, "the last seconds turn the digits red")
	view.pm.left = 30.0
	view._tick_label()
	view.chat_in.text = "hello"
	view._send_chat()
	await main.get_tree().process_frame
	ok(view.chat_log.get_child_count() == 1 and view.chat_in.text == "", "a sent chat line shows in the log")
	var log_open: bool = view.chat_scroll.visible and view.chat_hint.visible and not view.chat_in.visible
	ok(log_open, "the first message opens the log and the input folds back")
	view.pm.pick = "bulwark"
	view.pm.left = 0.0
	view._process(0.0)
	ok(view.pm.locked and view.timer_label.text == "0:00", "at 0 the digits read 0:00 and the pick locks")
	var note: String = view.note_label.text
	ok(note.contains("locked in") and note.contains(HunterViewer.display_name("bulwark")), "the note names the pick")
	view.set_process(false)
	view.queue_free()

## Cards are portrait + name + role word (stats and quests on hover); shut ones are dim with a padlock; the
## voice button waits for a human squadmate.
func _declutter(view: Control) -> void:
	var padlock = view.get_script().Padlock
	var open := 0
	var shut_ok := true
	for card in view.grid.get_children():
		var ak: String = card.get_meta("arch")
		var role := String(Arch.def(ak)["card"]["role_word"])
		var texts: Array = card.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
		var lock: bool = card.find_children("*", "Control", true, false).any(func(c): return c.get_script() == padlock)
		var shut := not ClassUnlock.is_open(ak)
		open += 0 if shut else 1
		var quest := "Locked: " + ClassUnlock.requirement(ak)
		var plain: bool = texts.size() == 2 and texts[0] == HeroTitle.base_name(ak) and texts[1].begins_with(role)
		var tip: String = card.tooltip_text
		var tip_ok := tip.contains("health") and (not shut or tip.begins_with(quest))
		shut_ok = shut_ok and plain and lock == shut and tip_ok
	ok(open == 2 and shut_ok, "each card is name + role word, shut ones have a padlock, hover has stats and quest")
	ok(not view.talk_btn.visible, "no hold-to-talk without a voice transport and a human squadmate")
	var fits: Array = load("res://tools/prematch_shots.gd").new().outside(view, Rect2(Vector2.ZERO, view.size))
	ok(fits.is_empty(), "every element sits inside the screen's safe margin (%s)" % [fits.slice(0, 2)])
