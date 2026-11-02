class_name UltSlot
extends RefCounted
## X (the hunter_ult action): a hero's own ultimate (the "x" block of content/archetypes/<id>.json),
## separate from R (the Boki Merge). It unlocks at the hero's "unlock" level and runs on its own cooldown
## (ArchKit.cd["x"]); the kit's cast_ult() does the rest. Kits call from_ult() when it connects, never on
## the cast, so the bond meter fills only on a land.

const BOND_HOOK := "KinBond"     # the bond meter's public API (branch ultbond); until it ships, Bond.add stands in
## The stand-in's amounts when boki_system.json has no "bond_from_ult" yet (the values announced for it).
const FROM_ULT := {"hit": 0.6, "knock": 0.7, "kill": 0.8}

static var _hook: Script = null
static var _hook_looked := false

## The hero's X data ({} when the hero has no ult on X).
static func def(k: ArchKit) -> Dictionary:
	return k.d.get("x", {})

## Is the hunter's level high enough for X?
static func unlocked(k: ArchKit) -> bool:
	return int(k.h.lvl) >= int(def(k).get("unlock", 6))

## The X press: level gate, cooldown, merge and crowd-control checks, then the kit's cast_ult(). The
## cooldown starts on a cast that goes off.
static func press(k: ArchKit) -> void:
	var xd := def(k)
	if xd.is_empty():
		return
	var h := k.h
	if k.busy() or KinMerge.active(h) or KinMerge.transforming(h):
		h._ab_feedback("x", "deny")
		return
	if not unlocked(k):
		h._ab_feedback("x", "deny")
		if h.is_local() and k.m.hud:
			k.m.hud.toast_small("%s unlocks at level %d" % [String(xd["name"]), int(xd.get("unlock", 6))], k.col_of(xd))
		return
	if float(k.cd.get("x", 0.0)) > 0.0 or not k.cast_ult():
		h._ab_feedback("x", "deny")
		return
	k.cd["x"] = float(xd.get("cooldown", 36.0))
	k.st["ult_bond"] = 0.0
	k.st["ult_events"] = []
	h.used["x"] = int(h.used.get("x", 0)) + 1
	h._ab_feedback("x", "cast")
	CombatBus.ability_used.emit(h, k.id + "_x", "ultimate")

## The ult hit a rival hunter: bond for the hit, then for a knock or a kill if the hit took them down.
static func on_land(h: Hunter, foe: Hunter) -> void:
	from_ult(h, "hit")
	h.m.later(0.05, func():
		if not is_instance_valid(h) or not is_instance_valid(foe):
			return
		if foe.dead:
			from_ult(h, "kill")
		elif foe.downed:
			from_ult(h, "knock"))

## Bond for a landed ult: `kind` is "hit", "knock" or "kill", and only the best event of a cast pays.
## Calls the bond meter's public hook, KinBond.from_ult, when this build has it. Until then the stand-in
## pays the same amounts (boki_system.json "bond_from_ult") through Bond.add.
static func from_ult(h: Hunter, kind: String) -> void:
	(h.ak.st.get_or_add("ult_events", []) as Array).append(kind)
	var hook := _bond_hook()
	if hook != null:
		hook.call("from_ult", h, kind)
		return
	var amounts: Dictionary = Content.rules("boki_system").get("bond_from_ult", FROM_ULT)
	var want := float(amounts.get(kind, 0.0))
	var best := float(h.ak.st.get("ult_bond", 0.0))
	if want <= best:
		return
	h.ak.st["ult_bond"] = want
	Bond.add(h, want - best)

## The KinBond script when this build has one with from_ult(), looked up once by its global class name.
static func _bond_hook() -> Script:
	if _hook_looked:
		return _hook
	_hook_looked = true
	for c in ProjectSettings.get_global_class_list():
		if String(c["class"]) != BOND_HOOK:
			continue
		var s: Script = load(String(c["path"]))
		for fn in s.get_script_method_list():
			if String(fn["name"]) == "from_ult":
				_hook = s
	return _hook
