class_name HunterMove
extends RefCounted
## Per-hunter run speed, ground acceleration and tall-ledge climbing, plus the ground stop, dash exit,
## fall, glide, dive and mantle tunables every hunter shares, from content/rules/hunter_move.json
## ([game data]: SUPERVIVE's movement settings, uu converted to metres).

static var _rules: Dictionary = _load()
static var _phys: Dictionary = _rules["physics"]
static var brake_decel: float = _phys["brake"]
## 1/s: GroundFriction x BrakingFrictionFactor, the share of the speed the walking brake sheds per second
static var brake_friction: float = _phys["ground_friction"] * _phys["braking_friction_factor"]
static var braking_substep: float = _phys["braking_substep"]      # s, the longest sub-step of a brake
## 1/s, GroundFriction: bends a walk with keys held toward the keys (HunterMove.walk)
static var turn_friction: float = _phys["ground_friction"]
static var brake_stop_speed: float = _phys["brake_stop_speed"]    # m/s, a brake leaving less stops dead
static var min_tick: float = _phys["min_tick"]                    # s, the shortest sub-step braked
static var dash_exit_run: float = _phys["dash_exit_run"]
static var fall_max: float = _phys["fall_cap"]
static var abyss_fall_max: float = _phys["abyss_fall_cap"]
static var abyss_slow_from: float = _phys["abyss_slow_from"]
static var abyss_slow_to: float = _phys["abyss_slow_to"]
static var glide_height: float = _phys["glide_height"]
static var glide_pull_vy: float = _phys["glide_pull_vy"]
static var glide_accel: float = _phys["glide_accel"]
static var glide_start_vy: float = _phys["glide_start_vy"]
static var turn_rate: float = deg_to_rad(_phys["turn_rate"])      # rad/s, the body turning to the cursor
static var mantle_vy_cap: float = _phys["mantle_vy_cap"]
static var mantle_pull: float = _phys["mantle_pull"]
static var mantle_launch_keep: float = _phys["mantle_launch_keep"]
static var mantle_launch_min: float = _phys["mantle_launch_min"]
static var dive_vy: float = _phys["dive_vy"]
static var dive_accel: float = _phys["dive_accel"]
static var dive_steer: float = _phys["dive_steer"]
static var dive_cancel_h: float = _phys["dive_cancel_h"]
static var dive_timeout: float = _phys["dive_timeout"]
static var coyote_s: float = _phys["coyote_s"]
static var jump_buffer_s: float = _phys["jump_buffer_s"]
static var sneak_speed: float = _phys["sneak_speed"]
static var floor_snap: float = _phys["floor_snap"]
static var walkable_tan: float = tan(deg_to_rad(float(_phys["walkable_angle"])))
static var speed_cap: float = _phys["speed_cap"]
static var haste: float = _phys["haste"]
static var step_height: float = _phys["step_height"]      # m: a lip this high is walked over
static var pad_vy: float = _phys["pad_vy"]
static var pad_clear: float = _phys["pad_clear"]
static var updraft_vy: float = _phys["updraft_vy"]
const CHASE_BONUS := 0.18      # share of run speed: heading at whoever took your kin

static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/hunter_move.json"))
	assert(parsed is Dictionary, "content/rules/hunter_move.json did not parse")
	return parsed

static func rules() -> Dictionary:
	return _rules

## This archetype's movement row (the default row for none or an unknown id).
static func of(arch: String) -> Dictionary:
	return _rules.get(arch, _rules["default"])

## Sets the hunter's run speed and acceleration for its archetype.
static func apply(h: Hunter) -> void:
	var row := of(h.arch)
	h.base_speed = float(row["speed"])
	h.ground_accel = float(row["accel"])

## The one rule for ground speed: the move-speed bonuses (shares of run speed) add, the slows and
## states multiply that total, and nothing passes speed_cap ([game data] MaxMoveSpeed 700 uu/s).
static func ground_speed(run: float, bonus: float, mult: float) -> float:
	return clampf(run * maxf(0.0, 1.0 + bonus) * mult, 0.0, speed_cap)

