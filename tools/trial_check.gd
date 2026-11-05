extends RefCounted
## --trial-check: the Trial Expedition, then a quiet first real expedition (item 93).
##   1. the lessons come in the owner's order: move, dash, air dash, glide, crouch, pick up, the fight
##      (weapon, abilities, G and the Boki), level up, key and chest, the outpost, extract
##   2. each lesson pauses: its card comes up and the world waits (no time passes, nobody moves) until a
##      key; a key in the first READ_T doesn't close it
##   3. nothing moves on by itself: after its card, every lesson that needs you is still waiting after
##      IDLE_S of standing still; then the driver plays it and the Trial still finishes
##   4. skippable and replayable: a new save heads into the Trial and skipping it at the hatch marks it
##      done and goes home; the pause menu offers "Skip the Trial"; the first Trial ends on the results
##      and marks it played; the expedition panel replays it, and a replay goes straight home
##   5. a real expedition is quiet: no Trial, none of the old timed tips, every tip in the lane is logged
##   6. a first-time tip shows once and lands in the Tips log, which lists it; tips off shows none; the
##      Trial shows none
##   7. a locked chest without a key: one short reminder card ("Chests need a key"), not a toast
##   8. save migration: old tip flags move into the Tips log; an old save file loads with them

const ORDER := ["land", "move", "dash", "exdash", "glide", "crouch", "pickup", "shoot", "sig", "utility", "gkey",
		"throw", "orders", "kin1", "fight", "rank", "key", "chest", "goexit", "uplink", "defend", "extract"]
## Lessons that wait for you (land falls by itself, kin1 is watched, the fight and the defence can be
## won by your Boki or the outpost while you stand there).
const WAITS := ["move", "dash", "exdash", "glide", "crouch", "pickup", "shoot", "sig", "utility", "gkey", "throw",
		"orders", "rank", "key", "chest", "goexit", "uplink", "extract"]
const IDLE_S := 30.0         # s of standing still after a lesson's card
const HOLD_S := 1.0          # s a card is left unanswered (the world must not move)
const QUIET_S := 20.0        # s of a real expedition's start watched for tutorial text
## Teaching lines a real expedition used to show (the Trial teaches them now).
const OLD_TIPS := ["Hold left click to shoot", "sends your Boki", "Start the uplink, hold the yard",
		"Steer to choose where you land"]
const INPUTS := ["fire", "glide", "interact", "crouch", "sec", "sec_hold", "sig", "jump", "dash", "throw"]

var bad := 0
var main: Node
var m: Match
var screens: Array = []

