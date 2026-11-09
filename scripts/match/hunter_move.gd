class_name HunterMove
extends RefCounted
## Per-hunter run speed, ground acceleration and tall-ledge climbing, plus the ground stop, dash exit,
## fall, glide, dive and mantle tunables every hunter shares, from content/rules/hunter_move.json
## ([game data]: SUPERVIVE's movement settings, uu converted to metres).

static var _rules: Dictionary = _load()
static var _phys: Dictionary = _rules["physics"]
static var brake_decel: float = _phys["brake"]
static var ground_friction: float = _phys["ground_friction"]
static var dash_exit_run: float = _phys["dash_exit_run"]
static var fall_max: float = _phys["fall_cap"]
static var abyss_fall_max: float = _phys["abyss_fall_cap"]
static var abyss_slow_from: float = _phys["abyss_slow_from"]
static var abyss_slow_to: float = _phys["abyss_slow_to"]
static var glide_height: float = _phys["glide_height"]
static var glide_pull_vy: float = _phys["glide_pull_vy"]
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

## The source's walking brake at `speed` (m/s^2): ground_friction's share of the speed plus brake_decel. UE
## sheds any speed over the run this way, keys held or not, so a knock or a kit step slides out the same.
static func brake_rate(speed: float) -> float:
	return ground_friction * speed + brake_decel

## Ground speed after a step with no keys: the walking brake, so a let-go from a run slides ~0.3 m and a
## knock or kit step slides out under the same rule. grip < 1 on ice.
static func brake(hv: Vector2, grip: float, dt: float) -> Vector2:
	return (hv * maxf(0.0, 1.0 - ground_friction * grip * dt)).move_toward(Vector2.ZERO, brake_decel * grip * dt)

## Velocity a dash leaves you with: no hard stop, it hands over at dash_exit_run of run speed (never
## faster than the dash), and the walk, brake or air carry takes it from there.
static func dash_exit(dash_v: Vector2, run: float) -> Vector2:
	return dash_v.limit_length(run * dash_exit_run)

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
	var k := ground_friction
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
