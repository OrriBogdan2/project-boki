class_name HunterNet
extends RefCounted
## Extra hunter fields in the "st" snapshot that every game shows: the run level, so every player sees every
## hunter's level on their overhead plate (HudPlate.level_badge) and the badge pulses when it goes up, and the
## move its body makes on hazard ground (HazardMoves: swimming, no footing on ice), which only the owner can
## tell. Appended as tagged pairs at the very end of the hunter row (after GripNet's fields) so they never
## shift anything already there; a row without them is ignored.

const TAG := "lv"
const TAG_MOVE := "hz"

static func extra(h: Hunter) -> Array:
	return [TAG, h.lvl, TAG_MOVE, HazardMoves.of(h)]

static func apply(h: Hunter, it: Array) -> void:
	var i := it.rfind(TAG)
	if i >= 0 and i == it.size() - 4:
		h.lvl = maxi(1, int(it[i + 1]))
	if it.rfind(TAG_MOVE) == it.size() - 2:
		h.set_meta(HazardMoves.META, int(it[it.size() - 1]))
