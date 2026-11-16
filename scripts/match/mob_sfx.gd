class_name MobSfx
extends RefCounted
## Monster sounds: a death cue per kind in its voice family (tools/gen_sfx_mobs.py), and the stagger pair
## for elites and bosses. All positional (Sfx falls them off with distance). A pack dying at once is
## capped across kinds: DEATH_CAP cues per DEATH_WINDOW_MS, the rest stay silent (their burst still shows).

const DEATH := {"skitter": "mdie_skitter", "spitter": "mdie_spitter", "brute": "mdie_brute", "bomber": "mdie_bomber",
	"sentinel": "mdie_sentinel", "glimmer": "mdie_glimmer", "warden": "mdie_warden"}
## Bosses speak with the Watcher's voice, pitched by body (the same pitches boss.gd uses for v_warden).
const BOSS_PITCH := {"colossus": 0.6, "serpent": 1.35, "brood": 0.9}
const DEATH_CAP := 3
const DEATH_WINDOW_MS := 200
const DEATH_DB := -5.0
const OPEN_DB := -8.0
const HIT_DB := 0.0

static var recent: Array = []     # start times (ms) of the death cues still inside the window

## The death sound for a monster kind ("" when it has none: a Shrubling keeps the generic pop).
static func death_cue(kind: String) -> String:
	return String(DEATH.get(kind.trim_prefix("bl_"), "mdie_warden" if BOSS_PITCH.has(kind) else ""))

## Whether another death cue may start at now_ms (and counts it if so).
static func admit(now_ms: int) -> bool:
	while not recent.is_empty() and now_ms - int(recent[0]) > DEATH_WINDOW_MS:
		recent.pop_front()
	if recent.size() >= DEATH_CAP:
		return false
	recent.append(now_ms)
	return true

static func death(m: Match, mb: Mob, big: bool) -> void:
	var cue := death_cue(mb.mkind)
	if cue == "":
		m.sfx("die_big" if big else "die_small", mb.pos, DEATH_DB, randf_range(0.9, 1.15))
	elif admit(Time.get_ticks_msec()):
		m.sfx(cue, mb.pos, DEATH_DB, float(BOSS_PITCH.get(mb.mkind, 1.0)) * randf_range(0.95, 1.05))

static func stagger_open(m: Match, mb: Mob) -> void:
	m.sfx("mstag_open", mb.pos, OPEN_DB, randf_range(0.95, 1.05))

static func stagger_hit(m: Match, mb: Mob) -> void:
	m.sfx("mstag_hit", mb.pos, HIT_DB)
