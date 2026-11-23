class_name RocketSfx
extends RefCounted
## One squad rocket's sounds (tools/gen_sfx_rocket.py, content/sfx/rocket.json): the ignition at launch,
## a thrust loop that swells and rises while the leader turns it, the jump-out cue, and a small clean
## thud where it comes down. Aboard you hear it close; any other rocket is positional and carries 60-70 m
## (the set's "reach"), so you hear which squad comes down near you. A solo's one-seat rocket is the same.
## The free fall after jumping out is GliderSfx's (drop_fall_wind, handing into the glider's open sound).

const ABOARD_DB := -8.0  # dB, the thrust loop for the squad riding it
const OTHERS_DB := -6.0  # dB under that for a rocket you're not on (and its ignition and thud)
const TURN_DB := 4.0  # dB the thrust swells by while the leader turns it hard
const PITCH_DIVE := 0.85  # thrust pitch diving straight down...
const PITCH_FLAT := 1.1  # ...and at the rocket's full flat speed
const TURN_PITCH := 0.15  # extra pitch while it turns hard
const TURN_EASE := 5.0  # 1/s: how fast the swell follows the keys
const LAND_ABOVE_M := 4.0  # m: a copy following another machine's leader that ends this low has landed

var key := ""
var turn := 0.0  # 0..1, how hard the leader is turning it (from the change in its flat velocity)
var _hv := Vector2.ZERO


## The launch: the ignition, and the thrust loop starts on the next tick.
func start(r: DropRocket) -> void:
	key = "rocket%d" % r.get_instance_id()
	_hv = Vector2(r.vel.x, r.vel.z)
	_cue(r, "rocket_ignite", r.pos, 0.0)


## Every step while it flies: the thrust follows the steering (the same on every machine, from its velocity).
func tick(r: DropRocket, dt: float) -> void:
	var hv := Vector2(r.vel.x, r.vel.z)
	var want := clampf((hv - _hv).length() / maxf(dt, 0.001) / DropRocket.ACCEL, 0.0, 1.0)
	_hv = hv
	turn = move_toward(turn, want, TURN_EASE * dt)
	var k := clampf(hv.length() / DropRocket.SPEED, 0.0, 1.0)
	var on := _aboard(r)
	var vol := ABOARD_DB + TURN_DB * turn + (0.0 if on else OTHERS_DB)
	var pitch := lerpf(PITCH_DIVE, PITCH_FLAT, k) + TURN_PITCH * turn
	Sfx.loop_hold(key, "rocket_ride", null if on else r.pos, vol, pitch)


## Someone jumps out (yours close, anyone else's where they are).
func jump_out(r: DropRocket, h: Hunter) -> void:
	if h == r.m.player:
		Sfx.play("rocket_jump", null, -2.0)
	else:
		Sfx.play("rocket_jump", h.pos, OTHERS_DB)


## It hits the ground at `at`.
func land(r: DropRocket, at: Vector3) -> void:
	Sfx.loop_stop(key)
	_cue(r, "rocket_land", at, -2.0)


## A copy following another machine's leader ends when its riders are off: a thud if that was on the ground.
func ended(r: DropRocket) -> void:
	var w: World = r.m.world
	if w.is_void(r.pos.x, r.pos.z) or r.pos.y - w.ground_at(r.pos.x, r.pos.z) > LAND_ABOVE_M:
		Sfx.loop_stop(key)
		return
	land(r, Vector3(r.pos.x, w.ground_at(r.pos.x, r.pos.z), r.pos.z))


func _aboard(r: DropRocket) -> bool:
	return r.m.player != null and r.riders.has(r.m.player)


func _cue(r: DropRocket, sname: String, at: Vector3, vol_db: float) -> void:
	if _aboard(r):
		Sfx.play(sname, null, vol_db)
	else:
		Sfx.play(sname, at, vol_db + OTHERS_DB)
