class_name WallMoves
extends RefCounted
## A hunter's wall kick and wall bounce (one instance per hunter, hooked from Hunter).
## Kick (item 149, SUPERVIVE's wall dance): in the air touching or facing a wall, a jump hops you off it,
## again and again, no glider and no cooldown, with a stone scuff everyone near hears. Keys into the wall or
## none add wall_kick_rise of height to the jump you are on; keys away push you off it. A hop only starts up to
## wall_hop_climb_cap above where you took off, so a four-terrace wall is climbable with a mantle on top and a
## five-terrace one stays sheer however long you dance. Near a wall a capped press does nothing (it never
## opens the glider: the glide button still does). Bounce: hitting a
## wall at an angle with speed in the air (a dash, a glide, a boosted jump) rebounds you off it;
## head-on you just stop, as ever, and a jump there kicks.
## Its numbers are content/rules/tuning.json "feel" (HunterFeel).

const KICK_VOL := -5.0          # dB: the scuff
const KICK_PITCH_MIN := 0.85    # each hop's scuff a little different
const KICK_PITCH_MAX := 1.2
const BOUNCE_VOL := -6.0        # dB
const BOUNCE_PITCH := 1.5
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
	if h.pos.y > h.last_gy + HunterFeel.wall_hop_climb_cap:
		return true
	var keys: Vector2 = h.inp.get("move", Vector2.ZERO)
	var toward := keys.normalized().dot(h.wall_n) if keys.length() >= HunterFeel.wall_kick_keys_min else -1.0
	if toward > HunterFeel.wall_kick_away:
		var slide := Vector2(h.vel.x, h.vel.z).slide(h.wall_n) * HunterFeel.wall_kick_slide_keep
		var push := h.wall_n * HunterFeel.wall_kick_push + slide
		h.vel = Vector3(push.x, Loco.jump_v * HunterFeel.wall_kick_push_jump, push.y)
	else:
		var rise := pow(maxf(h.vel.y, 0.0), 2.0) / (2.0 * Loco.gravity) + HunterFeel.wall_kick_rise
		h.vel.y = sqrt(2.0 * Loco.gravity * rise)
	h.wall_touch_t = 0.0
	# no glider until the rise is done, so a held jump keeps the kick's height
	h.glide_cd = maxf(h.glide_cd, h.vel.y / Loco.gravity)
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

## Touching a wall (the last 0.2 s), or facing one (keys, else your aim) within wall_face_reach:
## sets wall_n to its normal.
func _at_wall(h: Hunter) -> bool:
	if h.wall_touch_t > 0.0 and h.wall_n.length() > 0.1:
		return true
	var keys: Vector2 = h.inp.get("move", Vector2.ZERO)
	var pressed := keys.length() >= HunterFeel.wall_kick_keys_min
	var dir := keys.normalized() if pressed else h.aim_dir()      # (you face your aim)
	var probe := Vector2(h.pos.x, h.pos.z) + dir * (h.r + HunterFeel.wall_face_reach)
	var w: World = h.m.world
	if not w.is_block(probe.x, probe.y) and w.ground_at(probe.x, probe.y) < h.pos.y + HunterFeel.wall_face_rise:
		return false
	h.wall_n = -dir
	return true

## Called the step a wall stopped you in the air, with the velocity you hit it at and the wall's top.
## Reflects an angled hit about the wall's normal.
func hit(h: Hunter, hit_v: Vector2, wall_top: float) -> void:
	if h.grounded or h.remote or h.dropping or h.mantling() or h.m.time - h.kb_t < HunterFeel.wall_bounce_knock_quiet:
		return
	var ramming := h.roll_t > 0.0 and not h.shove.is_empty()      # (a shove outlives the dash: only its run is a ram)
	if wall_top - h.pos.y <= HunterFeel.mantle_reach or ramming or not h.charge.is_empty():
		return
	var into := -hit_v.dot(h.wall_n)
	var head_on := hit_v.length() * cos(deg_to_rad(HunterFeel.wall_bounce_head_on_deg))
	if into < HunterFeel.wall_bounce_min_into or into > head_on:
		return
	var out := (hit_v - 2.0 * hit_v.dot(h.wall_n) * h.wall_n) * HunterFeel.wall_bounce_keep
	if h.roll_t > 0.0:
		h.roll_dir = out.normalized()
		h.roll_speed = out.length()
	else:
		h.vel.x = out.x
		h.vel.z = out.y
		bounce_t = HunterFeel.wall_bounce_window
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
	_rebound = (_rebound + keys * HunterFeel.wall_bounce_steer * dt).limit_length(_rebound_speed)
	h.vel.x = _rebound.x
	h.vel.z = _rebound.y

func _fx_at(h: Hunter) -> Vector3:
	return h.pos + Vector3(-h.wall_n.x * FX_OFFSET, FX_HEIGHT, -h.wall_n.y * FX_OFFSET)
