extends RefCounted
## --tutorial-text-check: one short banner line per tutorial step (DECISIONS 2026-11-08). Every step
## title, detail and first-time hint (content/rules/tutorial.json, farm_tutorial.json) must be one
## sentence of at most 12 words, name keys with Settings.key_cap tokens (%G, {interact}) and never raw
## letters or digits, and not use a jargon word before the step that introduces it.

const MAX_WORDS := 12
## term -> the step id that introduces it ("" = never introduced by the tutorial, so never allowed).
const JARGON := {"fuse": "pick_ult", "relic": "expedition", "kin": "", "rank": "rank", "daze": "",
		"uplink": "wayout", "ultimate": "pick_ult"}

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("TUTTEXT FAIL ", what)
		bad += 1

func _lint(where: String, text: String, seen_intro: Dictionary) -> void:
	var words := text.split(" ", false)
	ok(words.size() <= MAX_WORDS, "%s: %d words (max %d): %s" % [where, words.size(), MAX_WORDS, text])
	var re := RegEx.create_from_string("[.!?](\\s|$)")
	ok(re.search_all(text.strip_edges().rstrip(".!?")).size() == 0, "%s: more than one sentence: %s" % [where, text])
	var raw := RegEx.create_from_string("(?i)\\b(press|hold|tap|click)\\s+(?:the\\s+)?([a-z0-9])\\b(?!\\w)")
	for m in raw.search_all(text):
		var w := m.get_string(2)
		ok(false, "%s: raw key '%s' (use a key_cap token): %s" % [where, w, text])
	var low := text.to_lower()
	for term in JARGON:
		var r := RegEx.create_from_string("\\b%s\\b" % term)
		if r.search(low) != null:
			ok(seen_intro.has(term), "%s: jargon '%s' before it is introduced: %s" % [where, term, text])

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
	_steps("tutorial", tut["steps"], func(r): return String(r[0]), func(r):
		var out := [["title", r[1]]]
		if detail.has(r[0]): out.append(["detail", detail[r[0]]])
		return out)
	for k in tut["alt"]:
		_lint("tutorial alt %s" % k, String(tut["alt"][k]), {})
	_steps("farm", Content.rules("farm_tutorial")["steps"], func(r): return String(r["id"]), func(r):
		var out := [["title", r["title"]]]
		for h in r["hints"]:
			out.append(["hint " + h, r["hints"][h]])
		return out)
	print("TUTTEXT %s (%d problems)" % ["ok" if bad == 0 else "FAIL", bad])
	m.get_tree().quit(1 if bad > 0 else 0)
