class_name StepSurface
extends RefCounted
## What a Hunter's footstep sounds like (Juice.footstep): the surface underfoot and the cue for it.
## Surfaces: grass, stone, wood, snow (every Hunter has its own steps on these) and water and metal
## (shared steps per weight class: step_<surface>_<light|medium|heavy>, made by tools/gen_sfx_steps.py).
## Metal is the sky train's car decks, wood a plank bridge (World.bridge); the Hollow Crown's
## stone bridges are painted paths (stone) and it has no skiff docks since the Ways Out. Water is the
## farm's shallow ponds (HomeWater): match maps have none.
## A Hunter's own "<arch>_step_<surface>" wins when it has one. docs/AUDIO.md lists each region.

const SHARED := ["water", "metal"]     # surfaces with steps per weight class, not per Hunter
const WEIGHT_DB := {"light": -1.5, "medium": 0.0, "heavy": 1.5}     # dB on those steps: heavier boots carry more

## The surface under `pos` in match `m`: the sky train's decks, else the ground's (Juice.ground_surface).
static func at(m: Match, pos: Vector3) -> String:
	if m.skytrain != null and m.skytrain.on_deck(pos):
		return "metal"
	return Juice.ground_surface(m.world, pos)

## The sound for `surf` underfoot of `h`: its own set when it has one, else the shared one.
static func cue(h: Hunter, surf: String) -> String:
	var shared := "step_" + surf
	if surf in SHARED:
		shared += "_" + weight_of(h.arch)
	return HeroSfx.of(h, "step_" + surf, shared)

## The step's volume: `base` dB, plus the weight class's on the shared surfaces.
static func vol_db(h: Hunter, surf: String, base: float) -> float:
	return base + (float(WEIGHT_DB[weight_of(h.arch)]) if surf in SHARED else 0.0)

static func weight_of(arch: String) -> String:
	var wt := Arch.weight(arch)
	return wt if WEIGHT_DB.has(wt) else "medium"
