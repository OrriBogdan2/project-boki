class_name BokiSex
extends RefCounted
## Which model a Boki wears for its sex. Every Boki is male or female (Unique.sex, 50/50); only species
## with "sex_forms": true in content/kin/<id>.json have a separate female look, art/kin/<id>/<id>_f.glb.
## A species without it, or whose female art isn't made yet, wears its one model.

const FEMALE_PATH := "res://art/kin/%s/%s_f.glb"

static func has_forms(species: String) -> bool:
	return bool(Data.KIN.get(species, {}).get("sex_forms", false))

## The .glb this Boki's rig loads: the female one when it has a female look and the art exists, else `base`.
static func model_path(species: String, rec: Dictionary, base: String) -> String:
	if not has_forms(species) or Unique.sex(rec) != "f":
		return base
	var female := FEMALE_PATH % [species, species]
	return female if ResourceLoader.exists(female) else base
