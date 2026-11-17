class_name HeroTitle
extends RefCounted
## A class's title and base character, read from content/archetypes/<id>.json ("title", "base_name",
## "gender", "personality"), so renaming is a data edit. Match hunters (bots too) show only their player name.

static func title(archetype: String) -> String:
	return Arch.bare_title(archetype)

static func base_name(archetype: String) -> String:
	return String(Arch.def(archetype).get("base_name", ""))

static func gender(archetype: String) -> String:
	return String(Arch.def(archetype).get("gender", ""))

static func personality(archetype: String) -> String:
	return String(Arch.def(archetype).get("personality", "")).replace("\n", " ")

## "Orri the Red Stitch" on the profile and results screens; the bare name when the body has no class.
static func label(player_name: String, archetype: String) -> String:
	if not Arch.exists(archetype):
		return player_name
	return "%s the %s" % [player_name, title(archetype)]   # titles are stored without "the"