## Every move-speed bonus a hunter has right now, summed: gear, perk orbs, kin carry passives, owner
## points, merge and kin-ability buffs (gear_stat), the haste status, its kit's own bursts, its mount's
## gait and the chase after a kin thief.
static func speed_bonus(h: Hunter, mv: Vector2) -> float:
	var b := h.gear_stat("speed") + (haste if h.haste_t > 0.0 else 0.0)
	if h.ak: b += h.ak.speed_bonus()
	if h.mounted() and h.grounded: b += h.mount_speed() - 1.0
	var c := h.chase
	if c and not c.out and not c.extracted and mv.length() > 0.1 and mv.normalized().dot(h.dir_to(c)) > 0.5:
		b += CHASE_BONUS
	return b

## True when this hunter can mantle a double-high ledge (Archer and Juggernaut).
static func climbs_tall(h: Hunter) -> bool:
	return bool(of(h.arch).get("climb_tall", false))

## The source's walking brake at `speed` (m/s^2): brake_friction's share of the speed plus brake_decel. UE
## sheds any speed over the run this way, keys held or not, so a knock or a kit step slides out the same.
static func brake_rate(speed: float) -> float:
	return brake_friction * speed + brake_decel

## Ground velocity after a step with keys held: UE's walking CalcVelocity. Up to the wanted speed (with UE's 1%
## IsExceedingMaxSpeed slack) GroundFriction bends the velocity toward the keys at its own speed, the accel adds
## on and the speed caps at the wanted speed: a reversal sheds 2 x turn_friction x speed + accel, a 90-degree
## cut arcs round at run speed. Over it (a Slow landing, a knock, a pad's carry) the walking brake sheds it.
static func walk(hv: Vector2, wish: Vector2, accel: float, grip: float, dt: float) -> Vector2:
	var run := wish.length()
	var s := hv.length()
	if s > run * 1.01:
		return Loco.accel_to(hv, wish, accel, 0.0, brake_rate(s) * grip, dt)
	var dir := wish / run
	var bent := hv - (hv - dir * s) * minf(turn_friction * grip * dt, 1.0)
	return (bent + dir * accel * dt).limit_length(run)

## Ground speed after a step with no keys: UE's walking brake (ApplyVelocityBraking) exactly, so a let-go from a
## run slides 0.31-0.37 m and a knock or kit step slides out under the same rule. A step longer than
## braking_substep brakes in sub-steps (each at most that, and at most half of what is left); the brake never
## turns the speed around, and under brake_stop_speed it stops. grip < 1 on ice.
static func brake(hv: Vector2, grip: float, dt: float) -> Vector2:
	var k := brake_friction * grip
	var rev := hv.normalized() * brake_decel * grip
	var v := hv
	var left := dt
	while left >= min_tick:
		var sub := minf(braking_substep, left * 0.5) if left > braking_substep else left
		left -= sub
		v += (-k * v - rev) * sub
		if v.dot(hv) <= 0.0:
			return Vector2.ZERO
	return Vector2.ZERO if v.length() <= brake_stop_speed else v

## [game data] A grounded hunter (walking or dashing) keeps to the floor where the ground under it drops
## less than floor_snap this step, or less than a walkable slope falls over the `travel` metres it moved
## (a ramp, stairs, the lip it was lifted onto), easing the model down. A bigger drop, and always a whole
## tier, is a ledge: it leaves the ground. Nothing pulls down a body that is rising.
static func follows_floor(h: Hunter, g: float, travel: float) -> bool:
	var reach := minf(maxf(floor_snap, travel * walkable_tan), World.LEVEL - 0.05)
	if h.vel.y > 0.0 or h.pos.y - g > reach:
		return false
	h.step_vis += h.pos.y - g
	return true

## Velocity a dash leaves you with: no hard stop, it hands over at dash_exit_run of run speed (never
## faster than the dash), and the walk, brake or air carry takes it from there.
static func dash_exit(dash_v: Vector2, run: float) -> Vector2:
	return dash_v.limit_length(run * dash_exit_run)

