extends "res://tools/new_player_flow_check.gd"
## --tutorial-timing-check: ADVISORY. The whole new-player path on one fresh save (the same drivers as
## --new-player-flow-check) with a row per step printed as "TUTT": how long it took, the words on the
## screen, the keys it names, and whether those keys are live (every action rebound to F-keys: a cap that
## still reads the old key is a hard-coded name). Steps that nag (no progress for NAG_T) or come round again
## are flagged. Rows are written up in docs/TUTORIAL.md. Only a stall in the run fails it.
## Seconds: "sim" = game seconds of the instant-reacting TutorialDrive (no reading, no misses); "wall" =
## headless wall seconds of a screen; "n/a" = a step the driver marks done at once (farm, garden bot).

const NO_READ := ["A", "I"]      # caps that are also plain words: never counted as a hard-coded key name
const ACTIONS := ["up", "left", "down", "right", "dash", "crouch", "jump", "interact", "fire", "signature",
	"secondary", "ultimate", "throw", "gear1", "build", "details"]

var step_rec: Dictionary = {}
var steps_seen := 0
var last_step := -2
var live_done := false

func run(m: Node) -> void:
	main = m
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	main.get_window().size = Vector2i(1280, 720)
	await _prologue()
	await _hatch()
	var home = await _tutorial_match()
	await _farm_tutorial(home)
	await _second_relic(home)
	await _first_expedition(home)
	await _garden_first_day()
	_end()
	print("NPF TIMES (s): " + ", ".join(timings))
	print("TUTT DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)

func _words(txt: String) -> int:
	return txt.split(" ", false).size()

func row(section: String, id: String, secs: float, kind: String, txt: String, caps: String, flags: String) -> void:
	var cells := [section, id, "%.1f" % secs, kind, _words(txt), caps, flags, txt.replace("|", "/")]
	print("TUTT | " + " | ".join(cells.map(func(c): return str(c))))

## The caps of every action the doc watches, under the player's current keys.
func _all_caps() -> Array:
	return ACTIONS.map(func(a): return Settings.key_cap(a))

## Words on screen on a non-match screen: every visible label and button text under the current scene.
func screen_text() -> String:
	var parts: Array = []
	for c in main.current.find_children("*", "Control", true, false):
		if c is Label and (c as Label).is_visible_in_tree():
			parts.append((c as Label).text)
		elif c is Button and (c as Button).is_visible_in_tree():
			parts.append((c as Button).text)
		elif c is RichTextLabel and (c as RichTextLabel).is_visible_in_tree():
			parts.append((c as RichTextLabel).get_parsed_text())
	return " ".join(parts)

func _wait(cond: Callable, what: String, secs := STALL_S) -> bool:
	var t0 := Time.get_ticks_msec()
	var got: bool = await super._wait(cond, what, secs)
	var on_screens := stage_name in ["prologue", "first Relic"] or stage_name.begins_with("hatch")
	if on_screens and is_instance_valid(main.current):
		var took := (Time.get_ticks_msec() - t0) / 1000.0
		row("screens", "%s: %s" % [stage_name, what], took, "wall", screen_text(), "", "")
	return got

# ------------------------------------------------------------------ the tutorial course, per step
func _course_tick(m: Match) -> void:
	var tut := m.tut
	if not live_done:
		live_done = true
		_live_steps(tut)
	if tut.step != last_step:
		_close_step()
		if tut.step <= last_step and last_step >= 0:
			step_rec["repeat"] = true
		last_step = tut.step
		var sid: String = tut.id() if tut.step >= 0 else "intro"
		step_rec = {"id": sid, "t": 0.0, "text": "", "cap": "", "nag": false, "repeat": false,
				"live": live_by_step.get(sid, "")}
	if tut.step >= 0 and step_rec["text"] == "":
		step_rec["text"] = ("%s %s" % [tut.text, tut.detail]).strip_edges()
		step_rec["cap"] = tut.key_cap
	step_rec["t"] += Match.DT
	step_rec["nag"] = step_rec["nag"] or tut.nag_t > 0.0

func _close_step() -> void:
	if step_rec.is_empty():
		return
	var flags: Array = []
	if step_rec["nag"]:
		flags.append("nagged")
	if step_rec["repeat"]:
		flags.append("repeated")
	var live: String = step_rec.get("live", "")
	if live != "":
		flags.append(live)
	var named := _caps_in(step_rec["text"], _all_caps()).filter(func(c): return c != step_rec["cap"])
	var caps := ",".join([step_rec["cap"]] + named).trim_prefix(",")
	row("tutorial", step_rec["id"], step_rec["t"], "sim", step_rec["text"], caps, ", ".join(flags))
	steps_seen += 1

func _tutorial_match():
	var home = await super._tutorial_match()
	_close_step()
	return home

## Each step's words and cap with the default keys and again with every action on an F-key.
func _live_steps(tut: Tutorial) -> void:
	var keep := [tut.step, tut.text, tut.detail, tut.key_cap, tut.need]
	for i in Tutorial.steps().size():
		tut.step = i
		var sid := String(Tutorial.steps()[i][0])
		live_by_step[sid] = _stale_caps(func():
			tut._words()
			return "%s %s %s" % [tut.text, tut.detail, tut.key_cap])
	tut.step = keep[0]
	tut.text = keep[1]
	tut.detail = keep[2]
	tut.key_cap = keep[3]
	tut.need = keep[4]

var live_by_step: Dictionary = {}

## The caps (of `caps`) that `txt` names as whole words.
func _caps_in(txt: String, caps: Array) -> Array:
	var found: Array = []
	for c in caps:
		if c in NO_READ or c == "?" or found.has(c) or not c.is_valid_identifier():
			continue
		var flag := "(?i)" if c.length() > 2 else ""
		var re := RegEx.create_from_string("%s(^|[^A-Za-z0-9])%s($|[^A-Za-z0-9])" % [flag, c])
		if re.search(txt) != null:
			found.append(c)
	return found

## Which default key names survive in `text_fn`'s text after every action is rebound ("" when none do).
func _stale_caps(text_fn: Callable) -> String:
	var before: String = text_fn.call()
	var old: Dictionary = {}
	for i in ACTIONS.size():
		old[ACTIONS[i]] = Settings.slots(ACTIONS[i])
	var caps: Array = ACTIONS.map(func(a): return Settings.key_cap(a))
	for i in ACTIONS.size():
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F1 + i
		Settings.rebind(ACTIONS[i], ev, 0)
	var after: String = text_fn.call()
	for a in ACTIONS:
		Settings._set_slots(a, old[a])
	var stale := _caps_in(after, caps)
	return ("hard-coded key: " + "/".join(stale)) if stale.size() > 0 and before != "" else ""

# ------------------------------------------------------------------ the farm tutorial, per step
func _do_step(id: String) -> void:
	var live := _stale_caps(func(): return FarmTutorial.hint_text(id))
	var txt := FarmTutorial.hint_text(id)
	row("farm", id, 0.0, "n/a", txt, ",".join(_caps_in(txt, _all_caps())), live)
	super._do_step(id)

# ------------------------------------------------------------------ the garden's first day
func _garden_first_day() -> void:
	_begin("garden first day")
	var bot = load("res://tools/garden_first_day_check.gd").new()
	bot.main = main
	await bot._bot()
	bad += bot.bad
	for r in (GardenFirstDay.rules()["rows"] as Array):
		var txt := String(r["text"])
		var live := _stale_caps(func(): return String(r["text"]))
		row("garden", String(r["id"]), 0.0, "n/a", txt, ",".join(_caps_in(txt, _all_caps())), live)
