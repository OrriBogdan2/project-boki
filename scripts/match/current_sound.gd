class_name CurrentSound
extends RefCounted
## The sound of currents (wind roads and updrafts): you hear one before you see it, and riding it sounds
## different from gliding in still air. Each current within BED_M of the listener has a positional looping
## bed (one player, culled beyond BED_M; a wind road is heard from its nearest point). While the local
## Hunter rides a current a second layer plays, rising in pitch with speed. Sounds: tools/gen_sfx_wind.py.

const BED_M := 25.0              # m: a bed starts inside this and carries no further
const BED_KEEP_M := 28.0         # m: ... and is dropped beyond this, so one at the edge doesn't flutter
const BED_DB := -5.0             # dB at the source: a soft bed under the glide and combat sounds
const RIDE_DB := -9.0            # dB: the riding layer is yours alone, so it sits under the beds near you
const RIDE_PITCH_STILL := 0.8    # pitch at rest
const RIDE_PITCH_PER_MS := 0.04  # pitch gained per m/s of speed
const RIDE_PITCH_MAX := 1.6
const RIDE_KEY := "cur_ride"

## Starts, moves and drops the beds, and keeps the riding layer going while the player is in a current.
static func tick(m: Match) -> void:
	var from := Sfx.listener
	for i in m.world.winds.size():
		var wd: Dictionary = m.world.winds[i]
		_bed("cur_w%d" % i, _nearest(wd["a"], wd["b"], from), from)
	for i in m.world.updrafts.size():
		_bed("cur_u%d" % i, m.world.updrafts[i]["pos"], from)
	var p: Hunter = m.player
	if p != null and riding(p):
		Sfx.loop_hold(RIDE_KEY, "current_ride", null, RIDE_DB, ride_pitch(p.vel.length()))

## True while a Hunter is gliding in a current (in_current is only cleared inside the glide, so it
## alone goes stale once the glider is shut).
static func riding(h: Hunter) -> bool:
	return h.gliding and not h.dropping and h.in_current

static func ride_pitch(speed: float) -> float:
	return minf(RIDE_PITCH_STILL + RIDE_PITCH_PER_MS * speed, RIDE_PITCH_MAX)

static func bed_keys(m: Match) -> Array:
	var keys: Array = []
	for i in m.world.winds.size():
		keys.append("cur_w%d" % i)
	for i in m.world.updrafts.size():
		keys.append("cur_u%d" % i)
	return keys

## The point of the road a-b nearest to p (flat distance, like the rest of Sfx's falloff).
static func _nearest(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var t := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
	return a.lerp(b, t)

static func _bed(key: String, at: Vector3, from: Vector3) -> void:
	var d := Vector2(at.x - from.x, at.z - from.z).length()
	if d <= BED_M:
		Sfx.loop_start(key, "current_bed", at, BED_DB, BED_M)     # (already playing: ignored)
		Sfx.loop_set(key, at)
	elif Sfx.loop_on(key):
		if d > BED_KEEP_M:
			Sfx.loop_stop(key)
		else:
			Sfx.loop_set(key, at)
