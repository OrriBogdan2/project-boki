class_name HazardMoves
extends RefCounted
## What a Hunter's body does on hazard ground (content/rules/terrain_hazards.json): in Deep Water it swims (the
## HunterSwim crawl, state "swim", sunk to the shoulders), on ice it has no footing unless warded (state "footing":
## the ice kind's "moves", which WardenGait lays on the run: a shorter, quicker stride, the free arms out).
## The game that owns the hunter decides (its perks never reach the others); the move rides its snapshot
## row (HunterNet) so every other game shows the same.

const META := "hazard_move"  # a remote hunter's move from its snapshot
enum { NONE, SWIM, FOOTING }

## The move h makes now: worked out here for a hunter this game owns, as sent for a remote one.
static func of(h: Hunter) -> int:
	if h.remote:
		return int(h.get_meta(META, NONE))
	if not h.grounded or h.downed or h.out or h.mounted():
		return NONE
	var tz := TerrainHazards.of(h.m)
	var a := tz.area_at(h.pos) if tz else -1
	if a >= 0 and tz.areas[a]["kind"] == "deep_water":
		return SWIM
	return FOOTING if (h.m as Match).ground_grip(h.pos, h) < 1.0 else NONE

## Hunter._anim_state: the keys HunterAnim and WardenClips read.
static func anim_state(h: Hunter, s: Dictionary) -> void:
	var mv := of(h)
	s["swim"] = mv == SWIM
	s["footing"] = TerrainHazards.kind_def("ice")["moves"] if mv == FOOTING else {}

## m below its feet the model is drawn: sunk into the water as the swim eases in (HomeWater's depth).
static func sink(h: Hunter) -> float:
	return HomeWater.SINK_DEEP * h.anim.swim_k if h.anim else 0.0
