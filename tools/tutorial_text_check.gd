extends RefCounted
## --tutorial-text-check: one short banner line per tutorial step (DECISIONS 2026-11-08). Every step
## title, detail and first-time hint (content/rules/tutorial.json, farm_tutorial.json) must be one
## sentence of at most 12 words, name keys with Settings.key_cap tokens (%G, {interact}) and never raw
## letters or digits, and not use a jargon word before the step that introduces it.

const MAX_WORDS := 12
## A notice card line (every line gets a bullet from HomeNotices.bullet) stays short: bullets, not paragraphs.
const MAX_NOTICE_CHARS := 60
## term -> the step id that introduces it ("" = never introduced by the tutorial, so never allowed). The Fusion
## step and its unlock name the Ultimate (R) and the Fusion (X) as two things.
## "capture" means a Boki knocked out and scanned (owner); the course never does that, so no line may call
## the uplink's charge a capture.
const JARGON := {
	"fuse": "pick_ult",
	"relic": "expedition",
	"kin": "",
	"rank": "rank",
	"daze": "",
	"uplink": "uplink",
	"ultimate": "pick_ult",
	"capture": ""
}
## Steps whose action is a HOLD (the uplink starts after Exits.START_HOLD of interact): none of their lines
## (banner, detail, retry) may tell the player to press.
const HOLD_STEPS := ["uplink"]
## Steps whose action is a second press held (the glider opens only on a FRESH press in the air, Hunter
## _glide_armed, and shuts when it is let go): a banner or retry naming the key must say "again" and the hold.
## Holding Space on from the jump opens nothing, so "Jump, then hold Space" leaves a new player falling.
const AGAIN_HOLD_STEPS := ["glide"]

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	if not cond:
		print("TUTTEXT FAIL ", what)
		bad += 1


## DECISIONS 2026-11-07: "Mask" is Relic in every player line (ids, files and folders keep the old word).
func _no_mask(where: String, text: String) -> void:
	var re := RegEx.create_from_string("\\b(?i:masks?)\\b")
	ok(re.search(text) == null, "%s: 'Mask' in a player line (say Relic): %s" % [where, text])


func _lint(where: String, text: String, seen_intro: Dictionary) -> void:
	var words := text.split(" ", false)
	ok(words.size() <= MAX_WORDS, "%s: %d words (max %d): %s" % [where, words.size(), MAX_WORDS, text])
	var re := RegEx.create_from_string("[.!?](\\s|$)")
	ok(re.search_all(text.strip_edges().rstrip(".!?")).size() == 0, "%s: more than one sentence: %s" % [where, text])
	var raw := RegEx.create_from_string("\\b(?i:press|hold|tap|click)\\s+(?:the\\s+)?([A-Z0-9])\\b(?!\\w)")
	for m in raw.search_all(text):
		var w := m.get_string(1)
		ok(false, "%s: raw key '%s' (use a key_cap token): %s" % [where, w, text])
	_no_mask(where, text)
	var low := text.to_lower()
	for term in JARGON:
		var r := RegEx.create_from_string("\\b%s\\b" % term)
		if r.search(low) != null:
			ok(seen_intro.has(term), "%s: jargon '%s' before it is introduced: %s" % [where, term, text])


## A key that appears twice in one JSON object is lost without a word (the last one wins): the tutorial's
## glide detail was overwritten that way. Returns "<object path>.<key>" for each repeat.
static func dup_keys(raw: String) -> Array:
	var out := []
	var stack: Array = []  # per open container: {"keys": {}} for an object, null for an array
	var i := 0
	var last_str := ""
	while i < raw.length():
		var c := raw[i]
		if c == '"':
			var j := i + 1
			while j < raw.length() and raw[j] != '"':
				j += 2 if raw[j] == "\\" else 1
			last_str = raw.substr(i + 1, j - i - 1)
			i = j + 1
			continue
		if c == "{":
			stack.append({"keys": {}})
		elif c == "[":
			stack.append(null)
		elif c == "}" or c == "]":
			stack.pop_back()
		elif c == ":" and not stack.is_empty() and stack[-1] != null:
			var keys: Dictionary = stack[-1]["keys"]
			if keys.has(last_str):
				out.append(last_str)
			keys[last_str] = true
		i += 1
	return out


