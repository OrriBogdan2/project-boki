class_name HunterKeys
extends RefCounted
## What the hunter-ultimate key (R) does for a hunter. Fuse (X) is KinMerge.press.

## R: the hunter's own ultimate. Opens at the same level as Merge (Hunter.ULT_AT[0]). No hero has one yet:
## ArchKit.cast_ult() is the hook a kit overrides, and says whether anything went off.
static func ult_pressed(h: Hunter) -> bool:
	if h == null or h.downed or h.out:
		return false
	if h.ak != null and h.ak.flow.take_x():
		return true          # pressed mid-dash: DashFlow plays it when the dash ends
	if h.lvl < int(Hunter.ULT_AT[0]):
		_deny(h)
		if h.is_local() and h.m.hud:
			h.m.hud.toast_small("Ultimate at level %d" % int(Hunter.ULT_AT[0]), Color("a2a8bb"))
		return false
	if h.ak == null or not h.ak.cast_ult():
		_deny(h)
		return false
	return true

## A press that did nothing: the X tile shakes red with the soft warning sound (HunterUltTile).
static func _deny(h: Hunter) -> void:
	h._ab_feedback("x", "deny")
