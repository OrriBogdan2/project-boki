class_name WardenWarm
extends RefCounted
## Gets a match's Warden models ready before its hunters spawn, so no frame under the loading screen
## builds a hunter and also reads its .glb or measures its rig (item 33: profiled at 50 ms for the
## read and 100 ms for the measure on top of a 100 ms hunter build, all in one frame).

## The Wardens this match can spawn: only yours when you're out alone, else every one (bots pick
## theirs while they spawn).
static func archs(m: Match) -> Array:
	var alone := int(m.opts.get("teams", 4)) <= 1 and int(m.opts.get("squad", 1)) <= 1 and not m.opts.has("net")
	return [String(m.my_kit()["arch"])] if alone else Arch.ids()

## Starts reading their .glb files on loader threads (call it before the map builds: the reads
## run while it does).
static func fetch(m: Match) -> void:
	for a in archs(m):
		WardenGlb.fetch(a)

## Measures each one's rig rest (a hidden hunter build of its own), a frame apart under the loading screen.
static func measure(m: Match) -> void:
	for a in archs(m):
		if not WardenGlb.has_rest(a):
			WardenGlb.neutral_rest(a)
			await m._slice()
