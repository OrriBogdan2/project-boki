class_name HunterMove
extends RefCounted
## Per-hunter run speed, ground acceleration and tall-ledge climbing, plus the ground stop, dash exit, air,
## fall, glide, dive and mantle tunables every hunter shares, from content/rules/hunter_move.json
## ([game data]: SUPERVIVE's movement settings, uu converted to metres).

static var _rules: Dictionary = _load()
static var _phys: Dictionary = _rules["physics"]
static var brake_decel: float = _phys["brake"]
static var ground_friction: float = _phys["ground_friction"]
static var dash_exit_run: float = _phys["dash_exit_run"]
static var air_control: float = _phys["air_control"]
static var air_friction: float = _phys["air_friction"]
static var air_brake: float = _phys["air_brake"]
static var fall_max: float = _phys["fall_cap"]
static var abyss_fall_max: float = _phys["abyss_fall_cap"]
static var abyss_slow_from: float = _phys["abyss_slow_from"]
static var abyss_slow_to: float = _phys["abyss_slow_to"]
static var glide_height: float = _phys["glide_height"]
static var glide_pull_vy: float = _phys["glide_pull_vy"]
static var swoop_ratio: float = _phys["swoop_ratio"]
static var swoop_fade: float = _phys["swoop_fade"]
static var mantle_launch_keep: float = _phys["mantle_launch_keep"]
static var mantle_launch_min: float = _phys["mantle_launch_min"]
static var dive_vy: float = _phys["dive_vy"]
static var dive_accel: float = _phys["dive_accel"]
static var dive_steer: float = _phys["dive_steer"]
static var dive_cancel_h: float = _phys["dive_cancel_h"]
static var dive_timeout: float = _phys["dive_timeout"]

const OVER_RUN := 1.01     # UE IsExceedingMaxSpeed: speed past 1.01x the wanted speed counts as over it

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

## True when this hunter can mantle a double-high ledge (Archer and Juggernaut).
static func climbs_tall(h: Hunter) -> bool:
	return bool(of(h.arch).get("climb_tall", false))

## Ground speed after a step with no keys: UE's walking brake, ground_friction (share of the speed per
## second) plus a constant brake_decel, so a let-go from a run slides ~0.3 m. Speed over `run` (a kit
## step, a knock) first sheds at Hunter.GROUND_SHED. grip < 1 on ice.
static func brake(hv: Vector2, run: float, grip: float, dt: float) -> Vector2:
	var s := hv.length()
	if s > run + 0.05:
		return hv * (maxf(run, s - Hunter.GROUND_SHED * grip * dt) / s)
	return (hv * maxf(0.0, 1.0 - ground_friction * grip * dt)).move_toward(Vector2.ZERO, brake_decel * grip * dt)

## Velocity a dash leaves you with: no hard stop, it hands over at dash_exit_run of run speed (never
## faster than the dash), and the walk, brake or air carry takes it from there.
static func dash_exit(dash_v: Vector2, run: float) -> Vector2:
	return dash_v.limit_length(run * dash_exit_run)

## Metres a let-go at v0 m/s slides on flat ground under brake() (dv/dt = -friction*v - brake_decel):
## a kit step with a measured total takes this off its dash so the slide doesn't add to it.
static func slide(v0: float) -> float:
	var k := ground_friction
	if k <= 0.0:
		return v0 * v0 / (2.0 * brake_decel)
	return v0 / k - brake_decel / (k * k) * log(1.0 + k * v0 / brake_decel)

## Horizontal speed after a step in the air, UE's falling CalcVelocity: with keys held under their speed
## the carry doesn't bleed, air_friction (a share per second) only bends it toward the keys and the keys add
## air_control of the ground accel, capped at their speed. Keys off, or over it (a dash, a pad, a knock),
## it brakes at air_brake; keys held over it stop the brake at their speed. So you land with the run you
## jumped with.
static func air_steer(h: Hunter, hv: Vector2, wish: Vector2, dt: float) -> Vector2:
	var run := wish.length()
	var s := hv.length()
	if run < 0.01 or s > run * OVER_RUN:
		var braked := hv * maxf(0.0, 1.0 - air_brake * dt)
		if run < 0.01:
			return braked
		if braked.length() < run and hv.dot(wish) > 0.0:
			braked = hv / s * run
		return (braked + wish / run * h.ground_accel * air_control * dt).limit_length(braked.length())
	var dir := wish / run
	var bent := hv - (hv - dir * s) * minf(air_friction * dt, 1.0)
	return (bent + dir * h.ground_accel * air_control * dt).limit_length(run)

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

## Speed onto a ledge you climb (m/s), from a hunter's run speed.
static func mantle_launch(run_speed: float) -> float:
	return maxf(run_speed * mantle_launch_keep, mantle_launch_min)
