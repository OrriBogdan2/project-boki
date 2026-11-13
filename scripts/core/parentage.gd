class_name Parentage
## Who a baby got what from (briefs/design/GARDEN.md section 6). Care.breed saves the gifts on the baby
## (rec["gifts"]); the parents' uids are rec["lineage"]["parents"]. The hatch card marks each gift with its parent
## (HatchParents), and in base_mode a young Boki leans toward its parents (BaseLife).

const BOTH := -1     # a gift both parents share: the same kind, or a mutation each carried

## What each parent gave: {"species": i, "lean": i, "food": i, "play": i, "muts": {id: i}} with i the
## parent (0 = a, 1 = b, as in rec["parents"]) or BOTH. A kind of gift the baby didn't get has no key.
static func gifts(a: Dictionary, b: Dictionary, baby: Dictionary, a_food: bool) -> Dictionary:
	var g := {"food": _side(a_food), "play": _side(not a_food)}
	g["species"] = BOTH if a["species"] == b["species"] else _side(baby["species"] == a["species"])
	if Care.lean_total(a) > 0.0 or Care.lean_total(b) > 0.0:
		g["lean"] = 1 if Care.lean_total(b) > Care.lean_total(a) else 0
	var muts := {}
	for id in Mutations.of(baby):
		var from_a: bool = Mutations.of(a).has(id)
		var from_b: bool = Mutations.of(b).has(id)
		if from_a and from_b: muts[id] = BOTH
		elif from_a or from_b: muts[id] = _side(from_a)
	if not muts.is_empty(): g["muts"] = muts
	return g

## The parent index for "it came from a" (0) or from b (1).
static func _side(from_a: bool) -> int:
	return 0 if from_a else 1

## True if `other` is a parent of the young Boki `rec` (a Boki that is Grown has left the nest).
static func is_parent_of(other: Dictionary, rec: Dictionary) -> bool:
	return int(rec["level"]) < NookRules.GROWN_LV \
		and (rec.get("lineage", {}) as Dictionary).get("parents", []).has(String(other["uid"]))
