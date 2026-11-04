class_name HeroTitle
extends RefCounted
## A class's title and base character, read from content/archetypes/<id>.json ("title", "base_name",
## "gender", "personality"), so renaming is a data edit. A hunter in a match reads "<player> the <title>".

static func title(archetype: String) -> String:
	return Arch.name_of(archetype)

static func base_name(archetype: String) -> String:
	return String(Arch.def(archetype).get("base_name", ""))

static func gender(archetype: String) -> String:
	return String(Arch.def(archetype).get("gender", ""))

static func personality(archetype: String) -> String:
	return String(Arch.def(archetype).get("personality", "")).replace("\n", " ")

## "Orri the Red Stitch"; the bare player name when the body has no class.
static func label(player_name: String, archetype: String) -> String:
	if not Arch.exists(archetype):
		return player_name
	var t := title(archetype)
	if t.begins_with("The "):   # "Orri the Unbroken", not "Orri the The Unbroken"
		t = t.substr(4)
	return "%s the %s" % [player_name, t]

static func of_hunter(hunter: Hunter) -> String:
	return label(hunter.pname, hunter.arch)
