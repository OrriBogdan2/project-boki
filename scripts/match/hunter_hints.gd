class_name HunterHints
extends RefCounted
## First-time Hunter hints: the first time a save plays a Hunter, one short line as each of its five slots
## first matters (primary, right click, E, dash, ultimate). The words are the "hint" block of
## content/archetypes/<id>.json, with the player's own keys ({fire}, {secondary}, {signature}, {dash},
## {hunter_ult}); a slot with a two-step move tells both steps in its line. Shown once through
## FirstTimeHint (ids "<hunter>.<slot>", kept per Hunter in Save.d.tutorial.hints); MatchHints ticks it.

const SLOTS := ["lmb", "rmb", "e", "dash", "x"]

static func id(arch: String, slot: String) -> String:
	return "%s.%s" % [arch, slot]

## A hint's words with the keys still as {placeholders} ("" for an id that is not a Hunter hint).
static func raw(hint_id: String) -> String:
	var parts := hint_id.split(".")
	if parts.size() != 2 or not Arch.exists(parts[0]):
		return ""
	return String((Arch.def(parts[0]).get("hint", {}) as Dictionary).get(parts[1], ""))

## The hint to show now, or "": the next unseen of the four fighting slots once a foe is close, then the
## ultimate's once it can be bought.
static func due(arch: String, level: int, foe_near: bool) -> String:
	if not Arch.exists(arch):
		return ""
	for slot in SLOTS.slice(0, 4):
		if not FirstTimeHint.seen(id(arch, slot)):
			return id(arch, slot) if foe_near else ""
	var ult := id(arch, "x")
	return ult if not FirstTimeHint.seen(ult) and level >= int(Hunter.ULT_AT[0]) else ""

## Save v12 -> v13: a Hunter the save has already played is no stranger; it gets none of its hints.
static func migrate(data: Dictionary) -> void:
	var tut: Dictionary = data.get("tutorial", {})
	var seen: Dictionary = tut.get("hints", {}) if typeof(tut.get("hints")) == TYPE_DICTIONARY else {}
	var classes: Dictionary = data.get("classes", {})
	var played: Dictionary = classes.get("hunters", {}) if typeof(classes.get("hunters")) == TYPE_DICTIONARY else {}
	for arch in played:
		if (played[arch] as Dictionary).values().any(func(n): return int(n) > 0):
			for slot in SLOTS:
				seen[id(String(arch), slot)] = true
	tut["hints"] = seen
	data["tutorial"] = tut
