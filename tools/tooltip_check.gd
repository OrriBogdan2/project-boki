extends RefCounted
## --tooltip-check: hero tooltip numbers come from the kit data. A number in an ability text is a {token}
## (ArchText fills it at load); the typed ones still on disk may only shrink (TYPED_MAX: tokenise more, then
## lower it). Every archetype's filled text has no token left unfilled and no "{?path}" marker, and a figure
## written as a token shows the number the kit data holds (a spot check of one token per kind).

const NUMBER := "(?<![\\w.])\\d+(?:\\.\\d+)?"
## Digits that name something rather than count it: rank and level labels, ordinals, an ability's name.
const LABEL := "(?i)\\b(rank|ranks|level|lv) \\d+|\\(level \\d+\\)|\\b\\d+(st|nd|rd|th)\\b|360 Smash"
## A number token ArchText left (a path with a dot, or its "{?path}" marker); a key token ("{dash}") is AbilityText's.
const UNFILLED := "\\{[a-z0-9_]*[.?][^}]*\\}"
## Typed numbers in the 13 archetype files' ability text on disk.
const TYPED_MAX := 935
# story, a source link, ids and art names
const SKIP_KEYS := ["personality", "src", "sources", "id", "icon", "col", "color", "edge"]

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("TIPCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	var typed := 0
	var unfilled := RegEx.create_from_string(UNFILLED)
	for id in Arch.ids():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/archetypes/%s.json" % id))
		typed += _numbers_in(_strings(raw, [])).size()
		var filled := _strings(Arch.def(id), [])
		ok(filled.all(func(s): return unfilled.search(s) == null), "%s: every number token filled" % id)
	ok(typed <= TYPED_MAX, "typed numbers on disk %d <= %d" % [typed, TYPED_MAX])
	_spot_check()
	print("TIPCHECK %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)


## One token of each kind, against a tiny kit.
func _spot_check() -> void:
	var kit := {
		"rmb": {"cooldown": 8.0, "pin": {"dmg": [6.0, 9.0]}},
		"e": {"slow": 0.3, "cooldown": 10.0},
		"dash": {"cd": 9.0, "walk_k": 1.4},
		"rank_cd": {"sec": [1, 0.8, 0.6]}
	}
	ok(ArchText.text("{rmb.pin.dmg.1}", kit) == "9", "an array step")
	ok(ArchText.text("{e.slow%}", kit) == "30", "a percent")
	ok(ArchText.text("{dash.walk_k-1%}", kit) == "40", "a multiplier's gain as a percent")
	ok(ArchText.text("{cd3.sec}", kit) == "4.8", "the cooldown at rank 3")
	ok(ArchText.text("{dash}", kit) == "{dash}", "a key token is left for AbilityText")
	ok(ArchText.text("{e.nope}", kit) == "{?e.nope}", "a missing number shows its path")


func _strings(o: Variant, out: Array) -> Array:
	if o is Dictionary:
		for k in o:
			if not k in SKIP_KEYS:
				_strings(o[k], out)
	elif o is Array:
		for v in o:
			_strings(v, out)
	elif o is String and not (o as String).begins_with("#"):
		out.append(o)
	return out


## The numbers in these strings, as text, after the labels and any {tokens} are taken out.
func _numbers_in(strings: Array) -> Array:
	var label := RegEx.create_from_string(LABEL)
	var num := RegEx.create_from_string(NUMBER)
	var token := RegEx.create_from_string("\\{[^}]*\\}")
	var out: Array = []
	for s in strings:
		for m in num.search_all(label.sub(token.sub(String(s), "", true), "", true)):
			out.append(m.get_string())
	return out
