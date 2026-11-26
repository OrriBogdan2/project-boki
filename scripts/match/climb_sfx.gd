class_name ClimbSfx
extends RefCounted
## The sounds of a wall kick, a ledge grab and a mantle (docs/AUDIO.md, "Climbing sounds"): a foot planted and
## pushed off a wall, a hand grabbing the lip, a body hauled over it (no voice). One sound per move and weight
## class (`<move>_<light|medium|heavy>`, content/sfx/climb.json, tools/gen_sfx_climb.py), played at the Hunter
## like a footstep: it carries StepReach.reach, and online SfxCast sends it with the Hunter's other sounds.

const KICK := "wallkick"  # a wall kick or a wall bounce
const GRAB := "ledgegrab"
const MANTLE := "mantle"  # pulled over the lip
const DB := {KICK: -5.0, GRAB: -6.0, MANTLE: -7.0}  # dB per move, before the weight class's (StepSurface)
const PITCH_VAR := 0.08  # each play a little different


## The sound `move` makes for `h`: the move's own, by h's weight class.
static func cue(h: Hunter, move: String) -> String:
	return "%s_%s" % [move, StepSurface.weight_of(h.arch)]


static func play(h: Hunter, move: String) -> void:
	var weight_db: float = StepSurface.WEIGHT_DB[StepSurface.weight_of(h.arch)]
	Sfx.play(cue(h, move), h.pos, float(DB[move]) + weight_db, PITCH_VAR, 1.0, StepReach.reach(h))
