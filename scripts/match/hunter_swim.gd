class_name HunterSwim
extends RefCounted
## A Hunter in water (HunterAnim state keys "wade" and "swim", from HomeWater.anim_state()). Wading is the run
## cycle with the knees hauled up out of the water. Swimming is a crawl: the legs flutter and each hand the kit
## lets go of strokes round in turn, at a rate that follows the swim speed, so the stroke matches how fast you move.
## A hand the kit keeps on its weapon stays there (the weapon rides as on a run); a Warden's own clips stand
## aside for both (its warden_anim "procedural" list), so each Hero keeps its stance, class and weapon.

const WADE_HIP := 0.8        # rad: extra hip lift at the top of a wading step
const WADE_KNEE := 0.95      # rad: extra knee fold at the top of a wading step
const FULL_SPEED := 2.5      # m/s: a full swim (the farm's walk speed 5 x HomeWater.SWIM_SPEED)
const HZ_TREAD := 0.5        # strokes a second treading water
const HZ_FULL := 1.3         # strokes a second at full swim speed
const KICK_PER_STROKE := 2.0 # flutter kicks of each leg per stroke
const KICK_HIP := 0.3        # rad: the flutter kick's swing
const TREAD_HIP := 0.55      # rad: hips flexed treading upright
const TRAIL_HIP := -0.12     # rad: legs trailing straight out behind a full swim
const REACH_Z := 0.28        # m: how far the stroke runs fore and aft of the shoulder
const REACH_Y := 0.22        # m: how deep the pull goes (and how high the hand recovers)
const REACH_TREAD := 0.45    # share of the stroke when only treading water
const SIDE_X := 0.1          # m: the hand stays this far out from its shoulder line
const EASE_RATE := 8.0       # 1/s: how fast the wade and the swim ease in and out

## Eases the wade and swim weights and turns the stroke at the pace of the swim. Sets a.hz_cues (HazardMoveSfx):
## a stroke when a hand goes in (the phase passes 0 or PI), going into and out of the swim, footing lost and back.
static func tick(a: HunterAnim, dt: float, s: Dictionary, spd: float) -> void:
	var swim := bool(s.get("swim", false))
	var ice := not (s.get("footing", {}) as Dictionary).is_empty()
	a.hz_cues = HazardMoveSfx.edges(a, swim, ice)
	a.wade_k = move_toward(a.wade_k, 1.0 if bool(s.get("wade", false)) else 0.0, dt * EASE_RATE)
	a.swim_k = move_toward(a.swim_k, 1.0 if swim else 0.0, dt * EASE_RATE)
	var ph0 := a.swim_ph
	a.swim_ph += dt * TAU * lerpf(HZ_TREAD, HZ_FULL, speed_k(spd))
	if swim and a.swim_k > 0.5 and int(floor(a.swim_ph / PI)) != int(floor(ph0 / PI)):
		a.hz_cues |= HazardMoveSfx.STROKE

## 0 treading .. 1 a full swim.
static func speed_k(spd: float) -> float:
	return clampf(spd / FULL_SPEED, 0.0, 1.0)

## Extra (hip, knee) for a leg in its swing-through (sw 0..1): the wading knee-lift.
static func wade(sw: float, k: float) -> Vector2:
	var up := pow(sw, 1.2) * k
	return Vector2(WADE_HIP * up, -WADE_KNEE * up)

## Flutter kick: Vector4(hip_l, knee_l, hip_r, knee_r), `gait` is how much the legs work (a hoverer's barely do).
static func legs(ph: float, spd: float, gait: float) -> Vector4:
	var sk := speed_k(spd)
	var base := lerpf(TREAD_HIP, TRAIL_HIP, sk)
	var kick := ph * KICK_PER_STROKE
	var out := Vector4(base, -0.3, base, -0.3)
	out.x += sin(kick) * KICK_HIP * gait
	out.z += sin(kick + PI) * KICK_HIP * gait
	out.y -= (0.25 + 0.2 * sin(kick + 1.0)) * gait
	out.w -= (0.25 + 0.2 * sin(kick + 1.0 + PI)) * gait
	return out

## Where a stroking hand goes, from its shoulder: pulled back low under the water, brought forward high over it.
## side: -1 the left arm, +1 the right; `arm` is the class's reach (HunterAnim.STANCE "arm").
static func hand(sh: Vector3, ph: float, spd: float, side: float, arm: float) -> Vector3:
	var reach := lerpf(REACH_TREAD, 1.0, speed_k(spd)) * arm
	return sh + Vector3(side * SIDE_X, -0.04 - REACH_Y * sin(ph) * reach, -0.1 - REACH_Z * cos(ph) * reach)
