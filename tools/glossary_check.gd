extends RefCounted
## --glossary-check (docs/UI_FIRST15.md 4): the first-time lines (Glossary, content/rules/glossary.json)
## and the plain words that replaced jargon. Every line is one short line with no retired term; every
## drop-map spawn category has one; a line shows for the whole session its word is first seen in, then
## never again, and not at all with hints off; the Relics page's mastery list carries it the first time.

const LINE_MAX := 70           # chars: a panel line under a heading
const LEGEND_MAX := 34         # chars: the drop map's legend is about this wide at 11 px
## Words the glossary pass replaced with plain words, and the file each one was shown from.
const REPLACED := {
	"scripts/ui/full_map.gd": ["\"Drop leader\"", "\"Pass the lead\""],
	"scripts/home/home.gd": ["\"Boki at risk\""],
}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("GLOSSARY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Settings.set_v("tips", true, false)
	_lines()
	_sessions()
	_mastery_note()
	_replaced()
	print("GLOSSARY CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _lines() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(Glossary.RULES_PATH))
	ok(typeof(parsed) == TYPE_DICTIONARY and parsed.has("lines"), "glossary.json parses")
	var lines: Dictionary = parsed["lines"]
	var retired := RegEx.create_from_string(preload("res://tools/hero_title_check.gd").RETIRED_TERMS)
	var legend_words: Array = SpawnPlan.CATS.values().map(func(def): return String(def["name"]))
	for word in lines:
		var line := String(lines[word])
		var most := LEGEND_MAX if legend_words.has(word) else LINE_MAX
		ok(line != "" and not line.contains("\n") and line.length() <= most,
				"%s: one line of %d chars (at most %d)" % [word, line.length(), most])
		ok(retired.search(line) == null, "%s: no retired term" % word)
	for word in legend_words:
		ok(lines.has(word), "the drop map's '%s' has a first-time line" % word)

func _sessions() -> void:
	Settings.set_v("tips", false, false)
	ok(Glossary.first_line("Vault") == "", "hints off: no line (and the word stays new)")
	Settings.set_v("tips", true, false)
	var first := Glossary.first_line("Vault")
	ok(first != "", "a new save: the line shows (%s)" % first)
	ok(Glossary.first_line("Vault") == first, "the same session: it keeps showing")
	ok(Save.d["tutorial"]["glossary"].has("Vault"), "the save remembers the word")
	ok(Glossary.first_line("Shrine") == "", "a word with no line: nothing")
	Glossary.new_session()
	ok(Glossary.first_line("Vault") == "", "the next session: gone")

func _mastery_note() -> void:
	var id := Arch.of_save()
	ok(_has_note(ClassCard.mastery_list(id)), "Relics page, first visit: the mastery list explains Mastery")
	Glossary.new_session()
	ok(not _has_note(ClassCard.mastery_list(id)), "Relics page, a later session: no line")

func _has_note(list: Control) -> bool:
	var line := String(JSON.parse_string(FileAccess.get_file_as_string(Glossary.RULES_PATH))["lines"]["Mastery"])
	var found := list.get_children().any(func(ch): return ch is Label and (ch as Label).text == line)
	list.free()
	return found

func _replaced() -> void:
	for path in REPLACED:
		var text := FileAccess.get_file_as_string("res://" + path)
		for old in REPLACED[path]:
			ok(not text.contains(old), "%s no longer shows %s" % [path.get_file(), old])