func ok(cond: bool, what: String) -> void:
	print("TRIAL %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Game.screen_changed.connect(func(s): screens.append(s))
	_order()
	_lessons()
	await _flows()
	_quiet()
	_migration()
	print("TRIAL DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _new_save() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d

func _match(o: Dictionary) -> Match:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	var opts := o.duplicate()
	opts["demo_kin"] = "cindle"
	m.start(opts)
	m.set_process(false)
	return m

func _still() -> void:
	for k in INPUTS:
		m.player.inp[k] = false
	m.player.inp["move"] = Vector2.ZERO

# ------------------------------------------------------------------ 1. the order
func _order() -> void:
	var ids: Array = Tutorial.steps().map(func(s): return String(s[0]))
	ok(ids == ORDER, "the lessons come in the owner's order (%s)" % ", ".join(ids))

# ------------------------------------------------------------------ 2, 3. each lesson pauses and waits
func _lessons() -> void:
	_new_save()
	_match(Tutorial.opts())
	var tu: Tutorial = m.tut
	var shown: Array = []
	var frozen := {}
	var waited := {}
	var early_closed := false
	var t := 0.0
	while t < 1500.0 and not m.player.extracted:
		if tu.card and not shown.has(tu.id()):
			shown.append(tu.id())
			if shown.size() == 1:
				tu.ack()      # (a key straight away: too soon, the card stays)
				early_closed = not tu.card
			frozen[tu.id()] = _held(tu)
			if tu.id() in WAITS:
				waited[tu.id()] = _idle(tu)
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
	ok(m.player.extracted, "the Trial still finishes after all the waiting (%.0fs)" % t)
	ok(shown == ORDER, "every lesson opens with its card, in order (%s)" % ", ".join(shown))
	ok(not early_closed, "a key in the first %.1fs doesn't close a card (it can't be skipped unread)" % Tutorial.READ_T)
	var moved: Array = frozen.keys().filter(func(id): return not frozen[id])
	var all_frozen := frozen.size() == ORDER.size() and moved.is_empty()
	ok(all_frozen, "the world waits while each card is up (moved on: %s)" % str(moved))
	var gone: Array = waited.keys().filter(func(id): return not waited[id])
	var all_in := waited.size() == WAITS.size()
	var why := "(moved on: %s)" % str(gone)
	ok(all_in and gone.is_empty(), "no lesson moves on by itself in %.0fs of standing still %s" % [IDLE_S, why])

## Leaves the card up for HOLD_S without a key: no time passes, the hunter and the Boki don't move.
## Then a key closes it. True when the world waited.
func _held(tu: Tutorial) -> bool:
	var t0 := m.time
	var at := m.player.pos
	var kin_at: Vector3 = m.player.kin.pos if m.player.kin else Vector3.ZERO
	var held := 0.0
	while held < HOLD_S:
		m.step(Match.DT)
		held += Match.DT
	var still := m.time == t0 and m.player.pos == at and (m.player.kin == null or m.player.kin.pos == kin_at)
	var up := tu.card
	tu.ack()
	return still and up and not tu.card

## Stands still for IDLE_S after a lesson's card. True when the lesson is still the same.
func _idle(tu: Tutorial) -> bool:
	var at := tu.step
	var t := 0.0
	while t < IDLE_S and not m.player.extracted:
		_still()
		m.step(Match.DT)
		t += Match.DT
	return tu.step == at and not tu.card

# ------------------------------------------------------------------ 4. skip and replay
func _flows() -> void:
	_new_save()
	var gm: Node = Game.main
	var hatch = load("res://scripts/ui/hatch.gd").new()
	Game.main = null      # (where it would go is caught from screen_changed; no screen really changes)
	hatch._head_out(true)
	var first: Dictionary = Game.match_opts
	ok(_last() == "match" and first.get("tutorial", false) and not first.get("trial_replay", false),
			"a new save heads out into the Trial Expedition (%s)" % _last())
	hatch._head_out(false)
	var skipped := _last() == "home" and bool(Save.d["tutorial"].get("match", false))
	ok(skipped, "skipping it at the hatch marks it done and goes home")
	hatch.free()
	Game.main = gm
	# the pause menu in the Trial
	_new_save()
	_match(Tutorial.opts())
	m.step(Match.DT)
	var was = main.current
	main.current = m
	Overlay.open_pause("match")
	var texts := _button_texts(Overlay.host)
	Overlay.close()
	main.current = was
	var offers := texts.has("Skip the Trial") and texts.has("Tips log")
	ok(offers, "the pause menu offers Skip the Trial and the Tips log (%s)" % str(texts))
	# the reminder card (7), on the Trial's locked chest
	var c: Dictionary = m.chests.filter(func(x): return x.get("tut", false))[0]
	m.player.chest_keys = 0
	KeyChest.deny(m, m.player, c)
	var lane_has_locked: bool = m.hud.msgs.texts().any(func(x): return String(x).contains("Locked"))
	var reminded := m.tips.remind_text == "Chests need a key" and m.tips.remind_t > 0.0
	ok(reminded and not lane_has_locked, "a locked chest without a key: one reminder card, not a toast")
	# skipping the first Trial: the results, and it counts as played
	Game.main = null
	Practice.leave(m, true)
	var played := bool(Game.last_result.get("tutorial", false)) and bool(Save.d["tutorial"].get("match", false))
	ok(_last() == "results" and played,
			"skipping or finishing the first Trial ends on its results and marks it played")
	Game.main = gm
	# the expedition panel replays it
	var hm = await main._hb_home()
	hm._open_expedition()
	await main.get_tree().process_frame
	var replay := _button(hm.panel_host, "Trial Expedition")
	ok(replay != null, "the expedition panel has a Trial Expedition button")
	if replay:
		Game.main = null
		replay.pressed.emit()
		var o: Dictionary = Game.match_opts
		var again: bool = o.get("tutorial", false) and o.get("trial_replay", false)
		ok(_last() == "match" and again, "and it starts a replay of the Trial")
		Game.main = gm
	hm._close_panel()
	hm.queue_free()
	await main.get_tree().process_frame
	var matches_before := int(Save.d["matches"])
	_match(Tutorial.opts(true))
	m.step(Match.DT)
	Game.main = null
	Practice.leave(m, true)
	Game.main = gm
	var kept_nothing := int(Save.d["matches"]) == matches_before
	ok(_last() == "home" and kept_nothing, "a replay goes straight home, nothing carried over")

func _last() -> String:
	return String(screens[-1]) if not screens.is_empty() else ""

func _button_texts(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append((n as Button).text.strip_edges())
	for ch in n.get_children():
		out.append_array(_button_texts(ch))
	return out

func _button(n: Node, txt: String) -> Button:
	if n is Button and (n as Button).text.strip_edges() == txt:
		return n
	for ch in n.get_children():
		var b := _button(ch, txt)
		if b:
			return b
	return null

# ------------------------------------------------------------------ 5, 6. a quiet expedition, tips once
func _quiet() -> void:
	_new_save()
	Settings.v["tips"] = true
	_match({"teams": 2, "squad": 1, "tier": 0, "length": 1500.0, "seed": 4242, "big": false})
	ok(m.tut == null, "a real expedition has no Trial")
	var t := 0.0
	var seen := {}
	while t < QUIET_S:
		_still()
		m.step(Match.DT)
		m.tips.tick(Match.DT)
		t += Match.DT
		for x in m.hud.msgs.texts():
			seen[String(x)] = true
	print("  the first %.0fs: out %s, lane %s" % [t, m.player.out, str(seen.keys())])
	var old: Array = seen.keys().filter(func(x): return OLD_TIPS.any(func(o): return String(x).contains(o)))
	ok(old.is_empty(), "none of the old timed tips show in the first seconds (%s)" % str(old))
	var logged: Array = MatchTips.seen().map(func(id): return MatchTips.text(id))
	var tip_lines: Array = MatchTips.lines().keys().map(func(id): return MatchTips.text(id))
	var tips_seen: Array = seen.keys().filter(func(x): return tip_lines.has(x))
	ok(tips_seen.all(func(x): return logged.has(x)), "every tip that showed is in the log (%s)" % str(tips_seen))
	# a first-time tip: once, logged, listed
	Save.d["tips"] = []
	m.hud.msgs.clear()
	m.player.downed = true
	m.tips.tick(Match.DT)
	var line := MatchTips.text("down")
	var shown_once: bool = m.hud.msgs.texts().has(line) and MatchTips.seen().has("down")
	ok(shown_once, "a first-time tip shows and lands in the log ('%s')" % line)
	m.hud.msgs.clear()
	m.tips.tick(Match.DT)
	ok(not m.hud.msgs.texts().has(line) and MatchTips.seen().count("down") == 1, "and never shows again")
	var page := VBoxContainer.new()
	TipsLog.fill(page)
	ok(_label_texts(page).has(line), "the Tips log lists it")
	page.free()
	Save.d["tips"] = []
	Settings.v["tips"] = false
	m.tips.tick(Match.DT)
	ok(MatchTips.seen().is_empty() and not m.hud.msgs.texts().has(line), "with tips off, none show")
	Settings.v["tips"] = true
	m.player.downed = false
	_match(Tutorial.opts())
	m.step(Match.DT)
	m.tips.show("down")
	ok(MatchTips.seen().is_empty(), "the Trial shows no tips")
	m.queue_free()
	m = null

func _label_texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	for ch in n.get_children():
		out.append_array(_label_texts(ch))
	return out

# ------------------------------------------------------------------ 8. the save migration
func _migration() -> void:
	var old := {"tutorial": {"home": true, "down": true, "rings": true, "move": true, "ability": true}}
	MatchTips.migrate(old)
	var flags: Dictionary = old["tutorial"]
	var moved: bool = old["tips"] == ["down", "rings"] and not flags.has("down") and not flags.has("move")
	ok(moved and flags.get("home", false), "old tip flags move into the Tips log, other flags stay (%s)" % str(old))
	var d := Save.fresh()
	d.erase("tips")
	d["tutorial"] = {"home": true, "stagger": true}
	var path := "user://trial_check_old_save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	Save.load_from(path)
	var loaded := MatchTips.seen() == ["stagger"] and bool(Save.d["tutorial"].get("home", false))
	ok(loaded, "an old save file loads, its seen tips in the log")
	DirAccess.remove_absolute(path)
