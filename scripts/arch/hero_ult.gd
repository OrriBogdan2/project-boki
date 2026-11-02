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
	k.x_bond_kind = ""
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
## Until the main session's ultbond branch lands: what KinBond.from_ult pays per kind when
## rules/boki_system.json has no bond_from_ult yet (the numbers main announced).
const BOND_FALLBACK := {"hit": 0.6, "knock": 0.7, "kill": 0.8}


## The ult landed: pays the bond for its best event this cast ("hit", "knock" or "kill"). Calls the
## main session's KinBond.from_ult(h, kind) when it exists; until then this guarded stub pays the same
## amounts from rules/boki_system.json bond_from_ult through Bond.add. Swap it out once ultbond lands.
static func bond(h: Hunter, kind: String) -> void:
	if h == null or not BOND_FALLBACK.has(kind):
		return
	var hook := _kin_bond()
	if hook != null:
		hook.call("from_ult", h, kind)
	else:
		var amounts: Dictionary = Content.rules("boki_system").get("bond_from_ult", BOND_FALLBACK)
		Bond.add(h, float(amounts.get(kind, BOND_FALLBACK[kind])))
	if h.ak != null:
		h.ak.x_bond_kind = kind


## The KinBond script if the ultbond branch is in, else null.
static func _kin_bond() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if String(c["class"]) == "KinBond":
			var s: Script = load(String(c["path"]))
			for mt in s.get_script_method_list():
				if String(mt["name"]) == "from_ult":
					return s
	return null
