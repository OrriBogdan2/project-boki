class_name HeroUlt
extends RefCounted
## The hero's own ultimate on X (the "hunter_ult" action, rebindable). It unlocks at the level in the
## archetype's "x" data and runs on its own cooldown, separate from the Boki Merge on R. ArchKit.use_x()
## routes the press here; a kit builds its ult in ArchKit.cast_ult() (and ult_recast() for a press while
## it runs). Landing it charges the Boki bond through landed() and from_ult(), never the cast alone.

const LOCKED_TOAST_S := 1.0       # s between two "unlocks at level N" toasts, so a held key doesn't spam
## Stub only, until KinBond.from_ult lands (branch ultbond): the amounts the main session announced for
## rules/boki_system.json bond_from_ult (a reserved file), as fractions of a full meter.
const STUB_FROM_ULT := {"hit": 0.6, "knock": 0.7, "kill": 0.8}

static var paid_total := 0.0      # (tests) bond the stub added for ults this run
static var _kin_bond: Script = null
static var _looked := false

## The X press: a recast while the ult runs, else the level gate, the cooldown, then the kit's cast.
static func use(k: ArchKit) -> void:
	if k.x_def().is_empty():
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
	k.st["ult_bond_best"] = 0.0       # a new cast: its best bond event starts over
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

## The ult connected with `target`: an enemy hunter it hit, knocked or killed fills the Boki bond.
static func landed(k: ArchKit, target: Ent) -> void:
	if not (target is Hunter) or target.team == k.h.team:
		return
	var kind := "hit"
	if target.dead:
		kind = "kill"
	elif (target as Hunter).downed:
		kind = "knock"
	from_ult(k, kind)

## Bond for an ult that landed ("hit", "knock" or "kill"; the best event of a cast counts). The main
## session's KinBond.from_ult(h, kind) does it once it ships; until then the stub pays the same announced
## amounts through Bond.add, topping up to the cast's best event.
static func from_ult(k: ArchKit, kind: String) -> void:
	var hook := _bond_hook()
	if hook != null:
		hook.call("from_ult", k.h, kind)
		return
	var amount := float(STUB_FROM_ULT.get(kind, 0.0))
	var best := float(k.st.get("ult_bond_best", 0.0))
	if amount <= best:
		return
	k.st["ult_bond_best"] = amount
	paid_total += amount - best
	Bond.add(k.h, amount - best)

## The HUD's X slot data, the same keys Hunter.slot_info uses.
static func slot_info(k: ArchKit) -> Dictionary:
	var xd := k.x_def()
	var cd_left := float(k.cd["x"])
	return {
		"name": String(xd.get("name", "")), "short": String(xd.get("short", "")), "icon": String(xd.get("icon", "")),
		"col": k.col_of(xd), "desc": String(xd.get("desc", "")), "cd": cd_left, "cd_max": cooldown(k),
		"charges": 1 if cd_left <= 0.0 else 0, "max_charges": 1, "verb": "x", "level": 1,
		"ready": cd_left <= 0.0 and unlocked(k), "locked": not unlocked(k), "unlock": unlock_level(k),
		"up": k.ult_running(),
	}

static func _deny_locked(k: ArchKit) -> void:
	k.h._ab_feedback("x", "deny")
	if not k.h.is_local() or k.m.hud == null:
		return
	if k.m.time - float(k.st.get("x_toast", -9.0)) < LOCKED_TOAST_S:
		return
	k.st["x_toast"] = k.m.time
	var label := "%s unlocks at level %d" % [String(k.x_def().get("name", "Ultimate")), unlock_level(k)]
	k.m.hud.toast_small(label, k.col_of(k.x_def()))

## The main session's KinBond.from_ult(h, kind), if this build has it (looked up once).
static func _bond_hook() -> Script:
	if _looked:
		return _kin_bond
	_looked = true
	for c in ProjectSettings.get_global_class_list():
		if String(c["class"]) != "KinBond":
			continue
		var s: Script = load(String(c["path"]))
		for meth in s.get_script_method_list():
			if String(meth["name"]) == "from_ult" and (meth["args"] as Array).size() == 2:
				_kin_bond = s
	return _kin_bond
