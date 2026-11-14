class_name SummonCc
extends RefCounted
## Crowd control on a summoned Boki (docs/specs/SUMMON_CC.md). It rides the Hunter's own status path
## unchanged; the only difference is the kinds in content/rules/summon_cc.json "immune" (Grounded: a
## Boki has no dash, jump or glide to lose). KitStatus.apply asks here before it puts a kind on a body.

## Is this body a Boki out of its wisp (KinSummon.out), so the summon rules apply?
static func summoned(e: Ent) -> bool:
	if not e is Kin:
		return false
	var s = e.get("summon")
	return e.has_meta("summoned") or (s != null and s.out())

## Does a summoned `e` shrug off the KitStatus `kind` ("gnd", "rat", ...)?
static func immune(e: Ent, kind: String) -> bool:
	return summoned(e) and kind in Content.rules("summon_cc")["immune"]
