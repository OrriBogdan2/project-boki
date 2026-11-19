class_name HunterHints
extends RefCounted
## First-time Hunter hints, through Match._tip: the first time a save plays a Hunter, one short line as each of
## its four fighting slots (primary, right click, E, dash) first matters, once a foe is close. The words are the
## "hint" block of content/archetypes/<id>.json, with {fire}, {secondary}, {signature} and {dash} as the player's
## own keys. Seen flags are "hh_<hunter>_<slot>" in Save.d.tutorial. The ultimate has its own hint (FirstUltHint).

const SLOTS := ["lmb", "rmb", "e", "dash"]
const GAP_S := 8.0   # s between two of these lines (a hint stays up HUD.TIP_LIFE = 6 s)
const FOE_M := 9.0   # m: a monster or rival this close makes the next slot due

var _last_at := -99.0   # match time of the last line shown


static func key(arch: String, slot: String) -> String:
	return "hh_%s_%s" % [arch, slot]


## The next hint due as [save key, line], or [] (Match._tips asks every frame; at most one per GAP_S).
func next(m: Match) -> Array:
	var h := m.player
	if h.arch == "" or m.time - _last_at < GAP_S:
		return []
	for slot in SLOTS:
		var k := key(h.arch, slot)
		if Save.d["tutorial"].get(k, false):
			continue
		var words := String((Arch.def(h.arch).get("hint", {}) as Dictionary).get(slot, ""))
		if words == "" or not _foe_near(m, h):
			return []
		_last_at = m.time
		return [k, Settings.fill_keys(words)]
	return []


## Save v20 -> v21: a Hunter the save has already played is no stranger; it gets none of its hints.
static func migrate(data: Dictionary) -> void:
	var seen: Dictionary = data.get("tutorial", {})
	var classes = data.get("classes")
	var played = classes.get("hunters") if typeof(classes) == TYPE_DICTIONARY else null
	if typeof(played) == TYPE_DICTIONARY:
		for arch in played:
			if typeof(played[arch]) == TYPE_DICTIONARY and (played[arch] as Dictionary).values().any(_positive):
				for slot in SLOTS:
					seen[key(String(arch), slot)] = true
	data["tutorial"] = seen


static func _positive(n) -> bool:
	return (typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT) and n > 0


static func _foe_near(m: Match, h: Hunter) -> bool:
	for mb in m.mobs:
		if not mb.dead and h.flat_dist(mb) < FOE_M:
			return true
	for e in m.hunters:
		if e.team != h.team and not e.out and not e.downed and h.flat_dist(e) < FOE_M:
			return true
	return false
