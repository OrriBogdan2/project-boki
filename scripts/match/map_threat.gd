class_name MapThreat
extends RefCounted
## Harder monsters on a harder map: the layout's "threat" block (content/maps/<id>.json, e.g. the
## Riven Wilds) folded into the match's tier table once at the start, so every system that already
## reads the tier follows. "mob" multiplies the tier's monster strength (health and damage), "rarity_lift"
## shifts the rarity roll that many steps toward rare and elite (BiomeRun.dress), "camp_extra" adds
## monsters to every camp (BiomeRun.camp_comp). A map without the block leaves the tier as it is.

## The tier table for a match on this layout (a copy when the layout adds threat).
static func apply(tier_table: Dictionary, layout: Dictionary) -> Dictionary:
	var threat: Dictionary = layout.get("threat", {})
	if threat.is_empty():
		return tier_table
	var out := tier_table.duplicate()
	out["mob"] = float(tier_table.get("mob", 1.0)) * float(threat.get("mob", 1.0))
	out["rarity_lift"] = float(threat.get("rarity_lift", 0.0))
	out["camp_extra"] = int(threat.get("camp_extra", 0))
	return out
