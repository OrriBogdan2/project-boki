class_name MasterySeep
extends RefCounted
## The first mastery feature (MasteryLook: eyes, a scar...) shows on your own character with no word of why.
## On the first farm arrival after one is earned, one line says so and points at the menu's "Change your
## look", where you keep or fade it. Once per save (Save.d["tutorial"]["mastery_seep"], set as it shows);
## it waits out the farm tutorial and never shows on a visit.

const TEXT := "Your Relic has left its mark on you: %s. Open the menu (%s), Change your look, to keep it or fade it."


## What the line says, or "" while no feature is earned.
static func line() -> String:
	var names: Array = []
	for f in MasteryLook.features():
		if MasteryLook.earned(f):
			names.append(String(f["name"]).to_lower())
	if names.is_empty():
		return ""
	return TEXT % [" and ".join(names), Settings.key_cap("menu")]


## On arriving at your farm: shows the line once.
static func maybe_show(home: Node) -> void:
	var seen: Dictionary = Save.d["tutorial"]
	var text := line()
	if text == "" or seen.get("mastery_seep", false) or FarmTutorial.active():
		return
	seen["mastery_seep"] = true
	home._toast(text)
	Save.save_game()
