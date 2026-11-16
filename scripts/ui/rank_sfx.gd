class_name RankSfx
extends RefCounted
## The rank HUD's ready chime (tools/gen_sfx_ui.py, content/sfx/ui.json), played only for the player whose HUD
## it is, so bots' and other players' ranks stay silent. A new rank point gets a short rising chime once,
## after the level-up chime and never again while it waits. Spending it is LevelSfx.rank's confirm or sting.

const DB := {"rank_ready": -10.0}   # dB as played: under combat
const READY_DELAY := 0.9       # s: a new point's chime waits out the level-up chime's run (audio/level_up.wav)

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

static func _play(cue: String, pitch: float) -> void:
	heard[cue] = [int(heard.get(cue, [0])[0]) + 1, pitch]
	Sfx.play(cue, null, float(DB[cue]), 0.0, pitch)
