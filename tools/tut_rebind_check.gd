extends RefCounted
## --tut-rebind-check: the words a new player reads most follow the player's own keys (Settings.key_cap).
## Every action is rebound to an unusual key (a few to mouse buttons), then every match tutorial step (banner,
## second line, key cap, scout hint, the Boki's lines), every garden tutorial hint, every first-time hint
## (TipText) and the home key row are read again. Any default key that should have changed fails, and so does
## text built before the rebind that does not refresh. The glide steps say: jump, then press again in the air and hold.

var bad := 0
var main: Node
var stale_words: Array = []       # default caps no rebound action uses any more, as whole words
const PLAIN_WORDS := ["I", "A"]     # one-letter words that are also plain English
const LITERALS := ["Shift", "Space", "Ctrl", "WASD", "W A S D", "left click", "right click", "Left click", "Right click"]
const UNUSUAL := [KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F11, KEY_F12, KEY_F13, KEY_F14, KEY_F15,
		KEY_F16, KEY_F17, KEY_F18, KEY_F19, KEY_F20, KEY_F21, KEY_F22, KEY_F23, KEY_F24, KEY_INSERT, KEY_HOME, KEY_END,
		KEY_PAGEUP, KEY_PAGEDOWN, KEY_PAUSE, KEY_KP_ADD, KEY_KP_SUBTRACT, KEY_KP_MULTIPLY, KEY_KP_DIVIDE]
const MOUSE_BOUND := {"fire": MOUSE_BUTTON_XBUTTON1, "throw": MOUSE_BUTTON_XBUTTON2}

