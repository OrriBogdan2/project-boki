class_name WarnSfx
extends RefCounted
## Warning sounds nobody should miss (docs/AUDIO.md): a heartbeat under low health.

const LOW_HP := 0.25          # share of max health under which the heartbeat runs
const BEAT_S := Vector2(1.1, 0.6)   # s between beats at LOW_HP and at 0 health
const BEAT_DB := -4.0         # dB: soft, it sits under the fight

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
