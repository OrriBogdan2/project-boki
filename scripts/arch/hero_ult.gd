class_name HeroUlt
extends RefCounted
## The hero's own ultimate on X: the parts main's X path (HunterKeys.ult_pressed: the level gate, then
## ArchKit.cast_ult) doesn't carry. A kit's cast_ult() returns HeroUlt.press(self, start): a recast while the ult
## runs, else the ult's own cooldown (cd["x"]) and a fresh cast id. Landing it charges the Boki bond through
## landed(), never the cast alone (KinBond.from_ult: the best event of a cast counts).

static var _casts := 0            # cast ids are "<hero>_<n>", one per cast, unique in the run

## The X press after main's level gate: a recast while it runs (ult_recast), else nothing while busy, merged or
## cooling down, else `start` (the kit's own cast). True when the press did something; main denies on false.
static func press(k: ArchKit, start: Callable) -> bool:
	if k.x_def().is_empty():
		return false
	if k.ult_running():
		return k.ult_recast()
	if k.busy() or KinMerge.active(k.h) or float(k.cd["x"]) > 0.0:
		return false
	if not bool(start.call()):
		return false
	_casts += 1
	k.cd["x"] = cooldown(k)
	k.st["ult_cast"] = "%s_%d" % [k.id, _casts]
	k.h.used["x"] = int(k.h.used.get("x", 0)) + 1
	k.h._ab_feedback("x", "cast")
	CombatBus.ability_used.emit(k.h, k.id + "_x", "ultimate")
	return true

## Can a bot press X now (main's level gate and the ult's own cooldown)?
static func ready(k: ArchKit) -> bool:
	return not k.x_def().is_empty() and k.h.lvl >= int(Hunter.ULT_AT[0]) and float(k.cd["x"]) <= 0.0

## Seconds the ult rests. A kit without x.per_rank takes the shared 10% step per R rank instead.
static func cooldown(k: ArchKit) -> float:
	var xd := k.x_def()
	var base := float(xd.get("cooldown", 30.0))
	return base if xd.has("per_rank") else base * k.h.rank_cd_k("ult")

## The ult's data at R rank `r`: x.per_rank holds, per key, what ranks 2 and 3 each add in the key's own
## unit (the source's R tiers, docs/decisions/0022-ult-ranks.md), e.g. {"cooldown": [-5, -5], "time": [2.5, 2.5]}.
static func ranked(xd: Dictionary, r: int) -> Dictionary:
	var per: Dictionary = xd.get("per_rank", {})
	if r <= 1 or per.is_empty():
		return xd
	var out := xd.duplicate()
	for key in per:
		var steps: Array = per[key]
		for i in mini(r - 1, steps.size()):
			out[key] = float(out[key]) + float(steps[i])
	return out

## The id of the cast in flight ("" before the first).
static func cast_id(k: ArchKit) -> String:
	return String(k.st.get("ult_cast", ""))

## The ult connected with `target`: an enemy hunter it hit, knocked or killed fills the Boki bond.
static func landed(k: ArchKit, target: Ent) -> void:
	if not (target is Hunter) or target.team == k.h.team or cast_id(k) == "":
		return
	var kind := "hit"
	if target.dead:
		kind = "kill"
	elif (target as Hunter).downed:
		kind = "knock"
	KinBond.from_ult(k.h, kind, cast_id(k))

## The ult's slot data in the keys Hunter.slot_info uses (for a HUD tile that shows its cooldown).
static func slot_info(k: ArchKit) -> Dictionary:
	var xd := k.x_def()
	var cd_left := float(k.cd["x"])
	var unlock := int(Hunter.ULT_AT[0])
	return {
		"name": String(xd.get("name", "")), "short": String(xd.get("short", "")), "icon": String(xd.get("icon", "")),
		"col": k.col_of(xd), "desc": String(xd.get("desc", "")), "cd": cd_left, "cd_max": cooldown(k),
		"charges": 1 if cd_left <= 0.0 else 0, "max_charges": 1, "verb": "x", "level": k.rank("ult"),
		"ready": cd_left <= 0.0 and k.h.lvl >= unlock and not KinMerge.active(k.h),
		"locked": k.h.lvl < unlock, "unlock": unlock,
		"up": k.ult_running(),
	}
