class_name HunterNet
extends RefCounted
## Extra hunter fields in the "st" snapshot that the HUD shows to everyone: the run level, so every
## player sees every hunter's level on their overhead plate (HudPlate.level_badge) and the badge
## pulses when it goes up. Appended as a tagged pair at the very end of the hunter row (after
## KinNet's fields) so it never shifts anything already there; an older row without it is ignored.
## The row ends with the level and the Boki slots in use (claimed, stolen: Capture.slots), so a teammate's
## kin can point at one with room.

const TAG := "lv"

static func extra(h: Hunter) -> Array:
	var sl := Capture.slots(h)
	return [TAG, h.lvl, sl[0], sl[1]]

static func apply(h: Hunter, it: Array) -> void:
	var i := it.rfind(TAG)
	if i >= 0 and i == it.size() - 4:
		h.lvl = maxi(1, int(it[i + 1]))
		h.set_meta("slots", [int(it[i + 2]), int(it[i + 3])])
