extends RefCounted
## --ability-text-check: AbilityText is the one reader of ability words. For every archetype and slot the kit
## card, its strip row and the viewer say the AbilityText name, short name and line; a key is never typed as a
## letter in an ability text on disk (a {action} token, filled from the player's bindings); every token is
## filled when read. Prints ABTEXT ok/FAIL, never touches the save.

const SLOTS := ["lmb", "dash", "rmb", "e", "x", "passive"]
## A key named in words in a text (the story, the how-to lines and the design sources are not ability text).
const KEY_WORD := "\\b(LMB|RMB|MMB|Shift|Space|Ctrl)\\b"
const SKIP_KEYS := ["personality", "howto", "src", "sources"]

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("ABTEXT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	for id in Arch.ids():
		_hero(id)
	print("ABTEXT %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)


func _hero(id: String) -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/archetypes/%s.json" % id))
	var key_word := RegEx.create_from_string(KEY_WORD)
	var typed := _strings(raw, []).filter(func(s): return key_word.search(String(s)) != null)
	ok(typed.is_empty(), "%s: no key named by letter in its ability text (%s)" % [id, ", ".join(typed.slice(0, 2))])
	var shown: Array = [AbilityText.loop(id)]
	for slot in SLOTS:
		if slot in ["e", "x"] and not Arch.def(id).has(slot):
			continue
		var t := KitCard.slot_text(id, slot)
		ok(t["name"] == AbilityText.name_of(id, slot), "%s %s: card name is the reader's" % [id, slot])
		ok(t["short"] == AbilityText.short_name(id, slot), "%s %s: card short name is the reader's" % [id, slot])
		ok(t["line"] == AbilityText.line(id, slot), "%s %s: card line is the reader's" % [id, slot])
		ok(HunterViewer.slot_info(id, slot)["line"] == t["line"], "%s %s: viewer line is the card's" % [id, slot])
		ok(t["name"] != "" and t["line"] != "", "%s %s: has a name and a line" % [id, slot])
		shown.append_array([t["name"], t["line"], AbilityText.full(id, slot)])
		for row in t["detail"]:
			shown.append(String(row[1]))
	ok(shown.all(func(s): return not "{" in String(s)), "%s: every token filled when read" % id)


func _strings(o: Variant, out: Array) -> Array:
	if o is Dictionary:
		for k in o:
			if not k in SKIP_KEYS:
				_strings(o[k], out)
	elif o is Array:
		for v in o:
			_strings(v, out)
	elif o is String:
		out.append(o)
	return out
