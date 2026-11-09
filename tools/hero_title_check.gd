extends RefCounted
## --hero-title-check: every class has a title, a base character (name, gender) and a personality, and
## no old personal name is a player-facing hero label (the base_name field is the one place it lives).

const OLD_NAMES := ["Dancer", "Zedran", "Pin", "Bjorn", "Vireo", "Venator", "Tamsin", "Linwick", "Dredge",
	"Moosh Moosh", "Burple", "Breah", "Ostra",
	"Breaker", "Lisette", "Ravel", "Claire", "Tarek", "Pip", "Frost Siren", "Cliff Runner",
	"Ryzz", "Ravyl", "Kibo", "Magic Fox", "Snowglider", "Sunken Bulwark",
	"Mossy", "Hem", "Flame Queen", "Undying Queen"]
## Words retired from player text (Hunter / Relic / the Empty / Fusion replace them; ids and code names may keep them).
const RETIRED_TERMS := "(?i)\\b(wardens?|mantles?|bearers?|merge[sd]?|unmasked|masks?)\\b"
const CANONICAL_ORDER := [
	"gunslinger", "juggernaut", "ashwick", "tender", "dolm", "archer",
	"dredge", "rimewright", "mage", "bulwark", "thief", "ostra",
]
const RELIC_STATUS := ["locked", "proposed"]
const GENDERS := ["male", "female", "robot"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HEROTITLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var titles: Array = []
	for id in Arch.ids():
		titles.append(HeroTitle.title(id))
	ok(Arch.ids().size() == 12, "twelve classes (%d)" % Arch.ids().size())
	ok(Arch.ORDER == CANONICAL_ORDER, "Arch.ORDER is the canonical Hunter order")
	ok(Arch.name_of("rimewright") == "The Snowglide" and Arch.name_of("juggernaut", true) == "the Unbroken",
		"a title on its own carries 'the' (%s, %s)" % [Arch.name_of("rimewright"), Arch.name_of("juggernaut", true)])
	for id in Arch.ids():
		var data := Arch.def(id)
		var complete: bool = true
		for key in ["title", "base_name", "gender", "personality"]:
			complete = complete and String(data.get(key, "")) != ""
		ok(complete, "%s has a title, base name, gender and personality" % id)
		ok(GENDERS.has(HeroTitle.gender(id)), "%s gender is %s" % [id, HeroTitle.gender(id)])
		var story_lines := String(data.get("personality", "")).split("\n").size()
		ok(story_lines <= 3, "%s personality is three lines at most" % id)
		var label := HeroTitle.label("Orri", id)
		var bare := HeroTitle.title(id)
		var title := String(data["title"])
		ok(not title.begins_with("The ") and not title.begins_with("the "), "%s stores its title without 'the'" % id)
		ok(label == "Orri the %s" % bare and not label.contains("the The"), "%s label reads '%s'" % [id, label])
		var shown: Array = [Arch.name_of(id), Arch.label(id), label, _plain_text(data)]
		for text in shown:
			var found_old := _old_name_in(String(text))
			ok(found_old == "", "%s: no old name in a player-facing label (%s)" % [id, found_old])
		var retired := RegEx.create_from_string(RETIRED_TERMS).search(_plain_text(data))
		ok(retired == null, "%s: no retired term in its text (%s)" % [id, retired.get_string() if retired else ""])
		var shown_name := HunterViewer.display_name(id)
		ok(shown_name.begins_with(HeroTitle.base_name(id) + " the ") and not shown_name.contains("the The"),
				"%s shows as '%s', with no gender line" % [id, shown_name])
	_lore_check()
	print("HEROTITLE CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## content/rules/lore.json: every class sits in exactly one faction and has a relic with a known status, and its
## text uses no old name or retired term; Cinder carries no goggles, tank or flamethrower, Meeko no lantern.
func _lore_check() -> void:
	var lore = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/lore.json"))
	ok(typeof(lore) == TYPE_DICTIONARY, "lore.json parses")
	if typeof(lore) != TYPE_DICTIONARY:
		return
	ok(lore["factions"].size() == 5, "five factions")
	for id in Arch.ids():
		var homes: int = lore["factions"].filter(func(f): return f["hunters"].has(id)).size()
		ok(homes == 1, "%s sits in exactly one faction (%d)" % [id, homes])
		var relic: Dictionary = lore["hunters"].get(id, {}).get("relic", {})
		var known: bool = RELIC_STATUS.has(relic.get("status", "")) and String(relic.get("name", "")) != ""
		ok(known, "%s has a relic with a status" % id)
	var text := JSON.stringify(lore)
	ok(_old_name_in(text) == "", "lore.json: no old name (%s)" % _old_name_in(text))
	ok(RegEx.create_from_string(RETIRED_TERMS).search(text) == null, "lore.json: no retired term")
	var cinder := _plain_text(Arch.def("ashwick")) + JSON.stringify(lore["hunters"]["ashwick"])
	var banned := RegEx.create_from_string("(?i)goggles|\\btank\\b|\\bhose")
	ok(banned.search(cinder) == null, "Cinder: no goggles, tank or hose")
	var meeko := _plain_text(Arch.def("tender")) + JSON.stringify(lore["hunters"]["tender"])
	ok(not meeko.replace("lantern_crook", "").to_lower().contains("lantern"), "Meeko: no lantern (her weapon id aside)")

## The class JSON as text with the base-character fields removed: the rest is shown to players.
func _plain_text(data: Dictionary) -> String:
	var copy := data.duplicate(true)
	copy.erase("base_name")
	return JSON.stringify(copy)

## The first old personal name found in text once the class titles (Snowglide ...) are taken out.
func _old_name_in(text: String) -> String:
	var rest := text
	for title in _all_titles():
		rest = rest.replace(title, "")
	for old in OLD_NAMES:
		var found := RegEx.create_from_string("\\b%s\\b" % old).search(rest)
		if found != null:
			return old
	return ""

func _all_titles() -> Array:
	return Arch.ids().map(func(id): return HeroTitle.title(id))
