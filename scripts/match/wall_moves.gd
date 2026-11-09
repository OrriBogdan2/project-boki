class_name WallMoves
extends RefCounted
## A hunter's wall kick and wall bounce (one instance per hunter, hooked from Hunter).
## Kick (item 149, SUPERVIVE's wall dance): in the air touching or facing a wall, a jump hops you off it,
## again and again, no glider and no cooldown, with a stone scuff everyone near hears. Keys into the wall or
## none add KICK_RISE of height to the jump you are on; keys away push you off it. A hop only starts up to
## HOP_CLIMB_CAP above where you took off, so a four-terrace wall is climbable with a mantle on top and a
## five-terrace one stays sheer however long you dance. Near a wall a capped press does nothing (it never
## opens the glider: the glide button or a held glide still does). Bounce: hitting a
## wall at an angle with speed in the air (a dash, a glide, a boosted jump) rebounds you off it;
## head-on you just stop, as ever, and a jump there kicks.

const KICK_RISE := 0.8          # m of extra jump height: one terrace (World.LEVEL)
const HOP_CLIMB_CAP := 1.6      # m above the take-off ground a hop may still start (a plain jump's apex)
const FACE_REACH := 0.4         # m past the body a wall you face (not touching) still answers a hop
const FACE_RISE := 0.5          # m of ground above your feet that counts as a wall to hop on
const KICK_PRESS := 0.4         # keys this far into the wall (dot, ~66 degrees) climb it
const KICK_AWAY := 0.4          # keys this far away from the wall (dot) push off it
const KICK_KEYS_MIN := 0.3      # stick deflection that counts as pressing a direction
const KICK_PUSH := 7.5          # m/s away from the wall for a push-off
const KICK_SLIDE_KEEP := 0.6    # share of the speed along the wall a push-off keeps
const KICK_PUSH_JUMP := 0.9     # share of JUMP_V a push-off jumps with
const KICK_VOL := -5.0          # dB: the scuff
const KICK_PITCH_MIN := 0.85    # each hop's scuff a little different
const KICK_PITCH_MAX := 1.2
const BOUNCE_VOL := -6.0        # dB
const BOUNCE_PITCH := 1.5
const BOUNCE_KEEP := 0.85       # share of the speed that survives the rebound
const BOUNCE_HEAD_ON_DEG := 20.0  # closer than this to the wall's normal it doesn't bounce
const BOUNCE_MIN_INTO := 4.0    # m/s into the wall: a walking-speed jump brushing a wall doesn't ricochet
const BOUNCE_KNOCK_QUIET := 0.6  # s after a knockback in which the wall slam rules apply instead of a bounce
const BOUNCE_STEER := 25.0      # m/s^2 your keys steer the rebound for BOUNCE_WINDOW
const BOUNCE_WINDOW := 0.25     # s to steer before ordinary air control returns
const BOUNCE_DUST := 3          # dust puffs
const FX_OFFSET := 0.3          # m the spark sits in front of the wall face
const FX_HEIGHT := 0.8          # m above the feet

static var scuffs := 0          # (tests) hop scuffs played
var bounce_t := 0.0
var _rebound := Vector2.ZERO
var _rebound_speed := 0.0

## Landing ends a rebound.
func land() -> void:
	bounce_t = 0.0

## A jump pressed in the air at a wall: hops you up it or off it. True if the press is the wall's (it hopped,
## or the hop is capped), so it never falls through to opening the glider.
func try_kick(h: Hunter) -> bool:
	if h.dropping or h.remote or not _at_wall(h):
		return false
	if h.pos.y > h.last_gy + HOP_CLIMB_CAP:
		return true
	var keys: Vector2 = h.inp.get("move", Vector2.ZERO)
	var toward := keys.normalized().dot(h.wall_n) if keys.length() >= KICK_KEYS_MIN else -1.0
	if toward > KICK_AWAY:
		var push := h.wall_n * KICK_PUSH + Vector2(h.vel.x, h.vel.z).slide(h.wall_n) * KICK_SLIDE_KEEP
		h.vel = Vector3(push.x, Hunter.JUMP_V * KICK_PUSH_JUMP, push.y)
	else:
		var rise := pow(maxf(h.vel.y, 0.0), 2.0) / (2.0 * Hunter.H_GRAV) + KICK_RISE
		h.vel.y = sqrt(2.0 * Hunter.H_GRAV * rise)
	h.wall_touch_t = 0.0
	# no glider until the rise is done, so a held jump keeps the kick's height
	h.glide_cd = maxf(h.glide_cd, h.vel.y / Hunter.H_GRAV)
	h.stats["wall_kicks"] = int(h.stats.get("wall_kicks", 0)) + 1
	var pitch := randf_range(KICK_PITCH_MIN, KICK_PITCH_MAX)
	scuff(h.m, h.pos, pitch)
	h.m.net_fx(["whop", Match._r(h.pos.x), Match._r(h.pos.y), Match._r(h.pos.z), snappedf(pitch, 0.01)])
	h.m.fx.burst(_fx_at(h), Color("e6dccb"), 8, 2.5, 0.3)
	return true

## The hop's sound: a footstep on stone, at `pitch`. Played in every game (Match "fx" "whop").
static func scuff(m: Match, at: Vector3, pitch: float) -> void:
	scuffs += 1
	m.sfx("step_stone", at, KICK_VOL, pitch)

## Touching a wall (the last 0.2 s), or facing one (keys, else your aim) within FACE_REACH: sets wall_n to its normal.
func _at_wall(h: Hunter) -> bool:
	if h.wall_touch_t > 0.0 and h.wall_n.length() > 0.1:
		return true
	var keys: Vector2 = h.inp.get("move", Vector2.ZERO)
	var dir := keys.normalized() if keys.length() >= KICK_KEYS_MIN else h.aim_dir()      # (you face your aim)
	var probe := Vector2(h.pos.x, h.pos.z) + dir * (h.r + FACE_REACH)
	var w: World = h.m.world
	if not w.is_block(probe.x, probe.y) and w.ground_at(probe.x, probe.y) < h.pos.y + FACE_RISE:
		return false
	h.wall_n = -dir
	return true

## Called the step a wall stopped you in the air, with the velocity you hit it at and the wall's top.
## Reflects an angled hit about the wall's normal.
func hit(h: Hunter, hit_v: Vector2, wall_top: float) -> void:
	if h.grounded or h.remote or h.dropping or h.mantling() or h.m.time - h.kb_t < BOUNCE_KNOCK_QUIET:
		return
	var ramming := h.roll_t > 0.0 and not h.shove.is_empty()      # (a shove outlives the dash: only its run is a ram)
	if wall_top - h.pos.y <= Hunter.MANTLE_REACH or ramming or not h.charge.is_empty():
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
	h.m.sfx("land", h.pos, BOUNCE_VOL, BOUNCE_PITCH)
	h.m.fx.burst(_fx_at(h), Color("ffe9b0"), 8, 3.0, 0.25, 4.0, 0.8)
	h.m.fx.dust(h.pos, BOUNCE_DUST)

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

func _fx_at(h: Hunter) -> Vector3:
	return h.pos + Vector3(-h.wall_n.x * FX_OFFSET, FX_HEIGHT, -h.wall_n.y * FX_OFFSET)
