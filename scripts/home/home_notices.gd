class_name HomeNotices
extends RefCounted
## One-time notices on the farm screen, moved out of home.gd: a stray turning up (Lifeline.check
## events) and what the equal-footing save migration converted (EqualMigrate).

## The toast when a stray turned up.
static func toast_stray(home: Node, events: Array) -> void:
	for fe in events:
		if String(fe["kind"]) == "stray":
			var srec: Dictionary = fe["rec"]
			home.get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(home) and home.is_inside_tree():
					home._show_when_free(["A stray %s wandered onto the farm. With no Boki of your own, it's decided to stay with you." % Data.KIN[String(srec["species"])]["name"],
						"You can also buy a Boki at %s's Drift Pens." % BokiPens.MERCHANT]))

## The one-time list of what the save migration converted: shown once, then forgotten.
static func show_migration(home: Node) -> void:
	var lines := EqualMigrate.take_notice()
	if lines.is_empty():
		return
	home.get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(home) and home.is_inside_tree():
			home._show_when_free(lines))
