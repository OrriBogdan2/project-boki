class_name Parentage
## Who a baby got what from (briefs/design/GARDEN.md section 6). Care.breed saves the gifts on the baby
## (rec["gifts"]); the parents' uids are rec["lineage"]["parents"]. The hatch card lists the gifts in
## words, and in base_mode a young Boki leans toward its parents (BaseLife).

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

## The gifts in plain words, one per line ("" for a baby with none recorded: older or Rare Eggs).
static func gift_text(baby: Dictionary) -> String:
	var g: Dictionary = baby.get("gifts", {})
	if g.is_empty() or not baby.has("parents"): return ""
	var lines := PackedStringArray()
	lines.append("Its kind comes from %s." % _who(baby, g["species"]))
	if g.has("lean"): lines.append("Its lean comes from %s." % _who(baby, g["lean"]))
	lines.append("Favourite food from %s, favourite play from %s." % [_who(baby, g["food"]), _who(baby, g["play"])])
	for id in g.get("muts", {}):
		lines.append("%s comes from %s." % [Mutations.name_of(id), _who(baby, g["muts"][id])])
	return "\n".join(lines)

## The parent index for "it came from a" (0) or from b (1).
static func _side(from_a: bool) -> int:
	return 0 if from_a else 1

static func _who(baby: Dictionary, i: int) -> String:
	return "both parents" if i == BOTH else String(baby["parents"][i])

## True if `other` is a parent of the young Boki `rec` (a Boki that is Grown has left the nest).
static func is_parent_of(other: Dictionary, rec: Dictionary) -> bool:
	return int(rec["level"]) < NookRules.GROWN_LV \
		and (rec.get("lineage", {}) as Dictionary).get("parents", []).has(String(other["uid"]))
