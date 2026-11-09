class_name RecastHint
extends RefCounted
## The teaching beat for two-step abilities (DECISIONS 2026-11-08): the first time the local Hunter's kit opens
## a recast window, one banner line "Press <key> again to <verb>", once per Hunter (kit) per profile. A kit says what
## is open through ArchKit.recast_open(). It waits out the first second of a fight: a rival in range for less than
## FIGHT_GRACE keeps the line back (the window may still be open when the second is over).

const RIVAL_RANGE := 30.0      # m: a rival hunter this close makes it a fight
const FIGHT_GRACE := 1.0       # s after a rival comes into range before the line may show

static func seen_key(k: ArchKit) -> String:
	return "recast_" + k.id

static func line(open: Array) -> String:
	return "Press %s again to %s" % [Settings.key_cap(String(open[0])), String(open[1])]

## Every step for the local hunter's kit (ArchKit.tick): the line, once, when its window is open and no fight
## has just begun.
static func track(k: ArchKit) -> void:
	var seen: Dictionary = Save.d["tutorial"]
	if k.m.hud == null or seen.get(seen_key(k), false) or not Settings.get_v("tips"):
		return
	var open := k.recast_open()
	var near := _rival_near(k)
	if not near:
		k.rival_since = -1.0
	elif k.rival_since < 0.0:
		k.rival_since = k.m.time
	if open.is_empty() or (near and k.m.time - k.rival_since < FIGHT_GRACE):
		return
	seen[seen_key(k)] = true
	k.m.hud.tip(line(open))

static func _rival_near(k: ArchKit) -> bool:
	for o in k.m.hunters:
		if o.team != k.h.team and o.hittable() and not o.downed and o.pos.distance_to(k.h.pos) <= RIVAL_RANGE:
			return true
	return false
