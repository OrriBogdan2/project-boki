extends RefCounted
## --tooltip-check: no hero tooltip carries a typed number. For every archetype: the JSON on disk has no digits
## in its ability text (numbers are {tokens}, ArchText fills them at load), nothing is left unfilled, and every
## number in what the screens render (kit card and Practice rows, rank previews, pick-screen line, the whole
## filled file) is a number in that kit's data (its own leaves, as a percent, the rank cooldowns and damage,
## its signature weapon, its class's dashes, the Fusion surge). A stale figure typed into a text fails here.

var bad := 0
const NUMBER := "(?<![\\w.])\\d+(?:\\.\\d+)?"
## Digits that name something rather than count it: rank and level labels, ordinals, an ability's name.
const LABEL := "(?i)\\b(rank|ranks|level|lv) \\d+|\\(level \\d+\\)|\\b\\d+(st|nd|rd|th)\\b|360 Smash"
# story, a source link, ids and art names
const SKIP_KEYS := ["personality", "src", "id", "icon", "col", "color", "edge"]

func ok(cond: bool, what: String) -> void:
	print("TIPCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for id in Arch.ids():
		_hero(id)
	print("TIPCHECK %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(id: String) -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/archetypes/%s.json" % id))
	var typed := _numbers_in(_strings(raw, []))
	ok(typed.is_empty(), "%s: no typed number in its text on disk (%s)" % [id, ", ".join(typed.slice(0, 6))])
	var kit := Arch.def(id)
	var strings := _strings(kit, [])
	ok(strings.all(func(s): return not "{" in s), "%s: every token filled" % id)
	var known := _known(kit, id)
	var shown := strings.duplicate()
	shown.append_array(_rendered(id))
	var stray := _numbers_in(shown).filter(func(n): return not _in(known, float(n)))
	ok(stray.is_empty(), "%s: every number shown is in its kit data (%s)" % [id, ", ".join(stray.slice(0, 6))])

## What the kit card, Practice kit page, viewer and pick screen print for this hero.
func _rendered(id: String) -> Array:
	var out: Array = [String(Arch.def(id).get("card", {}).get("loop", ""))]
	for slot in KitCard.card_slots(id):
		var t := KitCard.slot_text(id, slot)
		out.append_array([t["name"], t["tag"], t["line"]])
		for row in t["detail"]:
			out.append_array([row[0], row[1]])
	for slot in ["sec", "dash", "kin", "ult"]:
		for r in Arch.next_ranks(id, slot, -1):
			out.append(String(r[1]))
	return out

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

## The numbers in these strings, as text, after the labels are taken out.
func _numbers_in(strings: Array) -> Array:
	var label := RegEx.create_from_string(LABEL)
	var num := RegEx.create_from_string(NUMBER)
	var out: Array = []
	for s in strings:
		for m in num.search_all(label.sub(String(s), "", true)):
			out.append(m.get_string())
	return out

## Every figure the kit may state: its numeric leaves (and x100), the rank cooldowns and damage, the signature
## weapon's stats, the class's dash count and the Fusion surge's length (the card's Fusion rows).
func _known(kit: Dictionary, id: String) -> Array:
	var out: Array = []
	_leaves(kit, out)
	for slot in ArchText.SLOT_BASE:
		for what in ["cd", "cd2", "cd3", "dmg2", "dmg3"]:
			out.append(ArchText.rank_value(kit, what, slot))
	_leaves(Data.weapon_stats(Arch.signature(id)), out)
	var w := Data.weapon_stats(Arch.signature(id))
	if w.has("rate"):
		out.append(1.0 / maxf(0.05, float(w["rate"])))
	out.append(float(Data.CLASSES.get(Arch.weight(id), {}).get("dashes", 1)))
	out.append(MergeForm.surge_spec().duration)
	return out.filter(func(v): return not is_nan(v))

func _leaves(o: Variant, out: Array) -> void:
	if o is Dictionary:
		for k in o:
			_leaves(o[k], out)
	elif o is Array:
		for v in o:
			_leaves(v, out)
	elif o is float or o is int:
		out.append(float(o))

## True when `n` is a known figure, within the rounding a tooltip shows (0.05; a percent is the figure x100).
func _in(known: Array, n: float) -> bool:
	return known.any(func(v): return absf(v - n) <= 0.051 or absf(v * 100.0 - n) <= 0.51)
