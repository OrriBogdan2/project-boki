class_name StepReach
## Who hears a Hunter's footsteps, and how loud (docs/AUDIO.md, Footsteps). Steps are how you hear a flank:
## a rival's carry RIVAL_M with Sfx's distance roll-off, fading to nothing at the edge; a teammate's carry as
## far but MATE_DB quieter, so a rival's step stands out; your own play at one steady level wherever the
## camera is. Sneaking (crouch walking) cuts the distance to SNEAK_K of it.
## Source: the data has no footstep distance and no sneak cut, only SneakSpeedMultiplier 0.5
## (briefs/supervive-data/supervive_physics.md) and Void's "floats: no footstep noise" (supervive_kits.md),
## so both numbers here are ours ([?]).

const RIVAL_M := 20.0       # m: how far a Hunter's step carries [?] (just under Sfx.hear_range, 22 m)
const SNEAK_K := 0.4        # of RIVAL_M while crouch walking [?] (no source value)
const MATE_DB := -6.0       # dB: a teammate's step under a rival's at the same distance

## Metres h's footsteps carry for the listener.
static func reach(h: Hunter) -> float:
	return RIVAL_M * (SNEAK_K if h.crouch else 1.0)

## Whether h's steps reach the listener at all (so a far Hunter's step costs no lookup).
static func heard(h: Hunter) -> bool:
	var d := Vector2(h.pos.x - Sfx.listener.x, h.pos.z - Sfx.listener.z).length()
	return _own(h) or d <= reach(h)

## One footstep of h: yours with no distance (steady), anyone else's placed at h, out to reach(h).
## own_db / other_db: the sound's level for you and for a rival.
static func play(h: Hunter, sname: String, own_db: float, other_db: float, pitch_var := 0.08) -> void:
	Sfx.play(sname, _at(h), _level(h, own_db, other_db), pitch_var, 1.0, reach(h))

## A foot coming down (HunterAnim.stepped): the plain step under the surface one.
static func contact(h: Hunter) -> void:
	Sfx.step(_at(h), _level(h, -14.0, -20.0), reach(h))

## Where the step sounds from: nowhere for your own (no distance roll-off), else at h.
static func _at(h: Hunter) -> Variant:
	return null if _own(h) else h.pos

static func _level(h: Hunter, own_db: float, other_db: float) -> float:
	if _own(h):
		return own_db
	var p: Hunter = h.m.player if h.m != null else null
	return other_db + (MATE_DB if p != null and h.team == p.team else 0.0)

static func _own(h: Hunter) -> bool:
	return h.m != null and h == h.m.player
