extends RefCounted
## The burst cap for hero ultimates (SERVER_UPDATE6): an ult that fully lands, then straight into the Boki
## merge and the merged form's ultimate, must leave a full-health light hunter (no armour, the lowest health
## in the game) standing. Used by the hero combo checks; `land` plays the ult out on the target.

const MERGE_KIN := "zephyrak"     # its form's ultimate strikes every foe in range at once (no aim to miss)
const TEST_LEVEL := 10            # the top of quiet level growth: the ult hits as hard as it ever does

## Runs it and returns {ult, total, alive, merged}: damage from the ult alone, from the whole burst, and
## whether the target is still up.
static func run(ak, arch: String, dist: float, land: Callable) -> Dictionary:
	var r: Array = ak.setup(arch, dist, MERGE_KIN)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	P.lvl = TEST_LEVEL
	T.max_hp = float(Data.CLASSES["light"]["hp"])
	T.hp = T.max_hp
	await land.call(m, P, T)
	var after_ult := T.max_hp - T.hp
	var merged: bool = ak.merge_now(P) and not bool(P.merge_st.get("surge", false))
	ak.step(m, float(MergeForm.data()["xform_s"]) + 0.12)
	var kit := MergeKit.of(P)
	if kit != null:
		kit.age = float(MergeForm.data()["ult_lock_s"]) + 0.1
	P.inp["ult"] = true
	ak.step(m, 2.0)
	var out := {"ult": after_ult, "total": T.max_hp - T.hp, "alive": T.hp > 0.0 and not T.downed, "merged": merged}
	await ak.done(m)
	return out
