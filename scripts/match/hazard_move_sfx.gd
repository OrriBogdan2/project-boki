class_name HazardMoveSfx
extends RefCounted
## The sounds of a Hunter's hazard moves (HazardMoves), each on its clip event: a stroke splash for every arm
## stroke of the HunterSwim crawl, a splash going into deep water and one coming out, and a catch when the footing
## comes back on ice (the scrape of losing it is HazardSfx's ice contact cue). HunterSwim.tick finds the events and
## sets HunterAnim.hz_cues; Hunter plays them after each pose. Going in is a splash in the Hunter's weight class
## (water_land_<light|medium|heavy>) and a dash while swimming throws up spray (water_dash, HeroSfx.dash_name).
## A Boki doesn't swim: it splashes landing in deep water, sprays starting a charge there and wades through it
## (the water_wade loop, louder and higher the faster it goes). Set "water" (tools/gen_sfx_water.py); the stroke
## and coming-out splash are the farm's (swim, splash: HomeWater); the catch is hazards.json's. Sfx places each
## where it happens, so the listener's range and roll-off apply; a rival's are quieter, like its footsteps.

const STROKE := 1  # HunterAnim.hz_cues bits
const ENTER := 2
const EXIT := 4
const CATCH := 8

const OTHERS_DB := -6.0  # dB quieter than the local Hunter's own (the footsteps are 6 dB down too)
const STROKE_DB := -11.0  # dB at the local Hunter: one arm stroke
const ENTER_DB := -7.0  # dB: a splash going under
const EXIT_DB := -12.0  # dB: a splash coming out, lighter and higher
const CATCH_DB := -11.0  # dB: footing back

const KIN_WEIGHT := {"small": "light", "medium": "medium", "large": "heavy"}  # a Boki's size -> splash class
const KIN_PITCH := 1.1  # a Boki is smaller than a Hunter: its water sounds a little higher
const KIN_LAND_DB := -10.0  # dB: a Boki landing in deep water
const KIN_DASH_DB := -13.0  # dB: a Boki's charge starting in deep water
const WADE_DB := Vector2(-26.0, -16.0)  # dB: a Boki's wading loop at WADE_MIN_K of its run speed, at full run
const WADE_PITCH := Vector2(0.85, 1.15)  # the loop's pitch at those two speeds
const WADE_MIN_K := 0.15  # of run speed: slower is standing in the water (no loop)


## The bits for the moves a has just started or ended: swim and ice are what the pose now says.
static func edges(a: HunterAnim, swim: bool, ice: bool) -> int:
	var bits := 0
	if swim != a.hz_swim:
		bits |= ENTER if swim else EXIT
	if a.hz_ice and not ice:
		bits |= CATCH
	a.hz_swim = swim
	a.hz_ice = ice
	return bits


## Plays what h's last pose found.
static func play(h: Hunter) -> void:
	var c := h.anim.hz_cues
	if c == 0 or h.downed:
		return
	var rival := 0.0 if h.is_local() else OTHERS_DB
	if c & ENTER:
		Sfx.play("water_land_" + StepSurface.weight_of(h.arch), h.pos, ENTER_DB + rival, 0.08)
	if c & EXIT:
		Sfx.play("splash", h.pos, EXIT_DB + rival, 0.08, 1.2)
	if c & STROKE:
		Sfx.play("swim", h.pos, STROKE_DB + rival, 0.12)
	if c & CATCH:
		Sfx.play("hazard_catch", h.pos, CATCH_DB + rival, 0.1)


## A Boki landing (thrown, or the end of a leap): its size's splash in deep water.
static func kin_land(k: Kin) -> void:
	if _deep(k):
		var weight: String = KIN_WEIGHT.get(k.ks.size if k.ks else "small", "light")
		Sfx.play("water_land_" + weight, k.pos, KIN_LAND_DB, 0.1, KIN_PITCH)


## A Boki's charge starting in deep water: a spray.
static func kin_dash(k: Kin) -> void:
	if _deep(k):
		Sfx.play("water_dash", k.pos, KIN_DASH_DB, 0.1, KIN_PITCH)


## Each ground step of a Boki: wading through deep water near the listener holds its loop, which stops by itself
## (Sfx.HOLD_MS) once these calls stop.
static func kin_wade(k: Kin) -> void:
	var f := inverse_lerp(WADE_MIN_K, 1.0, Vector2(k.vel.x, k.vel.z).length() / maxf(1.0, k.speed))
	if f < 0.0 or Vector2(k.pos.x - Sfx.listener.x, k.pos.z - Sfx.listener.z).length() > StepReach.RIVAL_M:
		return
	if _deep(k):
		f = minf(f, 1.0)
		var pitch := KIN_PITCH * lerpf(WADE_PITCH.x, WADE_PITCH.y, f)
		Sfx.loop_hold("wade%d" % k.get_instance_id(), "water_wade", k.pos, lerpf(WADE_DB.x, WADE_DB.y, f), pitch)


static func _deep(k: Kin) -> bool:
	var tz := TerrainHazards.of(k.m)
	return k.grounded and tz != null and tz.in_deep(k.pos)
