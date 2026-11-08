class_name MobBudget
extends RefCounted
## Monsters and ground drops per graphics preset (the performance pass). Fewer monsters alive means
## fewer skinned parts, shadow casters and AI ticks; fewer, bigger gem drops mean fewer pickup nodes to
## bob and to scan every frame. Medium keeps fights full (a little off the biggest camps); Low and Very
## Low cut hard but keep each camp's lead monster. Camps, lair guards, exit waves and the Blight read it.

## Share of the usual monster count kept (1 = as designed).
const SPAWN_K := {"very_low": 0.35, "low": 0.55, "medium": 0.85, "high": 1.0, "ultra": 1.0}
## Most gem drops one kill leaves (the same total gems, in bigger drops).
const GEM_DROPS := {"very_low": 1, "low": 2, "medium": 3, "high": 4, "ultra": 4}
const GEM_SCALE_MAX := 1.8      # a big drop is drawn up to this much larger than a small one

static func spawn_k() -> float:
	return float(SPAWN_K.get(Settings.quality(), 1.0))

## A usual count scaled to the preset, never below one.
static func count(n: int) -> int:
	return maxi(1, roundi(n * spawn_k()))

## A camp's monsters, lead first: the tail is what gets cut.
static func trim(comp: Array) -> Array:
	return comp.slice(0, count(comp.size()))

## How many drops a kill worth `gems` gems leaves.
static func gem_drops(gems: int) -> int:
	return mini(gems, int(GEM_DROPS.get(Settings.quality(), 4)))

## Draw size of a gem drop of this value (a usual small gem is worth about 3).
static func gem_scale(value: int) -> float:
	return clampf(sqrt(value / 3.0), 1.0, GEM_SCALE_MAX)
