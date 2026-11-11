class_name MobAlert
extends RefCounted
## The sound tell of a monster camp: a short alert when a camp wakes to a Hunter (idle to chase) and a
## quiet murmur from idle camps nearby, so you hear them before you see them. Both reuse the kind's own
## voice (v_<kind>) pitched and levelled differently from its attack call. Sfx.play does the distance
## falloff and the voice limits (merge gap, stack cap); this adds the per-camp rate limit.

## kind -> [alert level dB, alert pitch]: small things yip high, heavy things growl low.
const ALERT := {"skitter": [-8.0, 1.35], "spitter": [-8.0, 1.2], "brute": [-6.0, 0.7],
	"bomber": [-8.0, 0.8], "sentinel": [-6.0, 0.65], "glimmer": [-8.0, 1.3]}
const ALERT_GAP_MS := 3000      # ms: at most one alert per camp in this time
const CAMP_CELL := 6.0          # m: monsters whose camps share a cell of this size are one camp
const MURMUR_DB := -22.0        # dB: an idle camp's murmur, well under a call
const MURMUR_PITCH := 0.6       # the idle voice sits low and slow
const MURMUR_RANGE := 16.0      # m from the listener: farther camps stay silent
const MURMUR_GAP := Vector2(5.0, 9.0)    # s between one monster's murmurs

static var last := {}           # camp cell -> Time.get_ticks_msec() of its last alert

static func _cell(camp: Vector3) -> Vector2i:
	return Vector2i(floori(camp.x / CAMP_CELL), floori(camp.z / CAMP_CELL))

## The camp wakes: plays its alert unless this camp alerted in the last ALERT_GAP_MS. Returns whether it played.
static func aggro(mob: Mob) -> bool:
	if not ALERT.has(mob.mkind):
		return false
	var now := Time.get_ticks_msec()
	var cell := _cell(mob.camp)
	if now - int(last.get(cell, -ALERT_GAP_MS)) < ALERT_GAP_MS:
		return false
	last[cell] = now
	var a: Array = ALERT[mob.mkind]
	mob.m.sfx("v_" + mob.mkind, mob.pos, a[0], a[1])
	return true

## Called every tick while the monster idles awake: a quiet voice now and then while a listener is near.
static func murmur(mob: Mob, dt: float) -> bool:
	mob.murmur_t -= dt
	if mob.murmur_t > 0.0 or not ALERT.has(mob.mkind):
		return false
	mob.murmur_t = randf_range(MURMUR_GAP.x, MURMUR_GAP.y)
	if Vector2(mob.pos.x - Sfx.listener.x, mob.pos.z - Sfx.listener.z).length() > MURMUR_RANGE:
		return false
	mob.m.sfx("v_" + mob.mkind, mob.pos, MURMUR_DB, MURMUR_PITCH)
	return true
