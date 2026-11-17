class_name HunterNet
extends RefCounted
## Extra hunter fields in the "st" snapshot that the HUD shows to everyone: the run level, so every
## player sees every hunter's level on their overhead plate (HudPlate.level_badge) and the badge
## pulses when it goes up; and Meeko's Hearth Call target and seconds left, so the ally shows the
## protection bar (ChannelBar). Appended as a tagged tail at the very end of the hunter row (after
## KinNet's fields) so it never shifts anything already there; a row without it is ignored.

const TAG := "lv"
const CHAN_TAG := "ch"         # then the channel's target nid ("" none) and its seconds left (ChannelBar)
const TAIL := 5                # fields: TAG, level, CHAN_TAG, target, left

static func extra(h: Hunter) -> Array:
	var ch := ChannelBar.read(h)
	return [TAG, h.lvl, CHAN_TAG, ch[0], snappedf(maxf(0.0, ch[1]), 0.05)]

static func apply(h: Hunter, it: Array) -> void:
	var i := it.size() - TAIL
	if i < 0 or it[i] != TAG or it[i + 2] != CHAN_TAG:
		return
	h.lvl = maxi(1, int(it[i + 1]))
	ChannelBar.store(h, String(it[i + 3]), float(it[i + 4]))
