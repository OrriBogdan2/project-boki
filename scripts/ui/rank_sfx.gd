class_name RankSfx
extends RefCounted
## The rank HUD's sounds (tools/gen_sfx_ui.py, content/sfx/ui.json), played only for the player whose HUD
## it is, so bots' and other players' ranks stay silent. A new rank point gets a short rising chime once,
## after the level-up chime and never again while it waits. Spending it plays a confirm pitched a step per
## slot, or a soft accent instead when it takes the slot to its top rank and opens its bonus.

const DB := {"rank_ready": -10.0, "rank_up": -8.0, "rank_max": -8.0}   # dB as played: under combat; accent <= confirm
const READY_DELAY := 0.9       # s: a new point's chime waits out the level-up chime's run (audio/level_up.wav)
const SLOT_PITCH := {"sec": 1.0, "dash": 1.125, "kin": 1.25, "ult": 1.5}   # ratio: C D E G, one note per slot

static var ready_at := -1.0    # match time the ready chime is due (RankMarks.watch sets it), -1 with none due
static var heard := {}         # cue -> [times played, pitch of the last] (--rank-ui-check, --level-hud-check)

## Each panel redraw (RankMarks.watch): the ready chime once it's due, if a point still waits for a slot
## that can take it; spent by then or nothing to rank, it stays quiet.
static func tick(p: Hunter, now: float) -> void:
	if ready_at < 0.0 or now < ready_at:
		return
	ready_at = -1.0
	if p.skill_pts > 0 and Hunter.SLOTS.any(p.can_level):
		_play("rank_ready", 1.0)

## Your own Hunter spent a point on `slot`, now at rank `lv` (Hunter.level_slot's HUD feedback).
static func spent(slot: String, lv: int) -> void:
	_play("rank_max" if lv >= int(Hunter.SLOT_MAX[slot]) else "rank_up", float(SLOT_PITCH[slot]))

static func _play(cue: String, pitch: float) -> void:
	heard[cue] = [int(heard.get(cue, [0])[0]) + 1, pitch]
	Sfx.play(cue, null, float(DB[cue]), 0.0, pitch)
