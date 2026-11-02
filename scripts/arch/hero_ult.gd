class_name HeroUlt
extends RefCounted
## The hero's own ultimate on X (the "hunter_ult" action, rebindable). It unlocks at the level in the
## archetype's "x" data and runs on its own cooldown, separate from the Boki Merge on R. ArchKit.use_x()
## routes the press here; a kit builds its ult in ArchKit.cast_ult() (and ult_recast() for a press while
## it runs). Landing it charges the Boki bond through pay_bond, never the cast alone.

const LOCKED_TOAST_S := 1.0       # s between two "unlocks at level N" toasts, so a held key doesn't spam

static var paid_total := 0.0          # (tests) bond added by ults this run
static var _kin_bond: Script = null
static var _looked := false

## The X press: a recast while the ult runs, else the level gate, the cooldown, then the kit's cast.
static func use(k: ArchKit) -> void:
	var xd := k.x_def()
	if xd.is_empty():
		return
	if k.ult_running() and k.ult_recast():
		return
	if k.busy() or KinMerge.active(k.h):
		k.h._ab_feedback("x", "deny")
		return
	if not unlocked(k):
		_deny_locked(k)
		return
	if float(k.cd["x"]) > 0.0 or not k.cast_ult():
		k.h._ab_feedback("x", "deny")
		return
	k.cd["x"] = cooldown(k)
	k.h.used["x"] = int(k.h.used.get("x", 0)) + 1
	k.h._ab_feedback("x", "cast")
	CombatBus.ability_used.emit(k.h, k.id + "_x", "ultimate")

## Is the ult open at this hunter's level?
static func unlocked(k: ArchKit) -> bool:
	return k.h.lvl >= unlock_level(k)

static func unlock_level(k: ArchKit) -> int:
	return int(k.x_def().get("unlock", 6))

static func cooldown(k: ArchKit) -> float:
	return float(k.x_def().get("cooldown", 30.0))

## This hero's bond rules for the ult (content/rules/bond.json "ult").
static func bond_rules(arch_id: String) -> Dictionary:
	return (Bond.rules().get("ult", {}) as Dictionary).get(arch_id, {})

## Adds bond for an ult that landed. The main session's public hook (KinBond.add(h, amount, reason)) is
## used once it ships; until then this falls back to the meter's own Bond.add.
static func pay_bond(h: Hunter, amount: float, reason: String) -> void:
	if amount <= 0.0:
		return
	paid_total += amount
	var hook := _bond_hook()
	if hook != null:
		hook.call("add", h, amount, reason)
	else:
		Bond.add(h, amount)

## The HUD's X slot data, the same keys Hunter.slot_info uses.
static func slot_info(k: ArchKit) -> Dictionary:
	var xd := k.x_def()
	var cd_left := float(k.cd["x"])
	return {"name": String(xd.get("name", "")), "short": String(xd.get("short", "")), "icon": String(xd.get("icon", "")),
		"col": k.col_of(xd), "desc": String(xd.get("desc", "")), "cd": cd_left, "cd_max": cooldown(k),
		"charges": 1 if cd_left <= 0.0 else 0, "max_charges": 1, "verb": "x", "level": 1,
		"ready": cd_left <= 0.0 and unlocked(k), "locked": not unlocked(k), "unlock": unlock_level(k), "up": k.ult_running()}

static func _deny_locked(k: ArchKit) -> void:
	k.h._ab_feedback("x", "deny")
	if not k.h.is_local() or k.m.hud == null:
		return
	if k.m.time - float(k.st.get("x_toast", -9.0)) < LOCKED_TOAST_S:
		return
	k.st["x_toast"] = k.m.time
	k.m.hud.toast_small("%s unlocks at level %d" % [String(k.x_def().get("name", "Ultimate")), unlock_level(k)], k.col_of(k.x_def()))

## The main session's KinBond.add(h, amount, reason), if this build has it (looked up once).
static func _bond_hook() -> Script:
	if _looked:
		return _kin_bond
	_looked = true
	for c in ProjectSettings.get_global_class_list():
		if String(c["class"]) != "KinBond":
			continue
		var s: Script = load(String(c["path"]))
		for meth in s.get_script_method_list():
			if String(meth["name"]) == "add" and (meth["args"] as Array).size() == 3:
				_kin_bond = s
	return _kin_bond
