class_name HunterNet
extends RefCounted
## Extra hunter fields in the "st" snapshot that the HUD shows to everyone: the run level (the badge
## on the overhead plate, HudPlate.level_badge) and the seconds of resurrection sickness left (its
## status icon). Appended as tagged pairs at the very end of the hunter row (after KinNet's fields)
## so they never shift anything already there.

const TAG := "lv"
const TAG_SICK := "sk"   # seconds of resurrection sickness left, for the plate and the squad row

static func extra(h: Hunter) -> Array:
	return [TAG, h.lvl, TAG_SICK, snappedf(h.sick_t, 0.1)]

static func apply(h: Hunter, it: Array) -> void:
	var n := it.size()
	if n >= 4 and it[n - 4] == TAG and it[n - 2] == TAG_SICK:
		h.lvl = maxi(1, int(it[n - 3]))
		h.sick_t = float(it[n - 1])
