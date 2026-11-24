extends RefCounted
## --key-text-check: tutorial and hint text names keys only through Settings.key_cap (DECISIONS: Controls).
## Every rebindable action is moved to an unusual key (F13 up, the keypad, ...), then every line below
## is filled the way the game fills it and must not show any action's default key or a mouse button name:
##   - the first-match tutorial (content/rules/tutorial.json: steps, details, alt lines, labels)
##   - the Boki's tutorial hints (BokiChatter.TUT_HINT) and the scout hint
##   - the Training Grounds checklist (Match.training.rows)
##   - the first-time hints a match shows (Match._tips) and every _tip line in match.gd as written
##   - the farm tutorial (content/rules/farm_tutorial.json, through FarmTutorial.fill)
## and a few lines must show the new keys, so the rebind really reaches the text.
## The same lines are also held to plain words (DECISIONS 2026-11-08): at most MAX_LEN characters as shown, no
## internal names (kin, archetype, Mantle, Mask, Warden) and no term before the step that explains it
## (TERMS: tutorial steps, farm steps, the garden hub hints), and the first-time hint files read as written.
## Run with a temporary XDG_DATA_HOME: it rebinds keys (Settings writes its config file).

## Keys no default binding uses, one per action (not KP Enter: confirm's second default).
const ODD_KEYS := [
	KEY_F13,
	KEY_F14,
	KEY_F15,
	KEY_F16,
	KEY_F17,
	KEY_F18,
	KEY_F19,
	KEY_F20,
	KEY_F21,
	KEY_F22,
	KEY_F23,
	KEY_F24,
	KEY_F25,
	KEY_F26,
	KEY_F27,
	KEY_F28,
	KEY_F29,
	KEY_F30,
	KEY_F31,
	KEY_F32,
	KEY_F33,
	KEY_F34,
	KEY_F35,
	KEY_KP_0,
	KEY_KP_1,
	KEY_KP_2,
	KEY_KP_3,
	KEY_KP_4,
	KEY_KP_5,
	KEY_KP_6,
	KEY_KP_7,
	KEY_KP_8,
	KEY_KP_9,
	KEY_KP_ADD,
	KEY_KP_SUBTRACT,
	KEY_KP_MULTIPLY,
	KEY_KP_DIVIDE,
	KEY_KP_PERIOD,
	KEY_INSERT,
	KEY_HOME,
	KEY_END,
	KEY_PAGEUP,
	KEY_PAGEDOWN,
	KEY_SCROLLLOCK,
	KEY_PAUSE,
	KEY_NUMLOCK,
	KEY_BACKSLASH,
	KEY_SEMICOLON,
	KEY_BRACKETLEFT,
	KEY_BRACKETRIGHT,
	KEY_APOSTROPHE,
	KEY_MENU,
	KEY_PRINT,
	KEY_CAPSLOCK,
	KEY_HELP,
	KEY_BACK,
	KEY_FORWARD,
	KEY_REFRESH,
	KEY_STOP,
	KEY_SEARCH,
	KEY_FAVORITES,
	KEY_HOMEPAGE,
	KEY_VOLUMEUP,
	KEY_VOLUMEDOWN,
	KEY_MEDIAPLAY,
	KEY_MEDIASTOP,
	KEY_MEDIANEXT
]

## Caps that are also everyday words or numbers: only a hit after "press", "hold", "tap", "key" or in "(A)".
const WORDLIKE := ["A", "I", "1", "2", "3", "4"]

## Caps that prose spells in title case too ("Hold Shift").
const TITLED := ["SHIFT", "SPACE", "CTRL", "TAB", "DELETE"]
## Longest a tutorial or hint line may be, as shown (characters).
const MAX_LEN := 70
## Names of our own code that no player-facing line may use ("Warden" is what the game calls a Hunter).
const INTERNAL := "(?<![\\w%])(kin|Kin|archetype|Archetype|Mantle|Mask|Warden)s?(?!\\w)"
## Rules keys whose strings are data (ids, tiles, tools, a doc note), not a line anyone reads.
const NOT_TEXT := ["desc", "options", "id", "needs", "waits", "spot", "gives_tool", "gets", "skip_toy", "house_spot"]
## Terms a line may only use from the step that explains them on: [pattern, that step's id]. A step's id is its
## "id" (a tutorial.json step's first entry, a farm step's "id", a hub hint's "id", else its title).
const TERMS := {
	"tutorial":
	[
		["(?i)uplink|capture", "uplink"],
		["(?i)outpost", "wayout"],
		["(?i)glove", "glove"],
		["Sentinel", "hook"],
		["(?i)summon", "summon"],
		["(?i)\\branks?\\b", "ranks"]
	],
	"farm": [["(?i)trough", "feed"], ["(?i)pantry", "feed"], ["(?i)\\bpatch", "crop"], ["(?i)\\bstall\\b", "buy"]],
	"hub": [["Waystone", "waystone"], ["Wayseed", "keys"]],
}
## Files whose quoted lines are first-time hints (every string with a space in it is read as written).
const HINT_FILES := [
	"armour_hint",
	"xp_hints",
	"hazard_hint",
	"first_capture",
	"first_ult_hint",
	"vision_hint",
	"heart_raid_hints",
	"duel_ring_hint",
	"belt_tips",
	"knock_tip",
	"tutorial_summon",
	"tip_text"
]
var internal := RegEx.create_from_string(INTERNAL)

