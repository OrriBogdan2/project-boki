class_name HomeNotices
extends RefCounted
## One-time notices on the farm screen, moved out of home.gd: a stray turning up (Lifeline.check
## events), what the equal-footing save migration converted (EqualMigrate), and the Boki the market
## migration brought home (MarketSave).

const STRAY := "A stray %s wandered in to stay."
const STRAY_MORE := "Adopt more at the Shelter (the market stall)."
## A Boki starved: the lines under its "has died" card. `now` = it happened just now, not while you were away.
const DEATH_WHEN := "%s starved while you were away."
const DEATH_NOW := "%s starved."
const DEATH_REST := ["It had nothing to eat for days.", "Its grave is in the graveyard, east of the farm."]
const DEATH_FEEDER := "A filled feeder keeps your Boki fed."
const DEATH_SHRINE := "A Soul Shrine can bring a Boki back."
const BACK_HOME := ["You took %s back!", "It's home again.", "It won't forget you came for it."]
const EGG_HOME := ["Brought home %s!", "Off to the Incubator by the Nesting Nook.", "Eggs hatch one at a time."]
const NO_BOKI_HOME := [
	"With no Boki left at home, %s let one go on credit.", "It waited a long time and trusts you less now."
]
const SNACKS := ["The snack patch grew %d extra snacks.", "%d are in the bowl, the rest in the pantry."]


## The farm-room notice for an old save, first time home since the Kin Burrow: `room` Boki out, `resting` asleep.
static func burrow(room: int, resting: int) -> Array:
	return [
		"The farm has room for %d Boki out at once." % room,
		"Your partner and closest Boki stayed out.",
		"The other %d curled up in the Boki Burrow." % resting,
		"It is south of the market stall, by the pond.",
		"Boki in the burrow don't get hungry.",
		"Swap them out any time, or expand the cottages."
	]


## The lines under a Boki's "has died" card.
static func death(rec_name: String, away: bool, has_shrine: bool) -> Array:
	var lines: Array = [(DEATH_WHEN if away else DEATH_NOW) % rec_name] + DEATH_REST
	lines.append(DEATH_FEEDER)
	if not has_shrine:
		lines.append(DEATH_SHRINE)
	return lines


## Every fixed notice line, for --tutorial-text-check: a bullet card line over 60 characters fails.
static func fixed_lines() -> Array:
	var out: Array = [STRAY % "Mossling", STRAY_MORE, DEATH_FEEDER, DEATH_SHRINE]
	return (
		out
		+ burrow(8, 8)
		+ death("Mossling", true, false)
		+ fill(EGG_HOME, "a Rare Egg")
		+ fill(BACK_HOME, "Mossling")
		+ fill(NO_BOKI_HOME, "Old Pell")
		+ fill(SNACKS, 12)
	)


## `lines` with `arg` put into every line that has a "%" slot.
static func fill(lines: Array, arg) -> Array:
	return lines.map(func(l): return l % arg if "%" in String(l) else l)


## The toast when a stray turned up.
static func toast_stray(home: Node, events: Array) -> void:
	for fe in events:
		if String(fe["kind"]) == "stray":
			var srec: Dictionary = fe["rec"]
			home.get_tree().create_timer(1.0).timeout.connect(
				func():
					if is_instance_valid(home) and home.is_inside_tree():
						var species_name := String(Data.KIN[String(srec["species"])]["name"])
						home._show_when_free([STRAY % species_name, STRAY_MORE])
			)


## The one-time list of what the save migration converted: shown once, then forgotten.
static func show_migration(home: Node) -> void:
	var market = Save.d.get("market_notice", [])
	if typeof(market) == TYPE_STRING and market != "":
		market = [market]  # a save written before the notice became a list
	if typeof(market) == TYPE_ARRAY and not market.is_empty():
		Save.d.erase("market_notice")
		_later(home, market, "Boki aren't sold any more")
	var lines := EqualMigrate.take_notice()
	if not lines.is_empty():
		_later(home, lines, "Matches changed: everyone starts equal")


static func _later(home: Node, lines: Array, title: String) -> void:
	home.get_tree().create_timer(1.6).timeout.connect(
		func():
			if is_instance_valid(home) and home.is_inside_tree():
				home._show_when_free(lines, title)
	)


## A notice line as a bullet ("•"); a line that starts with spaces is a sub-point under the one above.
static func bullet(line: String) -> String:
	return ("      – " + line.strip_edges()) if line.begins_with("  ") else ("•  " + line)
