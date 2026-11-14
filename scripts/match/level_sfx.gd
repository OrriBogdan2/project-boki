class_name LevelSfx
extends RefCounted
## The three cues of levelling up (tools/gen_sfx_ui.py, content/sfx/ui.json), your own Hunter only; a
## rival's level and ranks make no sound. Each plays once per event, called from Hunter.gain_xp and
## Hunter.level_slot.

const LEVEL_DB := -6.0          # dB: the rise sits under combat, softer than the other UI rewards
const RANK_DB := -8.0           # dB: the per-slot confirm
const MAX_DB := -4.0            # dB: the sting when a slot reaches its top rank
const SLOT_PITCH := {"sec": 1.0, "dash": 1.122, "kin": 1.26, "ult": 1.498}   # ratio: a pentatonic step per slot

static var heard := {}          # cue -> times played (--sfx-set-check, --rank-ui-check)

## You gained a level.
static func level_up(m: Match) -> void:
	_play(m, "level_up", LEVEL_DB, 1.0)

## You spent a point on `slot`, which is now at `rank`: the slot's confirm, or the sting at its top rank.
static func rank(m: Match, slot: String, rank_now: int) -> void:
	if rank_now >= int(Hunter.SLOT_MAX[slot]):
		_play(m, "rank_max", MAX_DB, float(SLOT_PITCH[slot]))
	else:
		_play(m, "rank_up", RANK_DB, float(SLOT_PITCH[slot]))

static func _play(m: Match, cue: String, db: float, pitch: float) -> void:
	heard[cue] = int(heard.get(cue, 0)) + 1
	m.sfx(cue, null, db, pitch)
