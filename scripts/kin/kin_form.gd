class_name KinForm
extends RefCounted
## Which look a Boki wears: its base form, or its cracked second form (content/rules/boki_forms.json).

const PATH := "res://content/rules/boki_forms.json"

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_rules = parsed if parsed is Dictionary else {"damaged_below": 0.4, "forms": {}}
	return _rules

## "cracked" when the species has one and it is hurt (hp_frac below the threshold) or sick, else "base".
static func form_of(species: String, hp_frac: float, sick: bool) -> String:
	var r := rules()
	if not r["forms"].has(species):
		return "base"
	return "cracked" if sick or hp_frac < float(r["damaged_below"]) else "base"

## The 3D model path to show for that form; the base model while the cracked one is not made yet; "" for no model.
static func model_of(species: String, form: String) -> String:
	var forms: Dictionary = rules()["forms"].get(species, {})
	var path := String(forms.get(form, {}).get("model", ""))
	return path if path != "" else String(forms.get("base", {}).get("model", ""))
