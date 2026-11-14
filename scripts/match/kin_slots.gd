class_name KinSlots
extends RefCounted
## Two Boki in a match ("carry 2 in, 1 extra out", DECISIONS 2026-11-11, docs/decisions/0090): the lead (Hunter.kin) is
## the one you send out, with its abilities and the summon key; the second (Hunter.kin2) rides in your satchel
## and its carry passive is on as well. The lead's is on while it rides with you (Hunter.kin_carry_on). The same
## stat from both does not stack: the stronger one counts. The swap key trades them (Hunter.swap_kin, a short
## cooldown from content/rules/kin_ai.json). The carry-out and stolen slots are Capture's (Hunter.caught).

## The second's carry passive is on: it waits in the satchel, healthy, while you are up.
static func second_on(h: Hunter) -> bool:
	var b: Kin = h.kin2
	return b != null and is_instance_valid(b) and not b.dead and b.state == "bench" and b.hp > 0.0 and b.ks != null \
		and not h.downed

## Owner stats (KinParts.OWNER_STATS) from the carry passives that are on: each Boki's own passives add up,
## and between the two Boki the stronger value of a stat counts (no double stack).
static func carry_stats(h: Hunter) -> Dictionary:
	var out := {}
	var lead: Kin = h.kin
	var from: Array = []
	if lead and lead.ks and h.kin_carry_on():
		from.append(lead)
	if second_on(h):
		from.append(h.kin2)
	for k in from:
		var own := {}
		for ps in (k as Kin).ks.carry_passives:
			own[ps["stat"]] = float(own.get(ps["stat"], 0.0)) + RunPayoff.amount(ps, (k as Kin).carry_k)
		for st in own:
			out[st] = maxf(float(out[st]), float(own[st])) if out.has(st) else float(own[st])
	return out
