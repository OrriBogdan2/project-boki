class_name HomeNotices
extends RefCounted
## One-time notices on the farm screen, moved out of home.gd: a stray turning up (Lifeline.check
## events), what the equal-footing save migration converted (EqualMigrate), and the Boki the market
## migration brought home (MarketSave).


const STRAY := "A stray %s wandered in to stay."
const STRAY_MORE := "Adopt more at the Shelter (the market stall)."
## The farm-room notice for an old save, first time home since the Kin Burrow: %d = room, %d = resting.
const BURROW := ["The farm has room for %d Boki out at once.", "Your partner and closest Boki stayed out.",
	"The other %d curled up in the Boki Burrow.", "It is south of the market stall, by the pond.",
	"Boki in the burrow don't get hungry.", "Swap them out any time, or expand the cottages."]

## Every fixed notice line, for --tutorial-text-check: a bullet card line over 60 characters fails.
static func fixed_lines() -> Array:
	return [STRAY % "Mossling", STRAY_MORE] + BURROW.map(func(l): return l % 8 if "%d" in l else l)


## The toast when a stray turned up.
static func toast_stray(home: Node, events: Array) -> void:
	for fe in events:
		if String(fe["kind"]) == "stray":
			var srec: Dictionary = fe["rec"]
			home.get_tree().create_timer(1.0).timeout.connect(
				func():
					if is_instance_valid(home) and home.is_inside_tree():
						var species_name := String(Data.KIN[String(srec["species"])]["name"])
						home._show_when_free(
							[STRAY % species_name, STRAY_MORE]
						)
			)


## The one-time list of what the save migration converted: shown once, then forgotten.
static func show_migration(home: Node) -> void:
	var market = Save.d.get("market_notice", [])
	if typeof(market) == TYPE_STRING and market != "":
		market = [market]     # a save written before the notice became a list
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
