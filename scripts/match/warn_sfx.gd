class_name WarnSfx
extends RefCounted
## Warning sounds nobody should miss (docs/AUDIO.md): a heartbeat under low health and the extraction countdown tick.

const LOW_HP := 0.25          # share of max health under which the heartbeat runs
const BEAT_S := Vector2(1.1, 0.6)   # s between beats at LOW_HP and at 0 health
const BEAT_DB := -4.0         # dB: soft, it sits under the fight
const COUNT_S := 5            # s: the countdown ticks once a second for this long before an extraction closes
const TICK_PITCH := Vector2(1.0, 1.4)   # first and last tick of the countdown

static var beat_in := 0.0     # s until the next beat (the local hunter's only)

## The local hunter's heartbeat: faster the lower the health; it stops as soon as they are healed, downed or out.
static func low_hp(h: Hunter, dt: float) -> void:
	if h.downed or h.dead or h.out or h.extracted or h.hp <= 0.0 or h.hp >= h.max_hp * LOW_HP:
		beat_in = 0.0
		return
	beat_in -= dt
	if beat_in > 0.0:
		return
	beat_in = lerpf(BEAT_S.y, BEAT_S.x, h.hp / (h.max_hp * LOW_HP))
	Sfx.play("warn_heartbeat", null, BEAT_DB)

## One tick a second, rising in pitch, for the last COUNT_S seconds of an exit's timer `t`
## (x["count"] remembers the last second ticked).
static func countdown(m: Match, x: Dictionary, at: Vector3, t: float) -> void:
	var sec := ceili(t)
	if sec > COUNT_S or sec < 1 or sec == int(x.get("count", 0)):
		return
	x["count"] = sec
	m.sfx("warn_tick", at, -2.0, lerpf(TICK_PITCH.y, TICK_PITCH.x, float(sec - 1) / float(COUNT_S - 1)))