func ok(cond: bool, what: String) -> void:
	print("TUTREBIND %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Settings.reset_all()
	var before := {}
	for a in Settings.ACTIONS:
		before[a[0]] = Settings.key_cap(a[0])
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	var tu: Tutorial = m.tut
	tu.intro = false
	var row := LiveKeyRow.make(func(): return [[Settings.move_caps(" "), "walk"], [Settings.key_cap("jump"), "jump"]])
	main.add_child(row)
	for i in 3:
		m.step(Match.DT)
	_open_step(tu, "glide")
	var glide_before := [tu.text, tu.detail, tu.key_cap, TipText.move(), _row_text(row)]
	_rebind_everything(before)
	for i in 2:
		m.step(Match.DT)
	ok(tu.id() == "glide", "the glide step is still the one showing (%s)" % tu.id())
	var glide_after := [tu.text, tu.detail, tu.key_cap, TipText.move(), _row_text(row)]
	for i in 3:
		ok(glide_before[i] != glide_after[i], "built before the rebind, refreshed after it: %s ('%s' -> '%s')"
				% [["banner", "second line", "key cap"][i], glide_before[i], glide_after[i]])
	ok(glide_before[3] != glide_after[3], "a first-time hint is built when it shows: the move hint follows a rebind")
	ok(glide_before[4] != glide_after[4], "the home key row rebuilds when a binding changes ('%s' -> '%s')"
			% [glide_before[4], glide_after[4]])
	_match_tutorial(m, tu)
	_boki_lines(m)
	_tips()
	_garden()
	_kit_cards()
	_sources()
	Settings.reset_all()
	print("TUTREBIND DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _row_text(row: Node) -> String:
	var out := []
	for l in row.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return "|".join(out)

func _open_step(tu: Tutorial, sid: String) -> void:
	tu.step = Tutorial.steps().find_custom(func(s): return s[0] == sid)
	tu.wait = 0.0
	tu.card_t = Tutorial.CARD_T
	tu._words()

## Every action on an unusual key (or a mouse button), then the words that must not appear any more.
func _rebind_everything(before: Dictionary) -> void:
	var i := 0
	for a in Settings.ACTIONS:
		var ev: InputEvent
		if MOUSE_BOUND.has(a[0]):
			ev = InputEventMouseButton.new()
			(ev as InputEventMouseButton).button_index = MOUSE_BOUND[a[0]]
		else:
			ev = InputEventKey.new()
			(ev as InputEventKey).physical_keycode = UNUSUAL[i]
			i += 1
		Settings.rebind(a[0], ev, 0)
	ok(i < UNUSUAL.size(), "every action got its own unusual key (%d used of %d)" % [i, UNUSUAL.size()])
	var now := []
	for a in Settings.ACTIONS:
		now.append(Settings.key_cap(a[0]))
	for a in before:
		var cap: String = before[a]
		if cap not in now and cap not in stale_words and cap.length() > 0 and not cap.is_valid_int():
			stale_words.append(cap)
	ok(Settings.key_cap("fire") == "M4" and Settings.key_cap("throw") == "M5" and Settings.key_cap("jump") != before["jump"],
			"the rebind took (fire %s, Boki %s, jump %s)" % [Settings.key_cap("fire"), Settings.key_cap("throw"), Settings.key_cap("jump")])

## Default caps and literal key words found in a line, whole words only ("A" and "I" are plain English).
func stale_in(line: String, leftovers := true) -> Array:
	var found := []
	var re := RegEx.new()
	for w in stale_words + LITERALS:
		if w in PLAIN_WORDS:
			continue
		re.compile("(?<![A-Za-z0-9'%])" + w.replace(" ", "\\ ") + "(?![A-Za-z0-9'])")
		if re.search(line) != null:
			found.append(w)
	re.compile("%[A-Za-z]|\\{[a-z_]+\\}")
	var left := re.search(line)
	if leftovers and left != null:
		found.append("leftover " + left.get_string())
	return found

func _clean(line: String, where: String) -> void:
	var s := stale_in(line)
	ok(s.is_empty(), "%s has no default key left %s: '%s'" % [where, str(s), line])

# ------------------------------------------------------------------ the match tutorial
func _match_tutorial(m: Match, tu: Tutorial) -> void:
	var caps_ok := true
	for st in Tutorial.steps():
		var sid: String = st[0]
		_open_step(tu, sid)
		_clean(tu.text, "tutorial '%s' banner" % sid)
		if tu.detail != "":
			_clean(tu.detail, "tutorial '%s' second line" % sid)
		var want := ""
		if sid in ["land", "move"]:
			want = Settings.move_caps()
		elif sid == "rank":
			want = TutorialText.rank_combo()
		elif Tutorial.KEYS.has(sid):
			want = Settings.key_cap(Tutorial.KEYS[sid])
		if tu.key_cap != want:
			caps_ok = false
			print("  key cap of '%s': '%s', wanted '%s'" % [sid, tu.key_cap, want])
	ok(caps_ok, "every step's key cap is the rebound key")
	_open_step(tu, "glide")
	var jump := Settings.key_cap("jump")
	ok(tu.text.contains(jump) and tu.key_cap == jump, "glide banner names the jump key ('%s', cap '%s')" % [tu.text, tu.key_cap])
	ok(tu.detail.contains("press %s again in the air and hold" % jump),
			"glide says: jump, then press again in the air and hold ('%s')" % tu.detail)
	_open_step(tu, "move")
	tu.target = m.player.pos + Vector3(Tutorial.FAR_SCOUT + 10.0, 0, 0)
	m.player.crouch = false
	var scout := tu.scout_hint()
	ok(scout.contains(Settings.key_cap("crouch")), "the scout hint names the sneak key ('%s')" % scout)
	_clean(scout, "the scout hint")

func _boki_lines(m: Match) -> void:
	for sid in KinVoice.TUT_HINT:
		for line in KinVoice.TUT_HINT[sid]:
			_clean(TutorialText.fill(String(line), m.player), "the Boki's '%s' line" % sid)
	_clean(TutorialText.ability_tip(m.player), "the ability line")

# ------------------------------------------------------------------ first-time hints, the garden
func _tips() -> void:
	var lines := {"move": TipText.move(), "rings": TipText.rings(), "ability (kit)": TipText.ability(true),
			"ability": TipText.ability(false), "bond full": TipText.bond_full("Fuse", false),
			"bond full (next)": TipText.bond_full("Fuse", true), "send": TipText.send("Pip"), "scan": TipText.scan(),
			"hatch": TipText.hatch(), "stagger": TipText.stagger("Brute")}
	for k in lines:
		_clean(lines[k], "first-time hint '%s'" % k)
	ok(TipText.move().contains(Settings.key_cap("fire")) and TipText.move().contains("again in the air and hold"),
			"the first move hint names the rebound attack key and the glide wording")

func _garden() -> void:
	var n := 0
	for st in FarmTutorial.steps():
		for stage in (st["hints"] as Dictionary):
			n += 1
			var raw := String(st["hints"][stage])
			_clean(FarmTutorial.fill_hint(raw).replace("{secs}", "9"), "garden '%s/%s'" % [st["id"], stage])
	ok(n >= 20, "all %d garden hints read" % n)
	var build := FarmTutorial.fill_hint("Press {build}")
	ok(build == "Press " + Settings.key_cap("build"), "a garden hint is filled when read, so it follows a rebind ('%s')" % build)

## Class cards' own utility text (what the "use your ability" line is built from).
func _kit_cards() -> void:
	var d := DirAccess.open("res://content/archetypes")
	for f in d.get_files():
		if f.ends_with(".json"):
			var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/archetypes/" + f))
			_clean(String(j.get("card", {}).get("e", "")), "%s's ability card line" % f.get_basename())

## No fixed key words in the source of the first-time hints or the home key row.
func _sources() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/match/match.gd")
	var bare := 0
	for line in src.split("\n"):
		if line.contains("_tip(\""):
			if not line.contains("TipText.") and not _quoted(line).is_empty() and not stale_in(_quoted(line), false).is_empty():
				bare += 1
				print("  bare hint: ", line.strip_edges())
	ok(bare == 0, "no match.gd hint spells a default key out (%d)" % bare)
	ok(not FileAccess.get_file_as_string("res://scripts/home/home.gd").contains("\"W A S D\""),
			"the home key row builds the walk caps from the bindings")

func _quoted(line: String) -> String:
	var parts := line.split("\"")
	var out := []
	for i in range(3, parts.size(), 2):
		out.append(parts[i])
	return " ".join(out)
