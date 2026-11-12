class_name HazardMoveSfx
extends RefCounted
## The sounds of a Hunter's hazard moves (HazardMoves), each on its clip event: a stroke splash for every arm
## stroke of the HunterSwim crawl, a splash going into deep water and one coming out, a scrape when the footing
## goes on ice and a catch when it comes back. HunterSwim.tick finds the events and sets HunterAnim.hz_cues;
## Hunter plays them after each pose. The water sounds are the farm's (splash, swim: HomeWater); the two ice
## sounds are tools/gen_sfx_hazard_moves.py. Sfx places each at the hunter, so the listener's range and
## roll-off apply; a rival's are quieter, like its footsteps.

const STROKE := 1        # HunterAnim.hz_cues bits
const ENTER := 2
const EXIT := 4
const SKID := 8
const CATCH := 16

const OTHERS_DB := -6.0  # dB quieter than the local Hunter's own (the footsteps are 6 dB down too)
const STROKE_DB := -11.0 # dB at the local Hunter: one arm stroke
const ENTER_DB := -7.0   # dB: a splash going under
const EXIT_DB := -12.0   # dB: a splash coming out, lighter and higher
const SKID_DB := -9.0    # dB: footing lost on ice
const CATCH_DB := -11.0  # dB: footing back

## The bits for the moves a has just started or ended: swim and ice are what the pose now says.
static func edges(a: HunterAnim, swim: bool, ice: bool) -> int:
	var bits := 0
	if swim != a.hz_swim:
		bits |= ENTER if swim else EXIT
	if ice != a.hz_ice:
		bits |= SKID if ice else CATCH
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
		Sfx.play("splash", h.pos, ENTER_DB + rival, 0.08, 1.0)
	if c & EXIT:
		Sfx.play("splash", h.pos, EXIT_DB + rival, 0.08, 1.2)
	if c & STROKE:
		Sfx.play("swim", h.pos, STROKE_DB + rival, 0.12)
	if c & SKID:
		Sfx.play("hazard_skid", h.pos, SKID_DB + rival, 0.1)
	if c & CATCH:
		Sfx.play("hazard_catch", h.pos, CATCH_DB + rival, 0.1)
