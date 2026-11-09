extends RefCounted
## --boki-types-check: the 18 Boki types (KinTypes, owner decision 2026-11-08 22:29 ET).
##   1. the table: 18 ids, the same set as KinParts.THEMES, one colour each, "spore" kept
##   2. aliases: all 17 old ids load as their new id; nothing else maps; canon is idempotent
##   3. the species: every one has a valid type, a valid different second type or none, and
##      the roster's second types are in (Zephyrak Flying / Dragon, Selenfin Fairy / Water, ...)
##   4. content: no kin, ability, merge, merge-form or Boki-talk file spells a type with an old id
##   5. old files still load: a kin read with theme "lunar" comes out "fairy", an unknown second type is an error
##   6. what the player reads: Field Book names and badge colours, egg names, card labels
##   7. a saved Boki carries only its species, so old saves read the new types; the save upgrades

const OLD := {
	"ember": "fire", "tide": "water", "bloom": "grass", "storm": "electric", "frost": "ice", "stone": "rock",
	"gravity": "psychic", "tempest": "flying", "wyrm": "dragon", "shadow": "dark", "venom": "poison",
	"swarm": "bug", "titan": "steel", "lunar": "fairy", "prism": "crystal", "echo": "sound", "wild": "normal",
}
const SECOND := {
	"cairnback": "rock", "gloamshell": "fairy", "glomwort": "poison", "hivara": "steel", "lodestick": "dark",
	"mossgrade": "steel", "murmurling": "sound", "nettlynx": "grass", "selenfin": "water",
	"umbrathere": "flying", "zephyrak": "dragon",
}
const OLD_EGGS := ["Venom Egg", "Gravity Egg", "Prism Egg", "Echo Egg", "Lunar Egg", "Storm Egg", "Ember Egg"]

