class_name HeroUlt
extends RefCounted
## The hero's own ultimate (the "hunter_ult" action, rebindable). It unlocks at the level in the archetype's
## "x" data and runs on its own cooldown, separate from the Boki Merge. HunterKeys.ult_pressed calls
## ArchKit.cast_ult(), which routes here; a kit builds its ult in start_ult() (and ult_recast() for a press
## while it runs). Landing it charges the Boki bond through landed() and KinBond.from_ult, never the cast alone.

static var paid_total := 0.0      # (tests) bond the ults added this run (KinBond.from_ult's returns)

## The X press (HunterKeys.ult_pressed -> ArchKit.cast_ult): a recast while the ult runs, else the level
## gate, the cooldown, then the kit's start_ult(). True when the ult went off (or a recast was handled).
static func use(k: ArchKit) -> bool:
	if k.x_def().is_empty():
		return false
	if k.ult_running() and k.ult_recast():
		return true
	if k.busy() or KinMerge.active(k.h) or not unlocked(k):
		return false
	if float(k.cd["x"]) > 0.0 or not k.start_ult():
		return false
	k.cd["x"] = cooldown(k)
	var casts := int(k.st.get("ult_casts", 0)) + 1
	k.st["ult_casts"] = casts
	k.h.used["x"] = int(k.h.used.get("x", 0)) + 1
	k.h._ab_feedback("x", "cast")
	CombatBus.ability_used.emit(k.h, k.id + "_x", "ultimate")
	return true

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

## Bond for an ult that landed ("hit", "knock" or "kill"): KinBond pays the best event of each cast once.
static func from_ult(k: ArchKit, kind: String) -> void:
	var cast_id := "%d.x%d" % [k.h.get_instance_id(), int(k.st.get("ult_casts", 0))]
	paid_total += KinBond.from_ult(k.h, kind, cast_id)

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
