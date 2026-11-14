extends RefCounted
## --key-text-check: tutorial and hint text names keys only through Settings.key_cap (DECISIONS: Controls).
## Every rebindable action is moved to an unusual key (F13 up, the keypad, ...), then every line below
## is filled the way the game fills it and must not show any action's default key or a mouse button name:
##   - the first-match tutorial (content/rules/tutorial.json: steps, details, alt lines, labels)
##   - the Boki's tutorial hints (BokiChatter.TUT_HINT) and the scout hint
##   - the Training Grounds checklist (Match.train_rows)
##   - the first-time hints a match shows (Match._tips) and every _tip line in match.gd as written
##   - the farm tutorial (content/rules/farm_tutorial.json, through FarmTutorial.fill)
## and a few lines must show the new keys, so the rebind really reaches the text.
## Run with a temporary XDG_DATA_HOME: it rebinds keys (Settings writes its config file).

var bad := 0
var m: Match
var defaults := {}      # action -> its default caps (both slots), read before the rebind
var pats := {}          # action -> RegEx for those caps in a line

## Keys no default binding uses, one per action.
const ODD_KEYS := [KEY_F13, KEY_F14, KEY_F15, KEY_F16, KEY_F17, KEY_F18, KEY_F19, KEY_F20, KEY_F21, KEY_F22,
	KEY_F23, KEY_F24, KEY_F25, KEY_F26, KEY_F27, KEY_F28, KEY_F29, KEY_F30, KEY_F31, KEY_F32, KEY_F33, KEY_F34,
	KEY_F35, KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
	KEY_KP_ADD, KEY_KP_SUBTRACT, KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_PERIOD, KEY_KP_ENTER, KEY_INSERT,
	KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN, KEY_SCROLLLOCK, KEY_PAUSE, KEY_NUMLOCK, KEY_BACKSLASH,
	KEY_SEMICOLON, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_APOSTROPHE, KEY_QUOTELEFT, KEY_MINUS, KEY_EQUAL,
	KEY_SLASH, KEY_COMMA, KEY_PERIOD, KEY_F12, KEY_F11]
## Caps that are also everyday words or numbers: only a hit after "press", "hold", "tap", "key" or in "(A)".
const WORDLIKE := ["A", "I", "1", "2", "3", "4"]
## Caps that prose spells in title case too ("Hold Shift").
const TITLED := ["SHIFT", "SPACE", "CTRL", "TAB", "DELETE"]
var mouse_words := RegEx.create_from_string("(?i)\\b(left|right|middle)[ -]click|\\bmouse ?[0-9]|middle mouse")

