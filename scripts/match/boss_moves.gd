class_name BossMoves
extends RefCounted
## The lair bosses' attack numbers (content/rules/boss_moves.json): tells, shapes and damage.

static var _d := {}

static func rules() -> Dictionary:
	if _d.is_empty():
		_d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/boss_moves.json"))
	return _d

static func move(boss: String, move_id: String) -> Dictionary:
	return rules()["moves"][boss][move_id]

## The wind-up in seconds for a move, from its base tell: quickening moves speed up with enrage and
## phase, but never below the floor. Always computed from the content, never from the last attack.
static func tell(boss: String, move_id: String, enraged: bool, phase: int) -> float:
	var mv := move(boss, move_id)
	var base := float(mv["tell_s"])
	if not mv["quickens"]:
		return base
	var k: float = float(rules()["enrage_tell_k"]) if enraged else 1.0
	k *= 1.0 - float(rules()["phase_tell_k"]) * phase
	return maxf(float(rules()["min_tell_s"]), base * k)

## Seconds from the first ground ring to the hit: the tell, plus the flight of a thrown rock.
static func ring_s(boss: String, move_id: String) -> float:
	return float(move(boss, move_id)["tell_s"]) + float(move(boss, move_id).get("flight_s", 0.0))
