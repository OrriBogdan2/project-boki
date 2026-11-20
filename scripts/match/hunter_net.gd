class_name HunterNet
extends RefCounted
## Extra hunter fields in the "st" snapshot that the HUD shows to everyone: the run level, so every
## player sees every hunter's level on their overhead plate (HudPlate.level_badge) and the badge
## pulses when it goes up; Meeko's Hearth Call target and seconds left, so the ally shows the
## protection bar (ChannelBar); and the seconds of resurrection sickness left (its status icon).
## Appended as a tagged tail at the very end of the hunter row (after KinNet's fields) so it never
## shifts anything already there; a row without it is ignored.

const TAG := "lv"
const CHAN_TAG := "ch"  # then the channel's target nid ("" none) and its seconds left (ChannelBar)
const SICK_TAG := "sk"  # then the seconds of resurrection sickness left (HudPlate.statuses)
const TAIL := 7  # fields: TAG, level, SICK_TAG, sick seconds, CHAN_TAG, target, left


static func extra(h: Hunter) -> Array:
	var ch := ChannelBar.read(h)
	return [TAG, h.lvl, SICK_TAG, snappedf(h.sick_t, 0.1), CHAN_TAG, ch[0], snappedf(maxf(0.0, ch[1]), 0.05)]


static func apply(h: Hunter, it: Array) -> void:
	var i := it.size() - TAIL
	if i < 0 or it[i] != TAG or it[i + 2] != SICK_TAG or it[i + 4] != CHAN_TAG:
		return
	h.lvl = maxi(1, int(it[i + 1]))
	h.sick_t = float(it[i + 3])
	ChannelBar.store(h, String(it[i + 5]), float(it[i + 6]))
