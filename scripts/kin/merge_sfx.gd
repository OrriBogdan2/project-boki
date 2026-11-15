class_name MergeSfx
extends RefCounted
## A Fusion form's own sounds (docs/AUDIO.md), routed by form id through data: the form file's "sound" block
## (content/merge_forms/<id>.json) names its `cast` (the ultimate starting), `travel` (the form dash) and `hit`
## (where the form's moves land). Yours plays at form_sfx.db (content/rules/merge_forms.json); a teammate's or a
## rival's plays other_db quieter, from where it happens. A Boki with no form file has none of its own: play()
## says so and the caller keeps the shared sounds.

## The sound a form names for `kind`, or "" (no form, or a form without one).
static func name_of(form_id: String, kind: String) -> String:
	if form_id == "":
		return ""
	return String((Content.merge_form(form_id).get("sound", {}) as Dictionary).get(kind, ""))

## The merged hunter's form id: from the merge on its own game, from the snapshot (KinNet) on the others.
static func form_id(h: Hunter) -> String:
	if not h.merge_st.is_empty():
		return String(MergeForm.of(h)["id"])
	return String(h.get_meta("mf_id", ""))

## How loud `kind` plays for this hunter's form: full for yours, quieter for anyone else's.
static func level(h: Hunter, kind: String) -> float:
	var d: Dictionary = MergeForm.data()["form_sfx"]
	return float(d["db"][kind]) + (0.0 if h.is_local() else float(d["other_db"]))

## Plays the form's `kind` sound at `at` (the hunter when left out). False when the form has none.
static func play(h: Hunter, kind: String, at := Vector3.INF) -> bool:
	var sname := name_of(form_id(h), kind)
	if sname == "":
		return false
	h.m.sfx(sname, h.pos if at == Vector3.INF else at, level(h, kind))
	return true

## The Effects context entry that makes the form's area hits play its hit instead of the shared one ({} if none).
static func hit_ctx(h: Hunter) -> Dictionary:
	var sname := name_of(form_id(h), "hit")
	return {} if sname == "" else {"name": sname, "db": level(h, "hit")}
