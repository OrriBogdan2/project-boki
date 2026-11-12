class_name GlideLift
extends RefCounted
## Per-hunter glider spring and float over the abyss, and when a ledge counts as yours to catch.
## Opening the glider deep under an island's lip springs you up once per lift; the lift then floats
## over the lip under low gravity (Hunter.abyss_lift_vy does the climb itself). High over the ground
## the glider pulls you down toward HunterMove.glide_height. The swoop [game data]: fall that the glider's own
## pull or dive built is turned into forward speed as the canopy sheds it on a level-out (Loco.glide_swoop of it,
## half overheated), and that bonus fades to nothing over Loco.glide_swoop_fade. An opening never swoops
## (DECISIONS 11-08): a fall you bring into the glider is absorbed. Decision 0095.

const OPEN_KICK := 6.0      # [est] m/s of spring when the glider opens more than Hunter.ABYSS_BRAKE_DIST under the lip
const KICK_HEAT := 0.08     # [est] share of a full glider's heat the spring costs
const HANG_GRAV := 0.35     # [est] share of Hunter.GLIDE_GRAV while the lift's float lasts: a soft hang at the top
const HANG_T := 0.9         # [est] s the float lasts after the last lifting step
const LEDGE_AIR_T := 0.5    # s in the air after which a ledge higher than where you last stood is yours to catch

var hang_t := 0.0           # s left of the float
var kicked := false         # this lift's spring is used; coming back above the lip gives it back
var built := 0.0            # m/s of your fall past the sink that the glider's pull or dive built: the swoop's source
var swoop := 0.0            # m/s of swoop speed riding on top of the glide
var _swoop_drain := 0.0     # m/s per second the swoop fades at (all of it within Loco.glide_swoop_fade)
var _swoop_on := 0.0        # the part of the hunter's velocity that is swoop

## Counts the float and the swoop down, re-arms the spring once you are on the ground or above the lip, and
## drops the swoop when the glider folds (the speed stays; the air and feathering steps take it from there).
func tick(h: Hunter, dt: float) -> void:
	hang_t = maxf(0.0, hang_t - dt)
	if h.grounded or not h.below_lip:
		kicked = false
	swoop = maxf(0.0, swoop - _swoop_drain * dt)
	if not h.gliding:
		built = 0.0
		swoop = 0.0
		_swoop_on = 0.0

## Gravity multiplier for the glider while the lift's float lasts.
func gravity_scale() -> float:
	return HANG_GRAV if hang_t > 0.0 else 1.0

## The glider's sink rate (m/s) this step: above HunterMove.glide_height over the ground (or over the
## lip, above the abyss) it pulls you down at HunterMove.glide_pull_vy instead.
func sink(h: Hunter, usual: float) -> float:
	var under := h.lip_y if h.over_void() else h.ground()
	if h.pos.y - under <= HunterMove.glide_height:
		return usual
	return maxf(usual, HunterMove.glide_pull_vy)

## The glider's vertical speed after a step at its sink rate `usual` (m/s): a fall faster than the sink is
## caught back to it (a level-out: the caught fall the glider built becomes swoop), else gravity eases you down.
func fall_vy(h: Hunter, usual: float, dt: float) -> float:
	var sink_vy := sink(h, usual)
	var vy := h.vel.y
	if vy < -sink_vy:
		var caught := move_toward(vy, -sink_vy, Loco.glide_catch * dt)
		var cut := minf(built, caught - vy)
		built = minf(built - cut, maxf(0.0, -caught - usual))
		var gain := cut * Loco.glide_swoop * (1.0 if h.glide_fuel > 0.001 else 0.5)
		swoop = minf(swoop + gain, Loco.glide_max - Hunter.GLIDE_SPEED)     # a cruise glide tops out at the max
		_swoop_drain = swoop / Loco.glide_swoop_fade
		return caught
	return build(h, maxf(vy - Hunter.GLIDE_GRAV * gravity_scale() * dt, -sink_vy), usual)

## Notes the fall `vy` (m/s) the glider's own pull or dive reached this step past its sink rate `usual`.
func build(h: Hunter, vy: float, usual: float) -> float:
	var past := maxf(0.0, -vy - usual)
	built = minf(built + maxf(0.0, past - maxf(0.0, -h.vel.y - usual)), past)
	return vy

## The glide's own steering works on `hv` without the swoop...
func unswoop(hv: Vector2) -> Vector2:
	var s := hv.length()
	return hv * (maxf(0.0, s - _swoop_on) / s) if s > 0.001 else hv

## ...and the swoop rides back on top along the new heading.
func reswoop(hv: Vector2) -> Vector2:
	_swoop_on = swoop if hv.length() > 0.001 else 0.0
	return hv + hv.normalized() * _swoop_on

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
