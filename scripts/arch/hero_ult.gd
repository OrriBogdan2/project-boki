class_name HeroUlt
extends RefCounted
## What a hero's own ultimate (the "hunter_ult" action) needs beyond main's route. HunterKeys.ult_pressed gates
## the level (Hunter.ULT_AT) and calls the kit's ArchKit.cast_ult(); a kit with an ult overrides cast_ult() as
## `HeroUlt.cast(self, <its start>)` and has_ult() as true. Here: the ult's own cooldown (cd["x"]), the recast
## while it runs, the HUD slot data, and the bond on a land (KinBond.from_ult, one id per cast), never the cast alone.

static var paid_total := 0.0      # (tests) bond the ults added this run (KinBond.from_ult's returns)

## The kit's cast_ult(): a recast while the ult runs, else its own cooldown, then `start` (the kit's own
## cast, true when it went off). True when the ult went off or a recast was handled.
static func cast(k: ArchKit, start: Callable) -> bool:
	if k.ult_running() and k.ult_recast():
		return true
	if k.busy() or KinMerge.active(k.h) or float(k.cd["x"]) > 0.0:
		return false
	if not bool(start.call()):
		return false
	k.cd["x"] = cooldown(k)
	k.st["ult_casts"] = int(k.st.get("ult_casts", 0)) + 1
	k.h.used["x"] = int(k.h.used.get("x", 0)) + 1
	k.h._ab_feedback("x", "cast")
	CombatBus.ability_used.emit(k.h, k.id + "_x", "ultimate")
	return true

## Is the ult open at this hunter's level (main's gate, Hunter.ULT_AT)?
static func unlocked(k: ArchKit) -> bool:
	return k.h.lvl >= unlock_level()

static func unlock_level() -> int:
	return int(Hunter.ULT_AT[0])

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
	var cast_id := "%s_%d" % [k.id, int(k.st.get("ult_casts", 0))]
	paid_total += KinBond.from_ult(k.h, kind, cast_id)

## The HUD's X slot data, the same keys Hunter.slot_info uses.
static func slot_info(k: ArchKit) -> Dictionary:
	var xd := k.x_def()
	var cd_left := float(k.cd["x"])
	return {
		"name": String(xd.get("name", "")), "short": String(xd.get("short", "")), "icon": String(xd.get("icon", "")),
		"col": k.col_of(xd), "desc": String(xd.get("desc", "")), "cd": cd_left, "cd_max": cooldown(k),
		"charges": 1 if cd_left <= 0.0 else 0, "max_charges": 1, "verb": "x", "level": 1,
		"ready": cd_left <= 0.0 and unlocked(k), "locked": not unlocked(k), "unlock": unlock_level(),
		"up": k.ult_running(),
	}
