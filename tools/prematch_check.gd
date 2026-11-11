extends RefCounted
## --prematch-check: the pre-match lobby (Prematch, PrematchView, docs/decisions/0019-prematch-lobby.md).
## Turns: offline you pick first, then bot mates instantly, each squad's Hunters unique, a run-out turn
## gets a random untaken one, then the lock; online picking waits for the whole lobby to load, teammates'
## picks only count on their turn, a lost or gone teammate is picked for. Also the admin toggle (Settings
## lobby_enabled) and which matches get a lobby, the squad the loading screen shows, the options the match
## starts with, bot fill-ins never doubling a squadmate, chat lines, the voice hook, and the screen
## (the turn banner, the declutter cards, the safe margin).

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
	_turns()
	_online()
	_bot_fill()
	_toggle()
	_squad()
	_chat_and_voice()
	await _screen(main)
	print("PREMATCH DONE, failures: %d" % bad)
	main.get_tree().quit()

func _turns() -> void:
	var o := {"teams": 10, "squad": 3, "tier": 0, "seed": 7}
	Prematch.deal_mates(o)
	var dealt: Array = o["mates"].map(func(m): return m["arch"])
	var unique: bool = dealt.size() == 2 and dealt[0] != dealt[1] and not dealt.has("gunslinger")
	ok(unique, "a trio's bot mates are dealt Hunters nobody else on the squad has (%s)" % [dealt])
	var pm := Prematch.new(o)
	ok(pm.turn == -1 and pm.loaded_count() == Vector2i(1, 1), "offline nobody else has to load")
	ok(not pm.choose("gunslinger"), "no pick before picking starts")
	pm.tick(0.01)
	ok(pm.turn == 0 and pm.my_turn() and pm.squad[0]["you"], "offline you pick first")
	ok(pm.turn_left == Prematch.TURN and Prematch.TURN == 10.0, "a turn is 10 seconds")
	o["mates"][0]["arch"] = "bulwark"               # a bot dealt the Hunter you are about to take
	pm.squad[1]["deal"] = "bulwark"
	ok(pm.choose("bulwark") and pm.pick == "bulwark", "an open Hunter can be picked on your turn")
	var shut := Arch.ids().filter(func(a): return not ClassUnlock.is_open(a))
	ok(not pm.choose(String(shut[0])) and pm.pick == "bulwark", "a Hunter that isn't open is refused")
	pm.tick(9.0)
	ok(pm.my_turn() and pm.choose("gunslinger"), "you can change your mind until the turn runs out")
	pm.tick(1.01)
	var bots_done: bool = pm.squad.all(func(m): return m["done"])
	ok(bots_done and pm.locked, "once your turn runs out both bots pick at once and the picks lock")
	var archs: Array = pm.squad.map(func(m): return m["arch"])
	var all_unique: bool = archs.size() == 3 and archs[0] != archs[1] and archs[1] != archs[2] and archs[0] != archs[2]
	ok(all_unique and archs[0] == "gunslinger", "no two on the squad play the same Hunter (%s)" % [archs])
	ok(pm.taken_by("gunslinger") == "Tester", "a taken Hunter names who took it")
	var goes := 0
	for i in 400:
		if pm.tick(0.01): goes += 1
	ok(goes == 1, "after the lock hold the match loads, exactly once (%d)" % goes)
	var lo := pm.launch_opts()
	var mates_kept: bool = lo["mates"].map(func(m): return m["arch"]) == archs.slice(1)
	var started: bool = lo["arch"] == "gunslinger" and Save.d["arch"] == "gunslinger" and mates_kept
	ok(started, "the match starts with the picks, yours saved")
	var idle := Prematch.new({"teams": 10, "squad": 1, "tier": 0, "seed": 3})
	idle.tick(0.01)
	idle.tick(Prematch.TURN + 0.01)
	var auto_ok := idle.locked and ClassUnlock.is_open(idle.pick)
	ok(auto_ok, "a turn that runs out gives you a random open Hunter (%s)" % idle.pick)

