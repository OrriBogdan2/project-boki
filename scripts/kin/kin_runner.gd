class_name KinRunner
extends RefCounted
## Charges and cooldowns for a kin's grammar abilities (slot "k1" = the active on E, "k2" = the auto
## active). It only counts time: casting is KinExec's job. Ranks shorten the cooldown 10% a rank.

var slots := {}                # slot -> {def: AbilitySpec, charges: float, cd: float, cd_k: float}
var rate := 1.0                # cooldown speed (care, mutations)

func set_slot(slot: String, def: AbilitySpec) -> void:
	if def == null:
		slots.erase(slot)
		return
	slots[slot] = {"def": def, "charges": float(def.charges), "cd": 0.0, "cd_k": 1.0}

func has_slot(slot: String) -> bool:
	return slots.has(slot)

func def_of(slot: String) -> AbilitySpec:
	return slots[slot]["def"] if slots.has(slot) else null

func is_ready(slot: String) -> bool:
	return slots.has(slot) and float(slots[slot]["charges"]) >= 1.0

func charges(slot: String) -> int:
	return int(floor(float(slots[slot]["charges"]))) if slots.has(slot) else 0

func cd_left(slot: String) -> float:
	return float(slots[slot]["cd"]) if slots.has(slot) else 0.0

func cd_max(slot: String) -> float:
	if not slots.has(slot):
		return 0.0
	return (slots[slot]["def"] as AbilitySpec).cooldown * float(slots[slot]["cd_k"])

func cd_frac(slot: String) -> float:
	if not slots.has(slot) or is_ready(slot):
		return 0.0
	return clampf(cd_left(slot) / maxf(0.01, cd_max(slot)), 0.0, 1.0)

## Takes a charge for a cast at this rank. False if none is ready.
func spend(slot: String, rank := 1) -> bool:
	if not is_ready(slot):
		return false
	var s: Dictionary = slots[slot]
	s["charges"] = float(s["charges"]) - 1.0
	s["cd_k"] = clampf(1.0 - 0.1 * float(rank - 1), 0.5, 1.0)
	if float(s["cd"]) <= 0.0:
		s["cd"] = cd_max(slot)
	return true

func tick(dt: float) -> void:
	for slot in slots:
		var s: Dictionary = slots[slot]
		var d: AbilitySpec = s["def"]
		if float(s["charges"]) >= d.charges:
			s["cd"] = 0.0
			continue
		s["cd"] = float(s["cd"]) - dt * rate
		if float(s["cd"]) <= 0.0:
			s["charges"] = minf(float(d.charges), float(s["charges"]) + 1.0)
			s["cd"] = cd_max(slot) if float(s["charges"]) < d.charges else 0.0

func reset() -> void:
	for slot in slots:
		slots[slot]["charges"] = float((slots[slot]["def"] as AbilitySpec).charges)
		slots[slot]["cd"] = 0.0