## A hold step's line that says "press" (or a key token with no "hold" by it) teaches the wrong thing.
func _hold_words(where: String, text: String) -> void:
	var low := text.to_lower()
	ok(not low.contains("press"), "%s: a hold action told to press: %s" % [where, text])
	if text.contains("%K") or text.contains("%J"):
		ok(low.contains("hold") or low.contains("held"), "%s: names the key but not the hold: %s" % [where, text])


## A second-press-held line: names the key, says it is pressed again in the air, and held.
func _again_hold_words(where: String, text: String) -> void:
	var low := text.to_lower()
	ok(text.contains("%J"), "%s: does not name the glide key: %s" % [where, text])
	ok(low.contains("again"), "%s: the glider needs a second press in the air, not said: %s" % [where, text])
	ok(
		low.contains("hold") or low.contains("held"),
		"%s: the glider shuts on let-go, hold not said: %s" % [where, text]
	)


func _steps(file: String, rows: Array, id_of: Callable, texts_of: Callable) -> void:
	var seen := {}
	for row in rows:
		var id: String = id_of.call(row)
		for term in JARGON:
			if JARGON[term] == id:
				seen[term] = true
		for pair in texts_of.call(row):
			_lint("%s %s %s" % [file, id, pair[0]], String(pair[1]), seen)


func run(m: Node) -> void:
	main = m
	var tut: Dictionary = Content.rules("tutorial")
	var detail: Dictionary = tut["detail"]
	_steps(
		"tutorial",
		tut["steps"],
		func(r): return String(r[0]),
		func(r):
			var out := [["title", r[1]]]
			if detail.has(r[0]):
				out.append(["detail", detail[r[0]]])
			return out
	)
	for k in tut["alt"]:
		_lint("tutorial alt %s" % k, String(tut["alt"][k]), {})
	for f in ["res://content/rules/tutorial.json", "res://content/rules/farm_tutorial.json"]:
		for k in dup_keys(FileAccess.get_file_as_string(f)):
			ok(false, "%s: key '%s' twice in one object (the first is lost)" % [f.get_file(), k])
	ok(Exits.START_HOLD > HoldTeach.TAP_S, "the uplink start is a hold (%.2f s)" % Exits.START_HOLD)
	for row in tut["steps"]:
		if String(row[0]) in HOLD_STEPS:
			_hold_words("tutorial %s title" % row[0], String(row[1]))
	for row in tut["steps"]:
		if String(row[0]) in AGAIN_HOLD_STEPS:
			_again_hold_words("tutorial %s title" % row[0], String(row[1]))
	for sid in AGAIN_HOLD_STEPS:
		if tut["retry"].has(sid):
			_again_hold_words("tutorial %s retry" % sid, String(tut["retry"][sid]))
	for sid in HOLD_STEPS:
		for sec in ["detail", "retry"]:
			if tut[sec].has(sid):
				_hold_words("tutorial %s %s" % [sid, sec], String(tut[sec][sid]))
	for k in tut["retry"]:
		ok(not String(tut["retry"][k]).to_lower().contains("capture"), "tutorial retry %s: says capture" % k)
	_steps(
		"farm",
		Content.rules("farm_tutorial")["steps"],
		func(r): return String(r["id"]),
		func(r):
			var out := [["title", r["title"]]]
			for h in r["hints"]:
				out.append(["hint " + h, r["hints"][h]])
			return out
	)
	for w in Content.rules("words")["words"]:
		_no_mask("words " + String(w["term"]), String(w["line"]))
	for t in Content.rules("farm_builder")["talk"]["intro"]:
		_no_mask("hob intro", String(t["text"]))
	for l in load("res://scripts/ui/loading.gd").LORE:
		_no_mask("loading lore", String(l))
	for line in HomeNotices.fixed_lines():
		ok(String(line).length() <= MAX_NOTICE_CHARS, "notice line over %d chars: %s" % [MAX_NOTICE_CHARS, line])
	print("TUTTEXT %s (%d problems)" % ["ok" if bad == 0 else "FAIL", bad])
	m.get_tree().quit(1 if bad > 0 else 0)
