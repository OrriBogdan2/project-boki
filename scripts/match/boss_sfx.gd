class_name BossSfx
extends RefCounted
## The lair bosses' own sounds (content/sfx/boss.json, tools/gen_sfx_boss.py): boss_<kind>_wake, _phase and
## _defeat for each of Data.BOSSES, and per attack a wind-up cue (_<attack>_wind, played when the wind-up starts and
## pitched so it peaks on the clip's wind-up key, BossAnim.hit_t) and a strike cue (_<attack>_hit) on the blow;
## plus _stagger and _fall. Lairs and Boss call these where they used to borrow horn, warn, zap and the Boki cast names.

const WAKE_DB := 3.0       # dB: a roar from the lair itself; the set's reach carries it across the lair band
const PHASE_DB := 0.0      # dB: a sting, under the ultimates and the callouts
const DEFEAT_DB := -2.0    # dB: the squad's own sting, a little under the pile's pings
const WIND_DB := 2.0       # dB: a wind-up is heard coming, over the fight
const HIT_DB := 4.0        # dB: the blow, the loudest thing in the lair
const STAGGER_DB := 2.0    # dB: the groan when it opens
const FALL_DB := 3.0       # dB: the body hitting the ground
const WIND_TAIL_S := 0.24  # s: the room tail every cue carries past its last swell (sfx_lib.reflections)
const PITCH_MIN := 0.7     # the wind-up's pitch stays in this range, so enraged and phase-shortened wind-ups still read
const PITCH_MAX := 1.6
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

## The attack's wind-up starts (call it right after _begin): the cue's last swell lands on the wind-up key.
static func wind(m: Match, b: Boss, attack: String) -> void:
	var wind_cue := cue(b, attack + "_wind")
	if not Sfx.ensure(wind_cue):
		return
	var swell_s: float = (Sfx.streams[wind_cue] as AudioStream).get_length() - WIND_TAIL_S
	m.sfx(wind_cue, b.pos, WIND_DB, clampf(swell_s / BossAnim.hit_t(b), PITCH_MIN, PITCH_MAX))

## The blow of `attack` lands (or a shot leaves the boss) at `at`.
static func hit(m: Match, b: Boss, attack: String, at: Vector3) -> void:
	m.sfx(cue(b, attack + "_hit"), at, HIT_DB)

## A thrown boulder or glob comes down at `at`.
static func land(m: Match, b: Boss, attack: String, at: Vector3) -> void:
	m.sfx(cue(b, attack + "_land"), at, HIT_DB)

## A stagger opens: the boss groans.
static func stagger(m: Match, b: Boss) -> void:
	m.sfx(cue(b, "stagger"), b.pos, STAGGER_DB)

## The boss's body hits the ground, for everyone in earshot (the defeat sting is only the squad's).
static func fall(m: Match, b: Boss) -> void:
	m.sfx(cue(b, "fall"), b.pos, FALL_DB)
