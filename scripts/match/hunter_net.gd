class_name HunterNet
extends RefCounted
## Extra hunter fields in the "st" snapshot that the HUD shows to everyone: the run level, so every
## player sees every hunter's level on their overhead plate (HudPlate.level_badge) and the badge
## pulses when it goes up. Appended as a tagged pair at the very end of the hunter row (after
## KinNet's fields) so it never shifts anything already there; an older row without it is ignored.

const TAG := "lv"

static func extra(h: Hunter) -> Array:
	return [TAG, h.lvl]

static func apply(h: Hunter, it: Array) -> void:
	var i := it.rfind(TAG)
	if i >= 0 and i == it.size() - 2:
		h.lvl = maxi(1, int(it[i + 1]))
