extends RefCounted
## --tg-text-check: the practice space is "Training Grounds" in all player text (DECISIONS.md
## "Practice and Arena"); "Arena" is kept for the future 4v4 mode. Fails on any string literal in
## scripts/ or string value in content/ with the word Arena (code names, the "arena" mode id and the
## --arena flag stay lower-case or outside strings, so they pass). When the 4v4 mode lands, its text
## gets an allow-list here.

const WORD := "\\b(Arena|ARENA)\\b"

var bad := 0
var re := RegEx.create_from_string(WORD)

func run(main: Node) -> void:
	_walk("res://scripts", ".gd")
	_walk("res://content", ".json")
	var map_name := String(World.load_layout("arena").get("name", ""))
	_ok(map_name == "Training Grounds", "the practice map is named Training Grounds (%s)" % map_name)
	print("TGTEXT %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

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
			else:
				var n := 0
				for line in text.split("\n"):
					n += 1
					for s in _gd_strings(line):
						_ok(re.search(s) == null, "%s:%d: \"%s\"" % [path, n, s])

## Every string value in parsed JSON (keys are ids, not text).
func _json_strings(v) -> Array:
	if v is String:
		return [v]
	var out: Array = []
	if v is Dictionary or v is Array:
		for x in (v.values() if v is Dictionary else v):
			out.append_array(_json_strings(x))
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
