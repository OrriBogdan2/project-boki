class_name WaysHints
extends RefCounted
## First-time hints for Limited Ways Out (docs/decisions/0051-limited-ways-out.md): the first time the
## Blight's tide closes, a quest seat opens and the Heart wakes, a new player reads one plain line about
## it in the message lane. Each shows once per save: Match._tip keeps the seen ones in Save.d["tutorial"]
## as "ways_<id>". Texts: content/rules/heart.json "hints".

## The hint due now as [save key, text], or [] for none (no Heart in this match, or nothing new).
static func due(m: Match) -> Array:
	if m.heart == null:
		return []
	var hints: Dictionary = Heart.rules()["hints"]
	var seen: Dictionary = Save.d["tutorial"]
	for id: String in hints:
		if not id.begins_with("_") and not seen.get("ways_" + id, false) and _now(m, id):
			return ["ways_" + id, hints[id]]
	return []

static func _now(m: Match, id: String) -> bool:
	match id:
		"tide":
			return Heart.tide_stage(m) >= 0
		"quest":
			var qs: QuestSeats = m.exits.seats if m.exits else null
			return qs != null and qs.seats().any(func(s: QuestSeat): return s.state == QuestSeat.S.OPEN)
		"heart":
			return m.heart.state in [Heart.S.CHARGING, Heart.S.READY, Heart.S.CARRIED]
	return false