## A knock (one that sets knock_t) or a stun landing on an air Shift dash after its i-frames ends the dash on the
## spot, as a glide press does: the knock's push or the stun's stop takes over (source: a stun is "no movement",
## a knockback pushes you). A kit's rush, and a dash on the ground, ride on (MOVEMENT_FEEL "Knocked in the air").
static func cut_air_dash(h: Hunter) -> void:
	if h.roll_t <= 0.0 or h.grounded or h.move_kind != "dash":
		return
	h.roll_t = 0.0
	h.shove = {}

## The step a ground dash ends in runs the dash for the `left` seconds it still had, then the hand-over: the
## metres to add to that step's travel at `run_v`, so the dash covers its whole distance at any tick rate. (An
## air dash needs none: it carries its own speed through the step, under air drag after.)
static func dash_rest(dash_v: Vector2, run_v: Vector2, left: float) -> Vector2:
	return (dash_v - run_v) * maxf(0.0, left)

## A ground dash that runs off a ledge keeps its own course (distance, speed curve) but falls as it goes: the
## height hold is an air dash's (Hunter.roll_falls, set as the ground goes). It ends in the air with the usual dash
## exit, so the glider and the air dash are free as it ends, and the kit's ground pose for it is cut there.
## Source: a dash is how you leave a platform (bCanWalkOffLedges false) and a falling body only sheds
## FallingLateralFriction; DECISIONS: walking off ledges is always allowed. Called every step.
static func dash_off_ledge(h: Hunter) -> void:
	if not h.roll_falls or h.roll_t > 0.0:
		return
	h.roll_falls = false
	if h.ak and not h.grounded:
		h.ak.on_dash_off_ledge()

## A dash's speed at u (0..1 through it) against its mean, on a piecewise-linear curve of [u, k] knots
## (content/rules/dash_feel.json "curve": mean 1, so the dash still covers its distance).
static func dash_k(curve: Array, u: float) -> float:
	for i in curve.size() - 1:
		var a: Array = curve[i]
		var b: Array = curve[i + 1]
		if u <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (u - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])))
	return float(curve[-1][1])

## Metres speed v0 slides on flat ground under brake_rate before it falls to `to_speed` m/s (0: a let-go; the run
## speed: keys held). A kit step with a measured total takes this off its dash so the slide doesn't add to it.
static func slide(v0: float, to_speed := 0.0) -> float:
	var k := brake_friction
	return (v0 - to_speed) / k - brake_decel / (k * k) * log((k * v0 + brake_decel) / (k * to_speed + brake_decel))

## The speed that slides `dist` metres before it falls to `to_speed` (the inverse of slide; a lunge's push).
static func slide_speed(dist: float, to_speed := 0.0) -> float:
	var lo := to_speed
	var hi := to_speed + 60.0
	for i in 24:
		var mid := (lo + hi) * 0.5
		if slide(mid, to_speed) < dist:
			lo = mid
		else:
			hi = mid
	return hi

## The fastest this hunter falls (m/s): fall_max, easing to abyss_fall_max as it sinks from
## abyss_slow_from to abyss_slow_to metres under an island's lip over the abyss (time to recover). A kit's
## plunge (ArchKit.dive_speed, like Breah's air Quakefall) outruns it.
static func fall_cap(h: Hunter) -> float:
	if h.ak and h.ak.dive_speed() > 0.0:
		return h.ak.dive_speed()
	if not h.below_lip:
		return fall_max
	var k := clampf((h.lip_y - h.pos.y - abyss_slow_from) / (abyss_slow_to - abyss_slow_from), 0.0, 1.0)
	return lerpf(fall_max, abyss_fall_max, k)

