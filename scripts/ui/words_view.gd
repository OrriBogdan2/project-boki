class_name WordsView
extends RefCounted
## The Words page (Help in the pause menu and on the title): one plain line per term the game uses, shown
## once the player has met it, so the page never spoils. Terms, lines and when each shows are data:
## content/rules/words.json. Seen rules read the save's tutorial flags and expedition count.

const RULES_PATH := "res://content/rules/words.json"

static var _rules := {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if parsed is Dictionary else {"words": []}
	return _rules

## Whether the player has met a term: no rule always, else its tutorial flag is set or enough expeditions are played.
static func is_seen(w: Dictionary) -> bool:
	var seen: Dictionary = w.get("seen", {})
	if seen.has("tut") and not Save.d["tutorial"].get(String(seen["tut"]), false):
		return false
	return int(Save.d.get("matches", 0)) >= int(seen.get("matches", 0))

## The terms to show now, in order.
static func visible() -> Array:
	var out: Array = []
	for w in rules()["words"]:
		if is_seen(w):
			out.append(w)
	return out

## Fills a menu page with the visible terms.
static func fill(v: VBoxContainer) -> void:
	UI.subtitle(v, "Terms you have met so far")
	for w in visible():
		var row := UI.vbox(1)
		row.add_child(UI.label(String(w["term"]), UI.T_HEAD, UI.ACCENT_HI))
		row.add_child(UI.label(String(w["line"]), UI.T_SMALL, UI.INK))
		v.add_child(row)
