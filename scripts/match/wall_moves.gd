class_name WallMoves
extends RefCounted
## A hunter's wall kick and wall bounce (one instance per hunter, hooked from Hunter).
## Kick: in the air, pressing into a wall, a jump kicks you up it. It adds KICK_RISE of height to the
## jump you were on, once per airtime, so a four-terrace wall is climbable with a mantle on top and
## a five-terrace one stays sheer. Bounce: hitting a wall at an angle with speed (a dash, a glide, a
## boosted jump) rebounds you off it; head-on you just stop, as ever, and a jump there kicks.

const KICK_RISE := 0.9          # m of extra jump height, about one terrace (World.LEVEL 0.8)
const KICK_PRESS := 0.4         # keys this far into the wall (dot) count as pressing in, about 66 degrees
const BOUNCE_KEEP := 0.85       # share of the speed that survives the rebound
const BOUNCE_HEAD_ON_DEG := 20.0  # closer than this to the wall's normal it doesn't bounce
const BOUNCE_MIN_INTO := 4.0    # m/s into the wall: a walking-speed jump brushing a wall doesn't ricochet
const BOUNCE_STEER := 25.0      # m/s^2 your keys steer the rebound for BOUNCE_WINDOW
const BOUNCE_WINDOW := 0.25     # s to steer before ordinary air control returns

var kicked := false             # this airtime's kick is used
var bounce_t := 0.0
var _rebound := Vector2.ZERO
var _rebound_speed := 0.0

## Landing gives the kick back.
func land() -> void:
	kicked = false
	bounce_t = 0.0

## A jump pressed in the air against a wall you are pushing into: kicks you up. True if it did.
func try_kick(h: Hunter) -> bool:
	if kicked or h.wall_touch_t <= 0.0 or h.dropping or h.remote or h.wall_n.length() < 0.1:
		return false
	var keys: Vector2 = h.inp.get("move", Vector2.ZERO)
	if keys.length() < 0.3 or keys.normalized().dot(-h.wall_n) < KICK_PRESS:
		return false
	kicked = true
	h.wall_touch_t = 0.0
	var rise := pow(maxf(h.vel.y, 0.0), 2.0) / (2.0 * Hunter.H_GRAV) + KICK_RISE
	h.vel.y = sqrt(2.0 * Hunter.H_GRAV * rise)
	h.gliding = false
	h.air_t = 0.0
	h.stats["wall_kicks"] = int(h.stats.get("wall_kicks", 0)) + 1
	h.m.sfx("jump", h.pos, -4.0, 1.4)
	h.m.fx.burst(h.pos + Vector3(h.wall_n.x * -0.3, 0.8, h.wall_n.y * -0.3), Color("e6dccb"), 8, 2.5, 0.3)
	return true

## Called the step a wall stopped you in the air or in a dash, with the velocity you hit it at and the
## wall's top. Reflects an angled hit about the wall's normal.
func hit(h: Hunter, hit_v: Vector2, wall_top: float) -> void:
	if h.remote or h.dropping or h.mantling() or h.m.time - h.kb_t < 0.6 or wall_top - h.pos.y <= Hunter.MANTLE_REACH:
		return
	var into := -hit_v.dot(h.wall_n)
	if into < BOUNCE_MIN_INTO or into > hit_v.length() * cos(deg_to_rad(BOUNCE_HEAD_ON_DEG)):
		return
	var out := (hit_v - 2.0 * hit_v.dot(h.wall_n) * h.wall_n) * BOUNCE_KEEP
	if h.roll_t > 0.0:
		h.roll_dir = out.normalized()
		h.roll_speed = out.length()
	else:
		h.vel.x = out.x
		h.vel.z = out.y
		bounce_t = BOUNCE_WINDOW
		_rebound = out
		_rebound_speed = out.length()
	h.m.sfx("land", h.pos, -6.0, 1.5)
	h.m.fx.burst(h.pos + Vector3(h.wall_n.x * -0.3, 0.8, h.wall_n.y * -0.3), Color("ffe9b0"), 8, 3.0, 0.25, 4.0, 0.8)
	h.m.fx.dust(h.pos, 3)

## While the rebound window lasts your keys steer it. Called every step after the ordinary air control.
func carry(h: Hunter, keys: Vector2, dt: float) -> void:
	if bounce_t <= 0.0:
		return
	bounce_t -= dt
	if h.grounded or h.roll_t > 0.0 or h.stun_t > 0.0 or h.knock_t > 0.0 or h.fly_t > 0.0:
		bounce_t = 0.0
		return
	_rebound = (_rebound + keys * BOUNCE_STEER * dt).limit_length(_rebound_speed)
	h.vel.x = _rebound.x
	h.vel.z = _rebound.y
