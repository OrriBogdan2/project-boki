class_name MobBudget
extends RefCounted
## Monsters per graphics preset (the performance pass). Fewer monsters alive means fewer skinned parts,
## shadow casters and AI ticks (gems already come as one pile, DropMerge). Medium keeps fights full (a
## little off the biggest camps); Low and Very Low cut hard but keep each camp's lead monster. Camps, lair guards, exit waves and the Blight read it.

## Share of the usual monster count kept (1 = as designed).
const SPAWN_K := {"very_low": 0.35, "low": 0.55, "medium": 0.85, "high": 1.0, "ultra": 1.0}

static func spawn_k() -> float:
	return float(SPAWN_K.get(Settings.quality(), 1.0))

## A usual count scaled to the preset, never below one.
static func count(n: int) -> int:
	return maxi(1, roundi(n * spawn_k()))

## A camp's monsters, lead first: the tail is what gets cut.
static func trim(comp: Array) -> Array:
	return comp.slice(0, count(comp.size()))
