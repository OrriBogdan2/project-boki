extends RefCounted
## --tg-text-check: the practice space is "Training Grounds" in all player text (DECISIONS.md
## "Practice and Arena"); "Arena" is kept for the future 4v4 mode. Fails on any string literal in
## scripts/ or string value in content/ with the word Arena (code names, the "arena" mode id and the
## --arena flag stay lower-case or outside strings, so they pass). When the 4v4 mode lands, its text
## gets an allow-list here.
## It also fails a Boki called "it": a hatched Boki has a sex (M/F), so text says {he}/{his} (KinSpeak.pronouns) or
## avoids the pronoun, never it/its/itself, when a singular Boki is the subject. Code identifiers and dev notes
## (a path, a .gd name, snake_case) are not player text. Hunter text is not checked.

const WORD := "\\b(Arena|ARENA)\\b"

const BOKI_IT := (
	"\\b(?:[Yy]our|[Aa]|[Tt]he|[Tt]his|[Ee]ach|[Oo]ne|[Aa]nother|[Ww]ild|rival) "
	+ "(?:\\w+ )?Boki\\b(?:'s)?[^.!?:;]*?"
	+ "(?:\\b[Ii]ts\\b|\\bitself\\b|(?:,| and| while| when| if| until| before| as| so| but| who|\\.|:) it\\b)"
)
## Care phrases that only ever mean a Boki ("Feed it", "let it rest"), with no Boki named before the "it".
const CARE_IT := (
	"\\b(?:(?:[Ff]eed|[Pp]et|[Bb]rush|[Tt]uck|[Nn]ame|play with|fight beside|look after|you feed|you raise"
	+ "|[Tt]akes whatever) it\\b|[Ll]et it (?:nap|rest|sleep|go back)\\b)"
)
## Hunter text that says "it" about a blade, not a Boki.
const HUNTER_PATH := "res://content/rules/mask_moment.json"
const DEV_TEXT := "/|\\.gd|\\w_\\w|\\w\\.\\w"

var bad := 0
var boki_re := RegEx.create_from_string(BOKI_IT)
var care_re := RegEx.create_from_string(CARE_IT)
var dev_re := RegEx.create_from_string(DEV_TEXT)
var re := RegEx.create_from_string(WORD)

func run(main: Node) -> void:
	_walk("res://scripts", ".gd")
	_walk("res://content", ".json")
	var map_name := String(World.load_layout("arena").get("name", ""))
	_ok(map_name == "Training Grounds", "the practice map is named Training Grounds (%s)" % map_name)
	print("TGTEXT %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _boki_it(s: String, where: String) -> void:
	if where.begins_with(HUNTER_PATH):
		return
	var said_it := boki_re.search(s) != null or care_re.search(s) != null
	_ok(dev_re.search(s) != null or not said_it, "%s: Boki called it: \"%s\"" % [where, s])

func _ok(cond: bool, what: String) -> void:
	if not cond:
		bad += 1
		print("TGTEXT FAIL ", what)

func _walk(dir: String, ext: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(d), ext)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			var path := dir.path_join(f)
			var text := FileAccess.get_file_as_string(path)
			if ext == ".json":
				for s in _json_strings(JSON.parse_string(text)):
					_ok(re.search(s) == null, "%s: \"%s\"" % [path, s])
				for s in _json_strings(JSON.parse_string(text), true):
					var at := text.find(s.json_escape())
					_boki_it(s, "%s:%d" % [path, text.substr(0, maxi(at, 0)).count("\n") + 1])
			else:
				var n := 0
				for line in text.split("\n"):
					n += 1
					for s in _gd_strings(line):
						_ok(re.search(s) == null, "%s:%d: \"%s\"" % [path, n, s])
						_boki_it(s, "%s:%d" % [path, n])

## Every string value in parsed JSON (keys are ids, not text). `player_only` leaves out dev notes: keys that start
## with "_" or end in "doc" or "note".
func _json_strings(v, player_only := false) -> Array:
	if v is String:
		return [v]
	var out: Array = []
	if v is Dictionary:
		for k in v:
			var key := String(k)
			if not (player_only and (key.begins_with("_") or key.ends_with("doc") or key.ends_with("note"))):
				out.append_array(_json_strings(v[k], player_only))
	elif v is Array:
		for x in v:
			out.append_array(_json_strings(x, player_only))
	return out

## The quoted literals on one line of GDScript, stopping at a comment.
func _gd_strings(line: String) -> Array:
	var out: Array = []
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "#":
			break
		if c == "\"" or c == "'":
			var j := i + 1
			while j < line.length() and line[j] != c:
				j += 2 if line[j] == "\\" else 1
			out.append(line.substr(i + 1, j - i - 1))
			i = j
		i += 1
	return out
