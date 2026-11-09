class_name DashRules
extends RefCounted
## The dash numbers every hero has at rank 1, read from data in one place: the class's dodge
## (content/abilities, Data.CLASSES) and the hero kit's `dash` block (content/archetypes/<id>.json).
## The Hunter in a match and the Home on the farm both ask here, so a charge or cooldown change is
## made once. What the farm does NOT share: the dash's shape (speed, time, long-dash distance), which
## it takes from the class dodge (Home._dodge) because the kit's moves need a Hunter.

## Charges from the class alone (a kit adds `extra`, ranks and perks add theirs on the Hunter).
static func class_charges(dodge: AbilityDef, cdat: Dictionary) -> float:
	return float(dodge.charges) if dodge else float(cdat["dashes"])

## Seconds per charge at rank 1: the kit's dash cd, else the class dodge's.
static func regen(dodge: AbilityDef, kit_dash: Dictionary) -> float:
	var base: float = dodge.cooldown if dodge else Hunter.DASH_REGEN
	return float(kit_dash.get("cd", base))

## Charges a kit gives over the class's from rank 1 (Grimble's third barge).
static func extra(kit_dash: Dictionary) -> float:
	return float(kit_dash.get("extra", 0))

## false when Shift is only ever the kit's own dash (Neve's skate): no long air dash.
static func has_air(kit_dash: Dictionary) -> bool:
	return bool(kit_dash.get("long", true))

## Seconds the long (air) dash takes to come back: the kit's `air.cd`, else the class's `ex_cd`.
static func air_cd(kit_dash: Dictionary, cdat: Dictionary) -> float:
	var air: Dictionary = kit_dash.get("air", {})
	return float(air.get("cd", cdat.get("ex_cd", Hunter.EX_DASH_CD)))

## The farm's dash numbers for a hero (rank 1, no perks): {charges, regen, air_cd (0 = no long dash)}.
static func of_hero(cls: String, arch: String) -> Dictionary:
	var kit_dash: Dictionary = Arch.def(arch).get("dash", {})
	var cdat: Dictionary = Data.CLASSES.get(cls, {})
	var dodge := Content.class_dodge(cls)
	return {"charges": class_charges(dodge, cdat) + extra(kit_dash), "regen": regen(dodge, kit_dash),
		"air_cd": air_cd(kit_dash, cdat) if has_air(kit_dash) else 0.0}
