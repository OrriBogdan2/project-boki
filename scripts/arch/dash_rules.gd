class_name DashRules
extends RefCounted
## Dash -> ability rules: one small per-hero table in content/rules/dash_interactions.json
## and one helper, so no kit special-cases it. An attack tapped while the dash blocks it is held and
## goes off when the dash ends (within the table's buffer window), never silently dropped.

static var _t: Dictionary = {}

static func table() -> Dictionary:
	if _t.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/dash_interactions.json"))
		_t = d if d is Dictionary else {"buffer": 0.15, "heroes": {}}
	return _t

static func buffer_time() -> float:
	return float(table().get("buffer", 0.15))

## What the table says for hero `aid`, phase "ground"|"air"|"reverse", key. A hero not in the table yet
## ("fires") keeps its own behaviour; one in the table defaults to "buffers".
static func rule(aid: String, phase: String, key: String) -> String:
	var heroes: Dictionary = table().get("heroes", {})
	if not heroes.has(aid):
		return "fires"
	var hero: Dictionary = heroes[aid]
	return String((hero.get(phase, {}) as Dictionary).get(key, "buffers"))

## The attack key's state for this frame: a press the dash swallowed is kept and returned as held
## once the dash is over, for the table's window.
static func lmb(h: Hunter, held: bool, dt: float) -> bool:
	var pressed := held and not h.dfire_was
	h.dfire_was = held
	if h.roll_t > 0.0 and not h.can_fire():
		var aid: String = h.ak.id if h.ak else ""
		if pressed and rule(aid, "ground" if h.grounded else "air", "lmb") == "buffers":
			h.dfire_buf = 99.0
		return held
	if h.dfire_buf > 0.0:
		h.dfire_buf = minf(h.dfire_buf, buffer_time()) - dt
		if h.dfire_buf > 0.0 and h.can_fire():
			h.dfire_buf = 0.0
			return true
	return held