var bad := 0
var m: Match
var defaults := {}  # action -> its default caps (both slots), read before the rebind
var pats := {}  # action -> RegEx for those caps in a line
var mouse_words := RegEx.create_from_string("(?i)\\b(left|right|middle)[ -]click|\\bmouse ?[0-9]|middle mouse")


func ok(cond: bool, what: String) -> void:
	print("KEYTEXT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	FarmUnlocks.rules()["base_mode"] = false  # walks the old farm (base_mode is the shipped default)
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
	_hub()
	_hint_files()
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
				if c in TITLED:
					alts.append("(?<!\\w)%s(?!\\w)" % c.capitalize())
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
	ok(
		ODD_KEYS.size() >= Settings.ACTIONS.size(),
		"an odd key per action (%d keys, %d actions)" % [ODD_KEYS.size(), Settings.ACTIONS.size()]
	)
	var i := 0
	for a in Settings.ACTIONS:
		var ev := InputEventKey.new()
		ev.physical_keycode = ODD_KEYS[i]
		i += 1
		Settings.rebind(a[0], ev, 0)
		Settings.clear_bind(a[0], 1)
	ok(
		Settings.key_cap("signature") != "E" and Settings.key_cap("fire") != "LMB",
		"every action rebound (E -> %s)" % Settings.key_cap("signature")
	)


## One line as shown: no default key and no mouse button name left in it, short, and no internal name.
## `shown` is false for a data string (an id, a tile), which only the key rule reads.
func _line(where: String, txt: String, shown := true) -> void:
	var why := _stale_key(txt)
	if shown and txt.length() > MAX_LEN:
		why = "is %d characters (max %d)" % [txt.length(), MAX_LEN]
	if shown and internal.search(txt) != null:
		why = "uses the internal name '%s'" % internal.search(txt).get_string().strip_edges()
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
func _walk(where: String, v: Variant, fill: Callable, shown := true) -> int:
	var n := 0
	if v is String:
		_line(where, fill.call(v), shown)
		return 1
	if v is Dictionary:
		for k: String in v:
			if not k.ends_with("doc"):
				n += _walk(where + "." + k, v[k], fill, shown and not NOT_TEXT.has(k))
	elif v is Array:
		for x in v:
			n += _walk(where, x, fill, shown)
	return n


func _tutorial() -> void:
	var tu: Tutorial = m.tut
	var fill := func(s: String) -> String: return tu.fill(TutorialText.fill(s, m.player))
	var rules := Content.rules("tutorial").duplicate()
	rules["steps"] = rules["steps"].map(func(st: Array) -> String: return st[1])  # [id, line]: the lines
	var n := _walk("tutorial", rules, fill)
	for id: String in BokiChatter.TUT_HINT:
		for s: String in BokiChatter.TUT_HINT[id]:
			_line("boki hint " + id, TutorialText.fill(s, m.player))
	_line("scout hint", "Hold %s to crouch and scout ahead" % Settings.key_cap("crouch"))
	ok(n > 30, "tutorial lines checked (%d)" % n)
	_terms("tutorial", _tutorial_steps(fill))
	ok(
		fill.call("%J %E") == "%s %s" % [Settings.key_cap("jump"), Settings.key_cap("signature")],
		"the tutorial's key tokens follow the rebind"
	)


## The tutorial's steps in order as [id, lines]: the step, its detail, alt lines, retry line, label and Boki hint.
func _tutorial_steps(fill: Callable) -> Array:
	var tut := Content.rules("tutorial")
	var out := []
	for st: Array in tut["steps"]:
		var id: String = st[0]
		var lines := [st[1], tut["detail"].get(id, ""), tut["retry"].get(id, ""), tut["labels"].get(id, "")]
		for k: String in tut["alt"]:
			if k.begins_with(id + "_"):
				lines.append(tut["alt"][k])
		for k: String in tut["detail"]:
			if k.begins_with(id + "_"):
				lines.append(tut["detail"][k])
		lines.append_array(BokiChatter.TUT_HINT.get(id, []))
		out.append([id, lines.map(func(s: String) -> String: return fill.call(s))])
	return out


## No line of a step names a TERMS entry whose step comes later.
func _terms(group: String, steps: Array) -> void:
	var at := {}
	for i in steps.size():
		at[steps[i][0]] = i
	for t: Array in TERMS[group]:
		var re := RegEx.create_from_string(t[0])
		ok(at.has(t[1]), "%s: the step that explains '%s' exists (%s)" % [group, t[0], t[1]])
		for i in steps.size():
			for ln: String in steps[i][1]:
				if at.has(t[1]) and i < at[t[1]] and re.search(ln) != null:
					ok(false, "%s step %s uses '%s' before step %s: %s" % [group, steps[i][0], t[0], t[1], ln])


func _training() -> void:
	var rows: Array = m.training.rows()
	for r: Array in rows:
		_line("training " + String(r[0]), String(r[1]))
	var glide := rows.filter(func(r): return r[0] == "glide")
	# the row text is key-free; the HUD prints the live cap of the row's action in front of it (training_drill.json)
	ok(
		not glide.is_empty() and String(glide[0][2]) == "jump" and Settings.key_cap("jump") != "",
		"the Training Grounds glide row shows the rebound jump key"
	)


## The first-time hints a fresh save sees at the start of a match.
func _tips() -> void:
	Save.d["tutorial"] = {}
	m.opts["tutorial"] = false
	var dropping := m.player.dropping
	m.player.dropping = false  # tips wait for the landing
	m.hud.msgs.clear()
	m.hud.msgs.hold = false  # the tutorial banner holds the lane; this is a plain match's start
	m._tip_t = 20.0
	m._tips()
	m.opts["tutorial"] = true
	m.player.dropping = dropping
	var shown: Array = m.hud.msgs.texts()
	for s in shown:
		_line("first-time hint", s)
	for pair: Array in TipText.all_lines():
		_line("TipText " + String(pair[0]), String(pair[1]))
	ok(shown.any(func(s): return s.contains(Settings.key_cap("dash"))), "the move hint names the rebound dash key")


## The _tip lines as written in match.gd: a key in the literal is a key nobody filled in.
func _source_tips() -> void:
	var lit := RegEx.create_from_string('_tip\\("[^"]*", "([^"]*)"')
	var n := 0
	for ln in FileAccess.get_file_as_string("res://scripts/match/match.gd").split("\n"):
		var hit := lit.search(ln)
		if hit != null:
			_line("match.gd _tip", hit.get_string(1))
			n += 1
	# the hints moved out of match.gd are filled by TipText from Settings.key_cap: _tips() checks them after the rebind
	ok(TipText.all_lines().size() + n > 3, "match.gd _tip lines read (%d) + TipText lines" % n)


func _farm() -> void:
	var n := _walk("farm tutorial", FarmTutorial.rules(), FarmTutorial.fill)
	var steps := []
	for st: Dictionary in FarmTutorial.rules()["steps"]:
		var lines := [st.get("title", "")]
		for k: String in ["hints", "world"]:
			lines.append_array(st.get(k, {}).values())
		var id: String = st.get("id", st.get("title", ""))
		steps.append([id, lines.map(func(s: String) -> String: return FarmTutorial.fill(s))])
	_terms("farm", steps)
	ok(n > 20, "farm tutorial lines checked (%d)" % n)
	var house: Dictionary = FarmTutorial.step_def("house")
	var wait: String = FarmTutorial.fill(String(house.get("hints", {}).get("wait", "")))
	ok(wait.contains(Settings.key_cap("interact")), "the farm house hint names the rebound use key: " + wait)


## The garden hub's first-time hints, in the order the hub shows them.
func _hub() -> void:
	var rules := HubHints.rules()
	var steps := []
	for e: Dictionary in rules["list"]:
		steps.append([e["id"], [String(e["text"]).replace("{interact}", Settings.key_cap("interact"))]])
	for s in steps:
		_line("hub hint " + s[0], s[1][0])
	_line("hub hint wayseed", String(rules["wayseed_text"]))
	_terms("hub", steps)


## TipText's lines (the ones _tips() does not reach) and every quoted line of the first-time hint files.
func _hint_files() -> void:
	for s: String in [
		TipText.rings(),
		TipText.stagger(),
		TipText.send("Pip"),
		TipText.scan(),
		TipText.ability(true),
		TipText.ability(false),
		TipText.bond_full("Fuse", true)
	]:
		_line("TipText", s)
	for kind: String in TerrainHazards.rules()["kinds"]:
		_line("hazard hint " + kind, String(TerrainHazards.kind_def(kind).get("tip", "")))
	for id: String in UtilityBelt.ids():
		_line("belt hint " + id, BeltTips.line(id, 0))
	for k: String in HoldTeach.HINTS:
		_line("hold hint " + k, HoldTeach.HINTS[k] % Settings.key_cap("jump"))
	var quoted := RegEx.create_from_string('"([^"\\n]*\\s[^"\\n]*)"')
	var n := 0
	for f: String in HINT_FILES:
		for ln in FileAccess.get_file_as_string("res://scripts/match/%s.gd" % f).split("\n"):
			if ln.strip_edges().begins_with("#"):
				continue
			for hit in quoted.search_all(ln.get_slice(" # ", 0)):
				_line(f + ".gd", hit.get_string(1))
				n += 1
	ok(n > 10, "first-time hint file lines read (%d)" % n)
