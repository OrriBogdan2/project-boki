class_name HunterNet
extends RefCounted
## Extra hunter fields in the "st" snapshot that the HUD shows to everyone: the run level, so every
## player sees every hunter's level on their overhead plate (HudPlate.level_badge) and the badge
## pulses when it goes up; and Meeko's Hearth Call target and seconds left, so the ally shows the
## protection bar (ChannelBar); and the Boki slots in use (claimed, stolen: Capture.slots), so a teammate's kin
## can point at a hunter with room. Appended as a tagged tail at the very end of the hunter row (after
## KinNet's fields) so it never shifts anything already there; a row without it is ignored.

const TAG := "lv"
const SLOT_TAG := "sl"  # then the claimed and the stolen Boki in the slots (Capture.slots)
const CHAN_TAG := "ch"  # then the channel's target nid ("" none) and its seconds left (ChannelBar)
const TAIL := 8  # fields: TAG, level, SLOT_TAG, claimed, stolen, CHAN_TAG, target, left


static func extra(h: Hunter) -> Array:
	var ch := ChannelBar.read(h)
	var slots := Capture.slots(h)
	return [TAG, h.lvl, SLOT_TAG, slots[0], slots[1], CHAN_TAG, ch[0], snappedf(maxf(0.0, ch[1]), 0.05)]


static func apply(h: Hunter, it: Array) -> void:
	var i := it.size() - TAIL
	if i < 0 or it[i] != TAG or it[i + 2] != SLOT_TAG or it[i + 5] != CHAN_TAG:
		return
	h.lvl = maxi(1, int(it[i + 1]))
	h.set_meta("slots", [int(it[i + 3]), int(it[i + 4])])
	ChannelBar.store(h, String(it[i + 6]), float(it[i + 7]))