func ok(cond: bool, what: String) -> void:
	print("KEYTEXT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	Save.no_write = true
	_read_defaults()
	_source_tips()
	_rebind()
	m = Match.new()
	main_node.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	_tutorial()
	_training()
	_tips()
	_farm()
	print("KEYTEXT DONE, failures: ", bad)
	main_node.get_tree().quit(1 if bad > 0 else 0)

func _read_defaults() -> void:
	for a in Settings.ACTIONS:
		var caps: Array = Array(Settings.key_caps(a[0]).split(" / ")).filter(func(c): return c != "?")
		defaults[a[0]] = caps
		var alts: Array = []
		for c: String in caps:
			if c in WORDLIKE:
				alts.append("(?i:press|hold|tap|key)\\s+%s(?!\\w)|\\(%s\\)" % [c, c])
			else:
				alts.append("(?<![\\w%%{])%s(?![\\w}])" % _esc(c))
				if c in TITLED: alts.append("(?<!\\w)%s(?!\\w)" % c.capitalize())
		if not alts.is_empty():
			pats[a[0]] = RegEx.create_from_string("|".join(alts))
	ok(defaults["signature"].has("E") and defaults["fire"].has("LMB"), "default caps read (E, LMB)")
	for txt in ["Press E again", "Hold Shift to dash", "drink one (1)", "Use your right click"]:
		ok(_stale_key(txt) != "", "the matcher catches '%s'" % txt)
	for txt in ["A teammate is down", "Land 2 hits", "Click Market on the bar"]:
		ok(_stale_key(txt) == "", "the matcher lets '%s' through" % txt)

func _esc(c: String) -> String:
	var out := ""
	for ch in c:
		out += ("\\" + ch) if "\\^$.|?*+()[]{}".contains(ch) else ch
	return out

func _rebind() -> void:
	var i := 0
	for a in Settings.ACTIONS:
		var ev := InputEventKey.new()
		ev.physical_keycode = ODD_KEYS[i]
		i += 1
		Settings.rebind(a[0], ev, 0)
		Settings.clear_bind(a[0], 1)
	ok(Settings.key_cap("signature") != "E" and Settings.key_cap("fire") != "LMB", "every action rebound (E -> %s)"
			% Settings.key_cap("signature"))

## One line as shown: no default key and no mouse button name left in it.
func _line(where: String, txt: String) -> void:
	var why := _stale_key(txt)
	if why != "":
		ok(false, "%s %s: %s" % [where, why, txt])

## What in a line still names a default key or a mouse button ("" when nothing does).
func _stale_key(txt: String) -> String:
	for a in pats:
		var hit: RegExMatch = (pats[a] as RegEx).search(txt)
		if hit != null:
			return "shows %s's default key '%s'" % [a, hit.get_string().strip_edges()]
	return "names a mouse button" if mouse_words.search(txt) != null else ""

## Every text value in a rules table (doc notes skipped), run through `fill`.
func _walk(where: String, v: Variant, fill: Callable) -> int:
	var n := 0
	if v is String:
		_line(where, fill.call(v))
		return 1
	if v is Dictionary:
		for k: String in v:
			if not k.ends_with("doc"): n += _walk(where + "." + k, v[k], fill)
	elif v is Array:
		for x in v: n += _walk(where, x, fill)
	return n

func _tutorial() -> void:
	var tu: Tutorial = m.tut
	var fill := func(s: String) -> String: return tu._fill(TutorialText.fill(s, m.player))
	var n := _walk("tutorial", Content.rules("tutorial"), fill)
	for id: String in BokiChatter.TUT_HINT:
		for s: String in BokiChatter.TUT_HINT[id]: _line("boki hint " + id, TutorialText.fill(s, m.player))
	_line("scout hint", "Hold %s to crouch and scout ahead" % Settings.key_cap("crouch"))
	ok(n > 30, "tutorial lines checked (%d)" % n)
	ok(fill.call("%J %S") == "%s %s" % [Settings.key_cap("jump"), Settings.key_cap("secondary")],
			"the tutorial's key tokens follow the rebind")

func _training() -> void:
	var rows := m.train_rows()
	for r: Array in rows: _line("training " + String(r[0]), String(r[1]))
	var glide := rows.filter(func(r): return r[0] == "glide")
	ok(not glide.is_empty() and String(glide[0][1]).contains(Settings.key_cap("jump")),
			"the Training Grounds glide row names the rebound jump key")

## The first-time hints a fresh save sees at the start of a match.
func _tips() -> void:
	Save.d["tutorial"] = {}
	m.opts["tutorial"] = false
	var dropping := m.player.dropping
	m.player.dropping = false      # tips wait for the landing
	m.hud.msgs.clear()
	m.hud.msgs.hold = false      # the tutorial banner holds the lane; this is a plain match's start
	m._tip_t = 20.0
	m._tips()
	m.opts["tutorial"] = true
	m.player.dropping = dropping
	var shown: Array = m.hud.msgs.texts()
	for s in shown: _line("first-time hint", s)
	ok(shown.any(func(s): return s.contains(Settings.key_cap("dash"))), "the move hint names the rebound dash key")

## The _tip lines as written in match.gd: a key in the literal is a key nobody filled in.
func _source_tips() -> void:
	var lit := RegEx.create_from_string("_tip\\(\"[^\"]*\", \"([^\"]*)\"")
	var n := 0
	for ln in FileAccess.get_file_as_string("res://scripts/match/match.gd").split("\n"):
		var hit := lit.search(ln)
		if hit != null:
			_line("match.gd _tip", hit.get_string(1))
			n += 1
	ok(n > 10, "match.gd _tip lines read (%d)" % n)

func _farm() -> void:
	var n := _walk("farm tutorial", FarmTutorial.rules(), FarmTutorial.fill)
	ok(n > 20, "farm tutorial lines checked (%d)" % n)
	var house: Dictionary = FarmTutorial.step_def("house")
	var wait := FarmTutorial.fill(String(house.get("hints", {}).get("wait", "")))
	ok(wait.contains(Settings.key_cap("interact")), "the farm house hint names the rebound use key: " + wait)
