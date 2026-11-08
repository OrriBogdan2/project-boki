extends RefCounted
## --hero-title-check: every class has a title, a base character (name, gender) and a personality, and
## no old personal name is a player-facing hero label (the base_name field is the one place it lives).

const OLD_NAMES := ["Dancer", "Zedran", "Pin", "Bjorn", "Vireo", "Venator", "Tamsin", "Linwick", "Dredge",
	"Hem", "Breaker", "Ryzz", "Pip", "Claire", "Tarek", "Lisette", "Mossy", "Ravel", "Snowglider",
	"Moosh Moosh", "Burple", "Breah", "Ostra"]
## Words retired from player text (Hunter / Mask / the Empty / Fusion replace them; ids and code names may keep them).
const RETIRED_TERMS := "(?i)\\b(wardens?|mantles?|bearers?|merge[sd]?|unmasked)\\b"
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
		var bare := HeroTitle.title(id).trim_prefix("The ")   # "Orri the Unbroken", never "the The"
		ok(label == "Orri the %s" % bare and not label.contains("the The"), "%s label reads '%s'" % [id, label])
		var shown: Array = [Arch.name_of(id), Arch.label(id), label, _plain_text(data)]
		for text in shown:
			var found_old := _old_name_in(String(text))
			ok(found_old == "", "%s: no old name in a player-facing label (%s)" % [id, found_old])
		var retired := RegEx.create_from_string(RETIRED_TERMS).search(_plain_text(data))
		ok(retired == null, "%s: no retired term in its text (%s)" % [id, retired.get_string() if retired else ""])
		var shown_name := HunterViewer.display_name(id)
		ok(shown_name.begins_with(HeroTitle.base_name(id) + ", the ") and not shown_name.contains("the The"),
				"%s shows as '%s', with no gender line" % [id, shown_name])
	print("HEROTITLE CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

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
