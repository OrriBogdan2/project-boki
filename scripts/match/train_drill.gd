class_name TrainDrill
extends RefCounted
## The Training Area checklist (content/rules/training_drill.json), worded with the player's own keys.


## [[id, what to do, action], ...]; no Fusion row (there is no fusion in the game: MergeForm's dev flag only).
static func rows() -> Array:
	var rows_v: Array = Content.rules("training_drill")["rows"]
	return rows_v.filter(func(t): return String(t[2]) != "ultimate" or MergeForm.enabled())


## A row's line: "{key}" is the cap of the row's own action (Settings.key_cap), so a rebind shows.
static func text(t: Array) -> String:
	return String(t[1]).replace("{key}", Settings.key_cap(String(t[2])))


static func label(id: String) -> String:
	for t in rows():
		if t[0] == id:
			return text(t)
	return id