## Online: three on your squad, one rival who mirrors a pick. Peer "2" is you.
func _online() -> void:
	var was_me := Net.me
	var was_peers := Net.peers
	Net.me = "2"
	Net.peers = {"1": {}, "2": {}, "3": {}, "4": {}}
	var roster := []
	for p in ["1", "2", "3", "4"]:
		roster.append({"peer": p, "team": 0 if p != "4" else 1, "name": "N" + p, "arch": "gunslinger"})
	var o := {"teams": 10, "squad": 3, "seed": 5, "net": {"seed": 5, "roster": roster}}
	var pm := Prematch.new(o)
	var again := Prematch.new(o.duplicate(true))
	var order: Array = pm.squad.map(func(m): return m["peer"])
	var same: bool = order.size() == 3 and order == again.squad.map(func(m): return m["peer"])
	ok(same, "the pick order is the same on every client (%s)" % [order])
	pm.tick(5.0)
	ok(pm.turn == -1 and pm.loaded_count() == Vector2i(1, 4), "picking waits until everyone loads (1/4)")
	ok(pm.mark_loaded("1") and not pm.mark_loaded("1"), "a player's load is counted once")
	pm.mark_loaded("3")
	pm.mark_loaded("4")
	pm.tick(0.01)
	ok(pm.turn == 0 and pm.loaded_count() == Vector2i(4, 4), "with everyone loaded the first turn starts")
	var first: Dictionary = pm.picker()
	var later := String(pm.squad[2]["peer"]) if first["you"] else String(pm.squad[1]["peer"])
	ok(not pm.remote_pick(later, "mage", true), "a teammate's pick off their turn is refused")
	if first["you"]:
		pm.choose("gunslinger")
		pm.tick(Prematch.TURN)
	else:
		var live := pm.remote_pick(String(first["peer"]), "gunslinger", false)
		ok(live and pm.turn == 0, "a live pick shows, the turn goes on")
		ok(pm.remote_pick(String(first["peer"]), "gunslinger", true) and pm.turn == 1, "a final pick ends the turn")
	ok(pm.taken().has("gunslinger"), "the first pick is taken")
	var second: Dictionary = pm.picker()
	if second["you"]:
		ok(not pm.choose("gunslinger"), "you can't take a squadmate's Hunter")
		pm.choose("bulwark")
		pm.tick(Prematch.TURN)
	else:
		ok(not pm.remote_pick(String(second["peer"]), "gunslinger", true), "a teammate can't take a taken Hunter")
		pm.tick(Prematch.TURN + Prematch.GRACE + 0.01)
		ok(pm.turn == 2 and pm.squad[1]["done"], "a teammate whose pick never comes is picked for after the grace")
	var third: Dictionary = pm.picker()
	if third["you"]:
		pm.tick(Prematch.TURN)
	else:
		Net.peers.erase(String(third["peer"]))
		pm.tick(0.01)
	var archs: Array = pm.squad.map(func(m): return m["arch"])
	var unique: bool = archs[0] != archs[1] and archs[1] != archs[2] and archs[0] != archs[2]
	ok(pm.locked and unique, "every squad pick is unique, a gone teammate picked for at once (%s)" % [archs])
	# as peer 3, the last to pick: a silent teammate is picked for after the grace, a taken Hunter is refused
	Net.me = "3"
	Net.peers["3"] = {}
	var late := Prematch.new(o.duplicate(true))
	for p in ["1", "2", "4"]:
		late.mark_loaded(p)
	late.tick(0.01)
	late.tick(Prematch.TURN + Prematch.GRACE + 0.01)
	var picked_for: bool = late.turn == 1 and late.squad[0]["done"]
	ok(picked_for, "a teammate whose final pick never comes is picked for after the grace")
	var mate := String(late.picker().get("peer", ""))
	ok(not late.remote_pick(mate, String(late.squad[0]["arch"]), true), "a teammate can't take a taken Hunter")
	var lo := pm.launch_opts()
	var in_roster: Array = lo["net"]["roster"].map(func(r): return r["arch"])
	var carried: bool = in_roster.slice(0, 3).all(func(a): return archs.has(a)) and in_roster[3] == "gunslinger"
	ok(carried, "the roster carries the picks, the rival may mirror")
	Net.me = was_me
	Net.peers = was_peers

func _bot_fill() -> void:
	var taken := ["gunslinger", "ostra", "tender"]
	var got := Arch.pick_for("medium", "b7|99", taken)
	ok(got == "dolm", "a bot filling a squad skips Hunters the squad already has (%s)" % got)
	var unchanged := Arch.pick_for("medium", "b7|99") == Arch.pick("medium", _seeded("b7|99"))
	ok(unchanged, "with nothing taken the pick is unchanged")

func _seeded(key: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	return r

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

func _squad() -> void:
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
	ok(you_first, "the loading screen's squad is you first, then your mate")

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
	await main.get_tree().process_frame
	ok(view.grid.get_child_count() == Arch.ids().size(), "the screen shows every Hunter")
	ok(view.squad_box.get_child_count() == 2, "the screen shows your squad")
	ok(view.caption.text == "YOUR TURN", "the banner says it's your turn (%s)" % view.caption.text)
	ok(view.timer_label.text == "0:10", "the turn counts down from 0:10 (%s)" % view.timer_label.text)
	_declutter(view)
	var line_only: bool = not view.chat_scroll.visible and not view.chat_in.visible and view.chat_hint.visible
	ok(line_only, "the chat is one 'Enter to chat' line until a message comes")
	view._show_chat_line(true)
	ok(view.chat_in.visible and not view.chat_hint.visible, "Enter opens the input in place of the line")
	var ink: Color = view.timer_label.get_theme_color("font_color")
	ok(ink == UI.INK, "a fresh turn: plain digits")
	view.pm.turn_left = 2.0
	view._tick_label()
	ok(view.timer_label.get_theme_color("font_color") != ink, "the last seconds of your turn turn the digits red")
	view.pm.turn_left = Prematch.TURN
	view._tick_label()
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shots = a.substr(12)
	if shots != "":
		if main.fade != null:
			main.fade.reveal(0.05)      # (the boot splash would cover the screenshot)
		view.pm.tick(3.4)
		view._choose("bulwark")
		for i in 30:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(shots + "/prematch_turn.png")
	view.chat_in.text = "hello"
	view._send_chat()
	await main.get_tree().process_frame
	ok(view.chat_log.get_child_count() == 1 and view.chat_in.text == "", "a sent chat line shows in the log")
	var log_open: bool = view.chat_scroll.visible and view.chat_hint.visible and not view.chat_in.visible
	ok(log_open, "the first message opens the log and the input folds back")
	view._choose("bulwark")
	view.pm.tick(Prematch.TURN + 0.01)
	view._tick_label()
	ok(view.pm.locked and view.caption.text == "PICKS LOCKED", "once the squad has picked the banner says so")
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
