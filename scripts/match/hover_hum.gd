class_name HoverHum
extends RefCounted
## A floating Hunter's movement sound in place of footsteps (Motley: KMovesStone.gait < 0.5 never steps):
## its own <arch>_hover loop (HeroSfx kind "hover", content/sfx/<arch>.json) held while it moves, its level
## and pitch following its ground speed, so it fades in and out with the speed and is gone at a standstill.
## Ticked once a frame for every hunter, like GliderSfx; another player's is positional and quieter, driven
## by the synced velocity. Hunters with no hover sound play nothing here.

const QUIET_DB := -34.0         # dB, loop, as he starts to drift...
const LOUD_DB := -16.0          # dB, ...and at his full run speed
const LOW := 0.85               # pitch as he starts to drift...
const HIGH := 1.1               # ...and at his full run speed
const STILL := 0.5              # m/s of ground speed below which he is still: the hum stops
const OTHERS_DB := -6.0         # dB under yours for another player's hum

## The held loop's key for `h` (Sfx.loop_hold; it stops by itself once ticks stop holding it).
static func key(h: Hunter) -> String:
	return "hover%d" % h.get_instance_id()

## Called every frame by the hunter: holds the hum while it drifts, levelled and pitched by its speed.
static func tick(h: Hunter) -> void:
	if h.out or h.downed or h.gliding or h.crouch or h.unseen:
		return
	var sname := HeroSfx.of(h, "hover", "")
	var v := h.net_vel if h.remote else h.vel
	var spd := Vector2(v.x, v.z).length()
	if sname == "" or spd < STILL:
		return
	var k := clampf(spd / maxf(h.base_speed, 0.1), 0.0, 1.0)
	var trim := 0.0 if h.is_local() else OTHERS_DB
	Sfx.loop_hold(key(h), sname, h.pos, lerpf(QUIET_DB, LOUD_DB, k) + trim, lerpf(LOW, HIGH, k))
