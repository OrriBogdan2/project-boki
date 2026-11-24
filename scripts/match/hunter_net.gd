class_name HunterNet
extends RefCounted
## Extra hunter fields in the "st" snapshot that the HUD shows to everyone: the run level, so every
## player sees every hunter's level on their overhead plate (HudPlate.level_badge) and the badge
## pulses when it goes up; Meeko's Hearth Call target and seconds left, so the ally shows the
## protection bar (ChannelBar); the seconds of resurrection sickness left (its status icon); Grimble's reaching arm
## (DredgeKit.net_reach), which only the caster's kit runs; and the move its body makes on hazard ground (HazardMoves:
## swimming, no footing on ice), which only its owner can tell. Appended as a tagged tail at the very end of the hunter
## row (after KinNet's fields) so it never shifts anything already there; a row without it is ignored.

const TAG := "lv"
const SICK_TAG := "sk"  # then the seconds of resurrection sickness left (HudPlate.statuses)
const CHAN_TAG := "ch"  # then the channel's target nid ("" none) and its seconds left (ChannelBar)
const REACH_TAG := "rch"  # then the reach wire (DredgeKit.net_reach; [] for every other Hunter)
const MOVE_TAG := "hz"  # then the HazardMoves move (an enum int)
const TAIL := 11  # fields: TAG, level, SICK_TAG, sick seconds, CHAN_TAG, target, left, REACH_TAG, reach, MOVE_TAG, move


static func extra(h: Hunter) -> Array:
	var ch := ChannelBar.read(h)
	var reach: Array = (h.ak as DredgeKit).net_reach() if h.ak is DredgeKit else []
	var left := snappedf(maxf(0.0, ch[1]), 0.05)
	var sick := snappedf(h.sick_t, 0.1)
	return [TAG, h.lvl, SICK_TAG, sick, CHAN_TAG, ch[0], left, REACH_TAG, reach, MOVE_TAG, HazardMoves.of(h)]


static func apply(h: Hunter, it: Array) -> void:
	var i := it.size() - TAIL
	var tags_ok: bool = i >= 0 and it[i] == TAG and it[i + 2] == SICK_TAG and it[i + 4] == CHAN_TAG
	if not tags_ok or it[i + 7] != REACH_TAG or it[i + 9] != MOVE_TAG:
		return
	h.lvl = maxi(1, int(it[i + 1]))
	h.sick_t = float(it[i + 3])
	ChannelBar.store(h, String(it[i + 5]), float(it[i + 6]))
	if h.ak is DredgeKit and it[i + 8] is Array:
		(h.ak as DredgeKit).net_reach_in(it[i + 8])
	h.set_meta(HazardMoves.META, int(it[i + 10]))
