class_name KinNames
extends RefCounted
## Names for a new Boki: a suggestion built from its species' name (a root plus an ending, both from
## content), and the check that keeps rude names out. Numbers and word lists: content/rules/kin_names.json.

static func rules() -> Dictionary:
	return Content.rules("kin_names")

## The species name's first syllable: up to and including the consonant after its first vowels ("Cindle" -> "Cin").
static func root(species: String) -> String:
	var sp_name := Data.default_kin_name(species)
	var i := 0
	while i < sp_name.length() and not _vowel(sp_name[i]):
		i += 1
	while i < sp_name.length() and _vowel(sp_name[i]):
		i += 1
	return sp_name.substr(0, mini(i + 1, sp_name.length()))

## A name to suggest: the root plus an ending, never a rude one.
static func suggest(species: String, rng: RandomNumberGenerator) -> String:
	var endings: Array = rules()["endings"]
	var base := root(species)
	for _try in 8:
		var nm := base + String(endings[rng.randi_range(0, endings.size() - 1)])
		if not is_rude(nm):
			return nm
	return Data.default_kin_name(species)

## True if the name holds a word from the rude list (letters only, any case).
static func is_rude(nm: String) -> bool:
	var plain := ""
	for ch in nm.to_lower():
		if ch >= "a" and ch <= "z":
			plain += ch
	for word in rules()["rude"]:
		if plain.contains(String(word)):
			return true
	return false

## The name a Boki keeps: what was typed, or the suggestion if the box is empty or the name is rude.
static func pick(typed: String, suggestion: String) -> String:
	var nm := typed.strip_edges()
	return suggestion if nm == "" or is_rude(nm) else nm

static func _vowel(ch: String) -> bool:
	return "aeiouyAEIOUY".contains(ch)