var fails := 0
var n := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("BOKITYPES %-66s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main: Node) -> void:
	Save.no_write = true
	_table()
	_aliases()
	_species()
	_content()
	_old_files()
	_player_text()
	_saves()
	print("BOKITYPES DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

func _table() -> void:
	var ids: Array = KinTypes.TYPES.keys()
	ok("18 types", ids.size() == 18, str(ids.size()))
	var themes: Array = KinParts.THEMES.duplicate()
	themes.erase("none")
	themes.sort()
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	ok("the type table and the grammar themes are the same set", themes == sorted_ids)
	var cols := {}
	for t in ids:
		cols[KinTypes.col_of(t).to_html()] = true
	ok("every type has its own badge colour", cols.size() == 18)
	ok("Spore is kept", KinTypes.TYPES.has("spore") and not KinTypes.ALIASES.has("spore"))

func _aliases() -> void:
	var good := KinTypes.ALIASES.size() == OLD.size()
	for old in OLD:
		good = good and KinTypes.canon(old) == OLD[old] and KinTypes.canon(OLD[old]) == OLD[old]
	ok("the 17 old ids read as their new ids, new ids stay", good)
	ok("canon ignores case and spaces", KinTypes.canon(" Lunar ") == "fairy" and KinTypes.canon("FIRE") == "fire")
	var targets := true
	for old in OLD:
		targets = targets and KinTypes.TYPES.has(OLD[old])
	ok("every alias lands on a real type", targets)

func _valid(ts: Array) -> bool:
	if ts.is_empty() or ts.size() > 2 or ts.size() == 2 and ts[0] == ts[1]:
		return false
	return ts.all(func(t): return KinTypes.TYPES.has(t))

func _species() -> void:
	var bad: Array = []
	var seen := {}
	for spk in Data.KIN:
		var ts := KinTypes.of_species(Data.KIN[spk])
		if not _valid(ts):
			bad.append(spk)
		for t in ts:
			seen[t] = true
	ok("every species has a valid type and a valid different second type or none", bad.is_empty(), str(bad))
	var second_ok := true
	for spk in SECOND:
		second_ok = second_ok and Data.KIN.has(spk) and KinTypes.of_species(Data.KIN[spk]).back() == SECOND[spk]
	ok("the roster's %d second types are in" % SECOND.size(), second_ok)
	var kin: Dictionary = Data.KIN
	ok("species carry the mapped types", kin["zephyrak"]["type"] == "flying" and kin["wisplet"]["type"] == "fairy"
			and kin["puddlet"]["type"] == "crystal" and kin["cindle"]["type"] == "poison")
	ok("%d of the 18 types are in use by a species" % seen.size(), seen.size() >= 15, str(seen.keys()))

func _content() -> void:
	var hits: Array = []
	for dir in ["kin_v2", "abilities_v2", "merges_v2"]:
		for f in DirAccess.get_files_at("res://content/%s" % dir):
			if not f.ends_with(".json"):
				continue
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/%s/%s" % [dir, f]))
			for key in ["theme", "theme2"]:
				if typeof(d) == TYPE_DICTIONARY and OLD.has(String(d.get(key, ""))):
					hits.append("%s/%s %s" % [dir, f, key])
			if typeof(d) == TYPE_DICTIONARY and d.has("egg") and (d["egg"] as Dictionary).get("name", "") in OLD_EGGS:
				hits.append("%s/%s egg" % [dir, f])
	ok("no species, ability or merge file spells a type with an old id", hits.is_empty(), str(hits))
	var mf: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/merge_forms.json"))
	var old_keys: Array = []
	for k in (mf["types"] as Dictionary):
		if OLD.has(k): old_keys.append(k)
	ok("merge-form types use no old id", old_keys.is_empty(), str(old_keys))
	var talk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/boki_lines.json"))
	var talk_old: Array = []
	var elements: Dictionary = talk.get("elements", {}) if typeof(talk.get("elements", null)) == TYPE_DICTIONARY else {}
	for k in elements:
		if OLD.has(k): talk_old.append(k)
	ok("Boki talk element lines use no old id", talk_old.is_empty(), str(talk_old))

func _errs(rep: GrammarReport, word: String) -> bool:
	return rep.errors.any(func(e): return e.contains(word))

func _old_files() -> void:
	var src: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/kin_v2/wisplet.json"))
	src["theme"] = "lunar"
	var rep := GrammarReport.new()
	var k := KinSpec.parse(src, rep)
	ok("a kin file with theme \"lunar\" loads as fairy", k != null and k.theme == "fairy" and not _errs(rep, "theme"),
			str(rep.errors))
	src["theme2"] = "fairy"
	var rep2 := GrammarReport.new()
	KinSpec.parse(src, rep2)
	ok("a second type equal to the first is an error", _errs(rep2, "theme2"))
	src["theme2"] = "tomato"
	var rep3 := GrammarReport.new()
	KinSpec.parse(src, rep3)
	ok("an unknown second type is an error", _errs(rep3, "theme2"))
	src["theme2"] = "tempest"
	var rep4 := GrammarReport.new()
	var k4 := KinSpec.parse(src, rep4)
	ok("an old id works as a second type too", k4 != null and k4.theme2 == "flying" and not _errs(rep4, "theme2"))

func _player_text() -> void:
	var names := {"psychic": "Psychic", "gravity": "Psychic", "crystal": "Crystal", "sound": "Sound", "fairy": "Fairy"}
	var names_ok := true
	for id in names:
		names_ok = names_ok and DexView.type_name(id) == names[id]
	ok("Field Book names (old ids read as the new name)", names_ok)
	var grey := DexView.type_col("")
	ok("Field Book badge colours are set for fire, water, dragon",
			["fire", "water", "dragon"].all(func(t): return DexView.type_col(t) != grey))
	var kin: Dictionary = Data.KIN
	ok("card label: one type, then two",
			KinTypes.label(kin["wisplet"]) == "Fairy" and KinTypes.label(kin["zephyrak"]) == "Flying / Dragon")
	var eggs := {"cindle": "Poison Egg", "puddlet": "Crystal Egg", "zapple": "Sound Egg", "pebbit": "Psychic Egg"}
	var eggs_ok := true
	for id in eggs:
		eggs_ok = eggs_ok and Data.egg_name(id) == eggs[id]
	ok("egg names use the new type names", eggs_ok)
	var wiki := FileAccess.get_file_as_string("res://docs/wiki/Boki-Species.md")
	var rows := ["| Dragon |", "| Normal |", "| Sound |", "| Fairy |"]
	ok("the wiki's type table lists them", rows.all(func(r): return wiki.contains(r)))

func _saves() -> void:
	var rec := Save.new_kin("wisplet", "Moth")
	var types := KinTypes.of_species(Data.KIN[String(rec["species"])])
	ok("a saved Boki stores no type, so its species gives it the new one",
			not rec.has("type") and not rec.has("theme") and types == ["fairy"])
	var old := {"v": 5, "roster": [rec], "gems": 0}
	ok("an old save still upgrades to the current version", Save.migrate(old) and int(old["v"]) == Save.VERSION)
