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
	return "%s the %s" % [player_name, title(archetype)]

static func of_hunter(hunter: Hunter) -> String:
	return label(hunter.pname, hunter.arch)

## "Originally Hem, female" for the class intro and picker.
static func origin_line(archetype: String) -> String:
	var gender_text := gender(archetype)
	if gender_text == "robot":
		return "Originally %s, a robot" % base_name(archetype)
	return "Originally %s, %s" % [base_name(archetype), gender_text]

## The origin line and personality as two labels, for any class screen.
static func intro_block(archetype: String, width: float, centered := false) -> Control:
	var box := UI.vbox(3)
	var origin := UI.label(origin_line(archetype), UI.T_SMALL, Arch.color(archetype), UI.semi)
	var story := UI.para(personality(archetype), UI.T_SMALL, UI.MUTED)
	story.custom_minimum_size.x = width
	if centered:
		origin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(origin)
	box.add_child(story)
	box.set_meta("hero_intro", archetype)
	return box
