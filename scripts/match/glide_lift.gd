class_name GlideLift
extends RefCounted
## Per-hunter glider float over the abyss, when a ledge counts as yours to catch, and the glider's
## hand-over to the ledge rise that catches it.
## Under an island's lip the glider lifts you (Hunter.abyss_lift_vy) and lets go at the lip. High over the ground
## the glider pulls you down toward HunterMove.glide_height. The swoop [game data]: fall that the glider's own
## pull or dive built is turned into forward speed as the canopy sheds it on a level-out (Loco.glide_swoop of it,
## half overheated), and that bonus fades to nothing over Loco.glide_swoop_fade. An opening never swoops
## (DECISIONS 11-08): a fall you bring into the glider is absorbed. Decision 0095. Under a lip, open_kick's
## pull (decision 0061) is the one exception: the abyss dive carries into the feather.

const PULL_FWD := 0.6  # [est] share of the fall speed (m/s) a glider opened below the lip turns into forward speed
const HANG_GRAV := 0.35  # [est] share of HunterFeel.glide_grav while the lift's float lasts: a soft hang at the top
const HANG_T := 0.9  # [est] s the float lasts after the last lifting step
const LEDGE_AIR_T := 0.5  # s in the air after which a ledge higher than where you last stood is yours to catch

var hang_t := 0.0  # s left of the float
var built := 0.0  # m/s of your fall past the sink that the glider's pull or dive built: the swoop's source
var swoop := 0.0  # m/s of swoop speed riding on top of the glide
var _swoop_drain := 0.0  # m/s per second the swoop fades at (all of it within Loco.glide_swoop_fade)
var _swoop_on := 0.0  # the part of the hunter's velocity that is swoop
var _under := false  # under the lip last step (the lift's zone)


## Counts the float and the swoop down, stops the lift's climb as you come out over the lip, and drops the swoop
## when the glider folds (the speed stays; the air and feathering steps take it from there).
func tick(h: Hunter, dt: float) -> void:
	hang_t = maxf(0.0, hang_t - dt)
	var under := lifting(h)
	if _under and not under and h.gliding:
		h.vel.y = minf(h.vel.y, 0.0)  # [game data] the lift lets go at its top: no throw past it
	_under = under
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
		swoop = minf(swoop + gain, Loco.glide_max - HunterMove.glide_cruise)  # a cruise glide tops out at the max
		_swoop_drain = swoop / Loco.glide_swoop_fade
		return caught
	return build(h, maxf(vy - HunterFeel.glide_grav * gravity_scale() * dt, -sink_vy), usual)


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


## The glider opening: it catches the fall or the rise you bring (Loco.glide_start). Below an island's lip it also
## pulls you up out of the fall you bring (decision 0061: the dive's
## momentum carries into the feather): PULL_FWD of the fall speed you came in with goes on as forward speed (never
## past Loco.glide_max; Loco.glide_step bleeds it back to cruise in ~1.5 s). This is the abyss pull, not the
## swoop (0095).
func open_kick(h: Hunter) -> void:
	var fall := maxf(0.0, -h.vel.y)
	h.vel.y = Loco.glide_start(h.vel.y, h.pos.y - h.ground())
	if h.dropping or not h.below_lip:
		return
	_pull_forward(h, fall * PULL_FWD)


## Adds `add` m/s along where you're heading (or steering, from a straight drop), up to Loco.glide_max.
func _pull_forward(h: Hunter, add: float) -> void:
	var hv := Vector2(h.vel.x, h.vel.z)
	var dir: Vector2 = hv if hv.length() > 0.5 else h.inp.get("move", Vector2.ZERO)
	if add <= 0.0 or dir.length() < 0.1:
		return
	hv = dir.normalized() * maxf(hv.length(), minf(hv.length() + add, Loco.glide_max))
	h.vel.x = hv.x
	h.vel.z = hv.y


## Is the glider in its abyss lift: over the void, under the lip's lift top (edge_mantle floor_rise over it)?
static func lifting(h: Hunter) -> bool:
	return h.gliding and not h.dropping and h.over_void() and h.pos.y < h.lip_y + float(MantleCarry.rules["floor_rise"])


## Airborne long enough, gliding, or just off the glider: pressing into a wall means climbing it, not
## stepping back up a terrace you just left.
static func airborne_long(h: Hunter) -> bool:
	return h.gliding or h.glide_off_t < HunterFeel.feather_keep or h.air_t > LEDGE_AIR_T
