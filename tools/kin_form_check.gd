extends RefCounted
## --kin-form-check: second forms (KinForm, content/rules/boki_forms.json, docs/boki/GEODEMOLE_FORMS.md).
##   1. Geodemole has both approved forms linked by art id
##   2. at 40% health or more it is base; below it, or sick, it is cracked
##   3. a Boki with no second form is always base
##   4. a missing cracked model falls back to the base model

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("KINFORM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	var f: Dictionary = KinForm.rules()["forms"].get("geodemole", {})
	var base_art: String = f.get("base", {}).get("art", "")
	var cracked_art: String = f.get("cracked", {}).get("art", "")
	ok(base_art == "geodemole-3-art" and cracked_art == "geodemole-r-3-art", "both forms linked")
	ok(KinForm.form_of("geodemole", 1.0, false) == "base", "full health is base")
	ok(KinForm.form_of("geodemole", 0.4, false) == "base", "exactly 40% is still base")
	ok(KinForm.form_of("geodemole", 0.39, false) == "cracked", "below 40% is cracked")
	ok(KinForm.form_of("geodemole", 1.0, true) == "cracked", "sick at home is cracked")
	ok(KinForm.form_of("glintmole", 0.1, true) == "base", "no second form stays base")
	var fallback: bool = KinForm.model_of("geodemole", "cracked") == KinForm.model_of("geodemole", "base")
	ok(fallback, "missing cracked model falls back to base")
	print("KINFORM %s" % ("PASS" if bad == 0 else "FAIL %d" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)
