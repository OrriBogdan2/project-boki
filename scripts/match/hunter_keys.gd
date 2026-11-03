class_name HunterKeys
extends RefCounted
## What the reload key (R) and the hunter-ultimate key (X) do for a hunter. Merge (T) is KinMerge.press.

const UNLOCK_TOAST_EVERY := 4.0      # s: the "unlocks at level 6" line shows at most this often

## R: reload by hand. Ignored when you cannot act (stunned, downed, riding, dropping, in the merge transformation)
## and while a hold or channel is running (a charge-up, a held roar). A weapon with no magazine (melee) answers
## with the deny tick; a full or reloading weapon does nothing, silently. Auto-reload after a short idle stays.
static func reload_pressed(h: Hunter) -> void:
	if h.downed or h.stun_t > 0.0 or h.riding or h.dropping or KinMerge.transforming(h):
		return
	if h.reload_t > 0.0 or _channeling(h):
		return
	if bool(h.wpn.get("melee", false)) or int(h.wpn.get("mag", 0)) <= 0:
		h._ab_feedback("reload", "deny")
		return
	h.start_reload()

static func _channeling(h: Hunter) -> bool:
	if not h.abil_charge.is_empty() or not h.charge.is_empty():
		return true
	if h.ak != null and h.ak.busy():
		return true
	return bool(h.inp.get("fire", false)) and String(h.wpn.get("id", "")) == "flamethrower"

## X: the hunter's own ultimate. Opens at the same level as Merge (Hunter.ULT_AT[0]). No hero has one yet:
## ArchKit.cast_ult() is the hook a kit overrides, and says whether anything went off.
static func ult_pressed(h: Hunter) -> bool:
	if h == null or h.downed or h.out:
		return false
	if h.ak != null and h.ak.flow.take_x():
		return true          # pressed mid-dash: DashFlow plays it when the dash ends
	if h.lvl < int(Hunter.ULT_AT[0]):
		_deny(h)
		if h.is_local() and h.m.hud and _toast_due(h):
			h.m.hud.toast("Hunter ultimate unlocks at level %d" % int(Hunter.ULT_AT[0]), Color("a2a8bb"))
		return false
	if h.ak == null or not h.ak.cast_ult():
		_deny(h)
		return false
	return true

static func _toast_due(h: Hunter) -> bool:
	var last := float(h.get_meta("ult_toast_at", -99.0))
	if h.m.time - last < UNLOCK_TOAST_EVERY:
		return false
	h.set_meta("ult_toast_at", h.m.time)
	return true

## A press that did nothing: the soft warning sound (the hunter ultimate has no slot to shake).
static func _deny(h: Hunter) -> void:
	if h.is_local():
		h.m.sfx("warn", null, -16.0, 1.6)
