class_name HomeNotices
extends RefCounted
## One-time notices on the farm screen, moved out of home.gd: a stray turning up (Lifeline.check
## events), what the equal-footing save migration converted (EqualMigrate), and the Boki the market
## migration brought home (MarketSave).

## The toast when a stray turned up.
static func toast_stray(home: Node, events: Array) -> void:
	for fe in events:
		if String(fe["kind"]) == "stray":
			var srec: Dictionary = fe["rec"]
			home.get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(home) and home.is_inside_tree():
					var species_name := String(Data.KIN[String(srec["species"])]["name"])
					home._show_when_free(["A stray %s wandered in and decided to stay." % species_name,
						"Adopt more at the Shelter (the market stall)."]))

## The one-time list of what the save migration converted: shown once, then forgotten.
static func show_migration(home: Node) -> void:
	var market := String(Save.d.get("market_notice", ""))
	if market != "":
		Save.d.erase("market_notice")
		_later(home, [market], "Boki aren't sold any more")
	var lines := EqualMigrate.take_notice()
	if not lines.is_empty():
		_later(home, lines, "Matches changed: everyone starts equal")

static func _later(home: Node, lines: Array, title: String) -> void:
	home.get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(home) and home.is_inside_tree():
			home._show_when_free(lines, title))

## A notice line as a bullet ("•"); a line that starts with spaces is a sub-point under the one above.
static func bullet(line: String) -> String:
	return ("      – " + line.strip_edges()) if line.begins_with("  ") else ("•  " + line)