## Vertical speed after one step up a ledge's face, `left` metres under its lip. Within Hunter.MANTLE_REACH it's the
## source's suction: gravity as in any jump, plus mantle_pull while you rise slower than mantle_vy_cap, so a
## jump's momentum carries you over and a slow arrival is lifted at the cap. Deeper (the abyss catch, ours) you
## rise as if thrown to clear the lip at the cap, never faster than `deep_max`. `k` scales the rise (downed).
static func rise_vy(vy: float, left: float, k: float, deep_max: float, dt: float) -> float:
	var cap := mantle_vy_cap * k
	if left > Hunter.MANTLE_REACH:
		return minf(sqrt(cap * cap + 2.0 * Hunter.H_GRAV * left), deep_max * k)
	vy -= Hunter.H_GRAV * dt
	if vy < cap:
		vy = minf(vy + mantle_pull * dt, cap)
	return vy

## The longest a rise from `depth` metres under a lip takes under rise_vy (s): thrown up to the suction band,
## then the band at the cap from a standstill.
static func rise_time(depth: float) -> float:
	var band := minf(depth, Hunter.MANTLE_REACH)
	var c2 := mantle_vy_cap * mantle_vy_cap
	var deep := (sqrt(c2 + 2.0 * Hunter.H_GRAV * depth) - sqrt(c2 + 2.0 * Hunter.H_GRAV * band)) / Hunter.H_GRAV
	return deep + band / mantle_vy_cap

## Speed onto a ledge you climb (m/s), from a hunter's run speed.
static func mantle_launch(run_speed: float) -> float:
	return maxf(run_speed * mantle_launch_keep, mantle_launch_min)

## "About to land": falling, with the ground no further than the jump buffer (and a step more) of falling away,
## and never further than 0.9 m. A jump pressed then waits for the landing instead of opening the glider.
## `height` is metres above the ground.
static func near_landing(vy: float, height: float) -> bool:
	var lead := jump_buffer_s + 0.02
	return vy < 0.0 and height < maxf(0.9, (0.5 * Hunter.H_GRAV * lead - vy) * lead)

## Where a body wanting to be at p ends up once it's pushed straight out of every barrier that blocks
## it (a Tenzo rock, a raised wall; Verbs.wall_blocks), as World.push_out_blocks does for rock tiles:
## you slide along the face and round the end instead of stopping. x, y: the spot; z: the highest top
## it was pushed off (0 for none), for the wall kick and the caster's climb (StoneStand).
static func push_out_walls(h: Hunter, p: Vector2) -> Vector3:
	var top := 0.0
	for w in h.m.world.dyn_walls:
		var wt := Verbs.wall_top(w, h.pos.y)
		if wt <= 0.0:
			continue
		var reach := Verbs.wall_reach(w, h.r)
		var c := Geometry2D.get_closest_point_to_segment(p, w["a"], w["b"])
		var d := p - c
		if d.length_squared() >= reach * reach:
			continue
		if d.length_squared() < 1e-8:
			d = Vector2(h.pos.x, h.pos.z) - c      # (dead on its line: back out the side you came from)
		# out to a skin past the reach: a body sliding along the face then stays clear of it, where a float's
		# rounding would otherwise push it a hair with a random normal and eat its speed
		p = c + d.normalized() * (reach + World.BLOCK_SKIN)
		top = maxf(top, wt)
	return Vector3(p.x, p.y, top)

## The keys' velocity against the wall the last step's walk pressed into (n: out of it, zero for
## none): its part into the wall is dropped, so the whole run-up goes along the face and you slide at
## the tangent part of your speed from the first step (a dash's hand-over into the run included).
static func along_wall(wish: Vector2, n: Vector2) -> Vector2:
	var into := wish.dot(n)
	return wish - n * into if into < 0.0 else wish

## Whether a step the walls stopped (b1, b2: World.occupy's answer for the x and z moves) is caught on a
## corner and needs the sideways slip. A dash step along a face, its one axis free, is not: it slides at
## the tangent part of its speed as the source's dashes do (decision 0047), and the slip would add to it.
static func caught(dashing: bool, b1: float, b2: float) -> bool:
	if dashing:
		return b1 > 0.0 and b2 > 0.0
	return b1 > 0.0 or b2 > 0.0
