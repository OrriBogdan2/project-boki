class_name GlideLift
extends RefCounted
## Per-hunter glider spring and float over the abyss, and when a ledge counts as yours to catch.
## Opening the glider deep under an island's lip springs you up once per lift; the lift then floats
## over the lip under low gravity (Hunter.abyss_lift_vy does the climb itself). High over the ground
## the glider pulls you down toward HunterMove.glide_height, and that swoop turns into glide speed.

const OPEN_KICK := 6.0      # [est] m/s of spring when the glider opens more than Hunter.ABYSS_BRAKE_DIST under the lip
const KICK_HEAT := 0.08     # [est] share of a full glider's heat the spring costs
const HANG_GRAV := 0.35     # [est] share of Hunter.GLIDE_GRAV while the lift's float lasts: a soft hang at the top
const HANG_T := 0.9         # [est] s the float lasts after the last lifting step
const LEDGE_AIR_T := 0.5    # s in the air after which a ledge higher than where you last stood is yours to catch

var hang_t := 0.0           # s left of the float
var kicked := false         # this lift's spring is used; coming back above the lip gives it back
var swoop := 0.0            # m/s of extra glide speed from a swoop, fading out
var _swoop_drain := 0.0     # m/s per second the swoop fades at

## Counts the float down and re-arms the spring once you are on the ground or above the lip.
func tick(h: Hunter, dt: float) -> void:
	hang_t = maxf(0.0, hang_t - dt)
	swoop = maxf(0.0, swoop - _swoop_drain * dt)
	if h.grounded or not h.below_lip:
		kicked = false

## Gravity multiplier for the glider while the lift's float lasts.
func gravity_scale() -> float:
	return HANG_GRAV if hang_t > 0.0 else 1.0

## The glider's sink rate (m/s) this step: above HunterMove.glide_height over the ground (or over the
## lip, above the abyss) it pulls you down at HunterMove.glide_pull_vy instead, and the drop past the
## usual sink becomes glide speed (swoop_ratio of it, up to Hunter.GLIDE_MAX), fading over HunterMove.swoop_fade.
func sink(h: Hunter, usual: float) -> float:
	var under := h.lip_y if h.over_void() else h.ground()
	if h.pos.y - under <= HunterMove.glide_height:
		return usual
	var gain := maxf(0.0, -h.vel.y - Hunter.GLIDE_SINK) * HunterMove.swoop_ratio
	gain = minf(gain, Hunter.GLIDE_MAX - Hunter.GLIDE_SPEED)     # pulling out of a dive tops out at the glide's max
	if gain > swoop:
		swoop = gain
		_swoop_drain = gain / HunterMove.swoop_fade
	return maxf(usual, HunterMove.glide_pull_vy)

## Opening the glider well below an island's lip springs you upward, once per lift, for a little heat.
func open_kick(h: Hunter) -> void:
	if kicked or h.dropping or not h.below_lip or h.lip_y - h.pos.y <= Hunter.ABYSS_BRAKE_DIST:
		return
	kicked = true
	h.vel.y = minf(maxf(h.vel.y, 0.0) + OPEN_KICK, Hunter.ABYSS_LIFT_CAP)
	h.glide_fuel = maxf(0.0, h.glide_fuel - KICK_HEAT)

## Airborne long enough, gliding, or just off the glider: pressing into a wall means climbing it, not
## stepping back up a terrace you just left.
static func airborne_long(h: Hunter) -> bool:
	return h.gliding or h.glide_off_t < Hunter.FEATHER_KEEP or h.air_t > LEDGE_AIR_T
