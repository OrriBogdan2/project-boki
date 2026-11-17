class_name Glossary
extends RefCounted
## The one first-time hint path for words a new player meets before anything explains them
## (docs/UI_FIRST15.md 4). A screen that shows such a word asks `first_line(word)` (or `add_note` in
## a Control panel) and puts the line under it. The line keeps showing for the whole session the word
## is first seen in, then never again; seen words live in Save.d["tutorial"]["glossary"]. The words
## and lines are content/rules/glossary.json. Hints off (Settings "tips") or a clean recording: no lines.

const RULES_PATH := "res://content/rules/glossary.json"

static var _lines := {}            # word -> its one line
static var _this_session := {}     # words first seen in this session: their line keeps showing

## The one-line explanation of `word` while it is new to this save, else "".
static func first_line(word: String) -> String:
	if _lines.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_lines = parsed["lines"] if typeof(parsed) == TYPE_DICTIONARY else {}
	if not _lines.has(word) or not Settings.get_v("tips") or Record.clean():
		return ""
	var seen: Dictionary = Save.d["tutorial"].get_or_add("glossary", {})
	if seen.has(word) and not _this_session.has(word):
		return ""
	seen[word] = true
	_this_session[word] = true
	return String(_lines[word])

## Adds `word`'s first-time line to `box` as a small faint paragraph (nothing once it has been seen).
static func add_note(box: Control, word: String) -> void:
	var line := first_line(word)
	if line != "":
		box.add_child(UI.para(line, UI.T_SMALL, UI.FAINT))

## Forgets this session's words, as if the game had restarted (the check uses it).
static func new_session() -> void:
	_this_session.clear()
