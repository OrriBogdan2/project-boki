class_name RankChoice
extends RefCounted
## Two one-time lines that teach the rank choice (a level-up point goes into the ability you pick,
## and maxing one unlocks its last rank): the first level-up on a profile names the live keys and
## pulses the rankable slots, the first max rank names the bonus it unlocked. Each is a seen-once
## flag in Save.d["tutorial"]. Bots, the tutorial course (it has its own rank step) and practice
## never get them.

const PULSE_SECS := 8.0        # s: the stronger pulse on the rankable slots after the first level-up
const FLAG_LEVEL := "rank_choice_seen"
const FLAG_MAX := "rank_max_seen"
const SLOT_ACTION := {"sec": "secondary", "dash": "dash", "kin": "signature", "ult": "ultimate"}

static var _pulse_until := 0.0
static var _pulse_pts := 0
static var _pulse_match := 0     # instance id of the match that started the pulse (m.time restarts per match)

## The first level-up: one banner line with the live keys, and the pulse starts.
static func on_level_up(m: Match, p: Hunter) -> void:
	if not _eligible(m, FLAG_LEVEL):
		return
	var caps: Array = []
	for slot: String in Hunter.SLOTS:
		if p.can_level(slot):
			caps.append(Settings.key_cap(SLOT_ACTION[slot]))
	var line := "Level up! Press Alt + %s on an ability to rank it" % "/".join(caps)
	m.hud.msgs.push(line, HudStyle.GOLD, MsgLane.HIGH, 6.0)
	_pulse_until = m.time + PULSE_SECS
	_pulse_pts = p.skill_pts
	_pulse_match = m.get_instance_id()
	_mark(FLAG_LEVEL)

## A point went into `slot`: the first time a slot reaches its top rank, one line names what that unlocked.
static func on_rank(m: Match, p: Hunter, slot: String) -> void:
	if int(p.slot_lv[slot]) < int(Hunter.SLOT_MAX[slot]) or not _eligible(m, FLAG_MAX):
		return
	var ranks := Arch.next_ranks(p.arch, slot, int(Hunter.SLOT_MAX[slot]) - 1)
	if ranks.is_empty():
		return
	m.hud.msgs.push("Max rank! Unlocked: " + String(ranks.back()[1]), HudStyle.GOLD, MsgLane.HIGH, 6.0)
	_mark(FLAG_MAX)

## True while the strong pulse should show: inside its window and the point still unspent.
static func pulsing(m: Match, p: Hunter) -> bool:
	return m.get_instance_id() == _pulse_match and m.time < _pulse_until and p.skill_pts >= _pulse_pts

static func _eligible(m: Match, flag: String) -> bool:
	return m.hud != null and m.tut == null and m.arena == null and not Save.d["tutorial"].get(flag, false)

static func _mark(flag: String) -> void:
	Save.d["tutorial"][flag] = true
	Save.save_game()
