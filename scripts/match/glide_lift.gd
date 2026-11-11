class_name GlideLift
extends RefCounted
## Per-hunter glider spring and float over the abyss, and when a ledge counts as yours to catch.
## Opening the glider under an island's lip turns the fall into forward speed and, deep down, springs you up once
## per lift; the lift then floats over the lip under low gravity (Hunter.abyss_lift_vy does the climb itself).
## High over the ground the glider pulls you down toward HunterMove.glide_height; that drop never turns into speed
## (DECISIONS 11-08).

const OPEN_KICK := 6.0      # [est] m/s of spring when the glider opens more than Hunter.ABYSS_BRAKE_DIST under the lip
const KICK_HEAT := 0.08     # [est] share of a full glider's heat the spring costs
const PULL_FWD := 0.6       # [est] share of the fall speed (m/s) a glider opened below the lip turns into forward speed
const PULL_RISE := 0.3      # [est] share of it the spring adds upward
const HANG_GRAV := 0.35     # [est] share of Hunter.GLIDE_GRAV while the lift's float lasts: a soft hang at the top
const HANG_T := 0.9         # [est] s the float lasts after the last lifting step
const LEDGE_AIR_T := 0.5    # s in the air after which a ledge higher than where you last stood is yours to catch

var hang_t := 0.0           # s left of the float
var kicked := false         # this lift's spring is used; coming back above the lip gives it back

## Counts the float down and re-arms the spring once you are on the ground or above the lip.
func tick(h: Hunter, dt: float) -> void:
	hang_t = maxf(0.0, hang_t - dt)
	if h.grounded or not h.below_lip:
		kicked = false

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

## Opening the glider below an island's lip pulls you up out of the fall you bring (decision 0061: the dive's
## momentum carries into the feather): PULL_FWD of the fall speed goes on as forward speed (never
## past Loco.glide_max; Loco.glide_step bleeds it back to cruise in ~1.5 s), the source's swoop scaled down (its
## 2.5x was for the high glide, retired 11-08). Well below the lip it also springs you upward, once per lift, for
## a little heat, the spring carrying PULL_RISE of the fall.
func open_kick(h: Hunter) -> void:
	if h.dropping or not h.below_lip:
		return
	var fall := maxf(0.0, -h.vel.y)
	_pull_forward(h, fall * PULL_FWD)
	if kicked or h.lip_y - h.pos.y <= Hunter.ABYSS_BRAKE_DIST:
		return
	kicked = true
	h.vel.y = minf(maxf(h.vel.y, 0.0) + OPEN_KICK + fall * PULL_RISE, Hunter.ABYSS_LIFT_CAP)
	h.glide_fuel = maxf(0.0, h.glide_fuel - KICK_HEAT)

## Adds `add` m/s along where you're heading (or steering, from a straight drop), up to Loco.glide_max.
func _pull_forward(h: Hunter, add: float) -> void:
	var hv := Vector2(h.vel.x, h.vel.z)
	var dir: Vector2 = hv if hv.length() > 0.5 else h.inp.get("move", Vector2.ZERO)
	if add <= 0.0 or dir.length() < 0.1:
		return
	hv = dir.normalized() * maxf(hv.length(), minf(hv.length() + add, Loco.glide_max))
	h.vel.x = hv.x
	h.vel.z = hv.y

## Airborne long enough, gliding, or just off the glider: pressing into a wall means climbing it, not
## stepping back up a terrace you just left.
static func airborne_long(h: Hunter) -> bool:
	return h.gliding or h.glide_off_t < Hunter.FEATHER_KEEP or h.air_t > LEDGE_AIR_T
