class_name HeroUlt
extends RefCounted
## The hunter's own ultimate on X (action "hunter_ult"): the level gate, its cooldown (ArchKit.cd["x"]),
## the aim-on-hold path for ults that pick a target, and the bond payout when it lands.
## The kit's half is ArchKit.cast_ult / ult_recast / ult_running / ult_aims / ult_aim_tick and its "x" data.
## Merge stays on R (KinMerge); the two never share a key or a resource.

const AIM_HOLD_MAX := 4.0      # s: an aim held this long casts by itself


## The X press: a recast while it runs, else the gates (level, cooldown, busy, merged), then the cast or
## the aim (kits whose ult picks a target cast on the release).
static func press(h: Hunter) -> void:
	var k: ArchKit = h.ak
	if k == null or k.x_def().is_empty():
		return
	if k.ult_running():
		k.ult_recast()
		return
	if not can_cast(h):
		_deny(h)
		return
	if k.ult_aims():
		k.x_aim = true
		k.x_aim_t = 0.0
		return
	fire(h)


## Level, cooldown and state gates. A merged form owns the buttons, so X waits for the split.
static func can_cast(h: Hunter) -> bool:
	var k: ArchKit = h.ak
	if k == null or k.x_def().is_empty() or k.busy() or KinMerge.active(h):
		return false
	if h.box_reviving() or not h.stomp.is_empty():
		return false
	return h.lvl >= unlock_level(h) and float(k.cd["x"]) <= 0.0


static func unlock_level(h: Hunter) -> int:
	return int(h.ak.x_def().get("unlock", 6))


static func cooldown(h: Hunter) -> float:
	return float(h.ak.x_def().get("cooldown", 45.0))


## Casts it now (the kit says no when there is no valid target). The cooldown starts on the cast.
static func fire(h: Hunter) -> bool:
	var k: ArchKit = h.ak
	k.x_aim = false
	AimKit.hide(h, "x")
	if not can_cast(h) or not k.cast_ult():
		_deny(h)
		return false
	k.cd["x"] = cooldown(h)
	h.used["x"] = int(h.used.get("x", 0)) + 1
	h.cast_at = h.m.time
	h._ab_feedback("x", "cast")
	CombatBus.ability_used.emit(h, k.id + "_x", "hunter_ult")
	return true


## Every step while X is held to aim: the kit's preview, and the cast once X is let go.
static func aim_tick(k: ArchKit, dt: float) -> void:
	var h := k.h
	k.x_aim_t += dt
	if not can_cast(h):
		k.x_aim = false
		AimKit.hide(h, "x")
		return
	k.ult_aim_tick()
	if not bool(h.inp.get("hult_down", false)) or k.x_aim_t >= AIM_HOLD_MAX:
		fire(h)


static func _deny(h: Hunter) -> void:
	h._ab_feedback("x", "deny")
	if not h.is_local() or h.m.hud == null:
		return
	if h.lvl < unlock_level(h):
		h.m.hud.toast_small("Ultimate unlocks at level %d" % unlock_level(h), Color("a2a8bb"))


# ------------------------------------------------------------------ the bond
## content/rules/hero_ult.json: per hero, how much of the bond meter a landed ult pays.
static func rules() -> Dictionary:
	return Content.rules("hero_ult")


static func bond_of(hero_id: String) -> Dictionary:
	return (rules().get("bond", {}) as Dictionary).get(hero_id, {})


## Fills h's bond meter by `amount` (0..1 of the bar) because the ult landed. Calls the main session's
## public bond hook (KinBond.add(h, amount, reason)) when it exists, else the meter's own Bond.add.
static func bond(h: Hunter, amount: float, reason: String) -> void:
	if h == null or amount <= 0.0:
		return
	if h.ak != null:
		h.ak.x_bond += amount
	var hook := _bond_hook()
	if hook != null:
		hook.call("add", h, amount, reason)
	else:
		Bond.add(h, amount)


## Guarded stub: the KinBond class ships with the main session's ultbond branch. Until then this is null.
static func _bond_hook() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if String(c["class"]) == "KinBond":
			var s: Script = load(String(c["path"]))
			for mt in s.get_script_method_list():
				if String(mt["name"]) == "add":
					return s
	return null
