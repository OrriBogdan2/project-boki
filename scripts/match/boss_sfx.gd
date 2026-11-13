class_name BossSfx
extends RefCounted
## The lair bosses' own sounds (content/sfx/boss.json, tools/gen_sfx_boss.py): boss_<kind>_wake,
## _phase and _defeat for each of Data.BOSSES. Lairs calls these where it used to borrow horn, warn
## and the Boki cast names.

const WAKE_DB := 3.0       # dB: a roar from the lair itself; the set's reach carries it across the lair band
const PHASE_DB := 0.0      # dB: a sting, under the ultimates and the callouts
const DEFEAT_DB := -2.0    # dB: the squad's own sting, a little under the pile's pings
const ENRAGE_PITCH := 0.8  # the phase sting pitched down for the enrage: same voice, angrier

static func cue(b: Boss, event: String) -> String:
	return "boss_%s_%s" % [b.mkind, event]

## It left dormant: a roar from the middle of the lair.
static func wake(m: Match, b: Boss) -> void:
	m.sfx(cue(b, "wake"), b.lair["c"], WAKE_DB)

## A phase change, or (enraged) the enrage.
static func phase(m: Match, b: Boss, enraged := false) -> void:
	m.sfx(cue(b, "phase"), b.pos, PHASE_DB, ENRAGE_PITCH if enraged else 1.0)

## The boss fell: the squad that cleared it hears its own sting; everyone else keeps the match-wide horn.
static func defeat(m: Match, b: Boss, killer: Hunter) -> void:
	if killer != null and m.player != null and killer.team == m.player.team:
		m.sfx(cue(b, "defeat"), null, DEFEAT_DB)
	else:
		m.sfx("horn", null, -2.0, 0.7)
