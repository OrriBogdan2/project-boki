class_name HunterKeys
extends RefCounted
## What the reload key (R) and the hunter-ultimate key (X) do for a hunter. Merge (T) is KinMerge.press.

## R: reload by hand. A weapon with no magazine (melee) answers with the deny tick; a full or reloading weapon
## does nothing. Auto-reload after a short idle (Hunter._physics_step) stays as the fallback.
static func reload_pressed(h: Hunter) -> void:
	if h.downed or h.reload_t > 0.0:
		return
	if bool(h.wpn.get("melee", false)) or int(h.wpn.get("mag", 0)) <= 0:
		h._ab_feedback("reload", "deny")
		return
	h.start_reload()

## X: the hunter's own ultimate. Opens at the same level as Merge (Hunter.ULT_AT[0]). No hero has one yet:
## ArchKit.cast_ult() is the hook a kit overrides, and says whether anything went off.
static func ult_pressed(h: Hunter) -> bool:
	if h == null or h.downed or h.out:
		return false
	if h.lvl < int(Hunter.ULT_AT[0]):
		h._ab_feedback("hunter_ult", "deny")
		if h.is_local() and h.m.hud:
			h.m.hud.toast("Hunter ultimate unlocks at level %d" % int(Hunter.ULT_AT[0]), Color("a2a8bb"))
		return false
	if h.ak == null or not h.ak.cast_ult():
		h._ab_feedback("hunter_ult", "deny")
		return false
	return true
