class_name KinPair
extends RefCounted
## Carry two in, one extra out (DECISIONS 2026-11-11): the lead Boki (h.kin, the one with the summon) and the
## second (h.kin2, benched) both give their carry passives, and the same stat from both counts once, the
## stronger. The swap key (Settings "swap_kin", KinKeys) trades the lead and the second. A hunter never holds
## more than steal.wisp_max wisps: own Boki, the carry-out capsule (Hunter.caught) and stolen wisps together.
## A capsule a rival loots from your deathbox is noted on you (robbed) for the HUD's STOLEN tag.

const ROBBED := "carry_robbed"      # Hunter meta: the capsule's record a rival took from your deathbox

## The carry passives on a hunter: the lead's (while it is settled on them) and the second's, per stat the stronger.
static func passives(h: Hunter) -> Dictionary:
	var out := {}
	var lists: Array = []
	if h.kin_carry_on():
		lists.append((h.kin as Kin).ks.carry_passives)
	var k2: Kin = h.kin2
	if k2 != null and not k2.dead and k2.owner_h == h and k2.ks != null:
		lists.append(k2.ks.carry_passives)
	for list in lists:
		for ps in list:
			out[ps["stat"]] = maxf(float(out.get(ps["stat"], 0.0)), float(ps["amount"]))
	return out

## Wisps the hunter holds: own Boki, carry-out capsules, stolen wisps.
static func wisps(h: Hunter) -> int:
	var own := 0
	for k in [h.kin, h.kin2]:
		if k != null and not (k as Kin).dead:
			own += 1
	return own + h.caught.size() + KinSteal.count(h)

## Room for one more stolen wisp: under the stolen cap and under the wisp cap.
static func room_for_stolen(h: Hunter) -> bool:
	var r := KinSteal.rules()
	return KinSteal.count(h) < int(r["carry_max"]) and wisps(h) < int(r["wisp_max"])

## A rival took `rec` out of `victim`'s deathbox into `looter`'s box.
static func robbed(victim: Hunter, looter: Hunter, rec: Dictionary) -> void:
	if victim != null and victim.team != looter.team:
		victim.set_meta(ROBBED, rec)
