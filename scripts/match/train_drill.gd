class_name TrainDrill
extends RefCounted
## The Training Area checklist (content/rules/training_drill.json), worded with the player's own keys.


## [[id, what to do, action], ...]
static func rows() -> Array:
	return Content.rules("training_drill")["rows"]


## A row's line: "{key}" is the cap of the row's own action (Settings.key_cap), so a rebind shows.
static func text(t: Array) -> String:
	return String(t[1]).replace("{key}", Settings.key_cap(String(t[2])))


static func label(id: String) -> String:
	for t in rows():
		if t[0] == id:
			return text(t)
	return id
