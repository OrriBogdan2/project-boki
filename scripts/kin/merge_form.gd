class_name MergeForm
extends RefCounted
## What a merge is and how it looks (docs/decisions/0003), the same for everyone. Two kinds:
##   - a FORM (content/merge_forms/<merge id>.json): its palette, look, weight-class baseline, its ultimate (R) and
##     its augments (`aug`: LMB rider, RMB and E add-ons, the form dash, a passive), run by MergeAugment. You keep
##     your own hero's abilities (docs/decisions/0004).
##   - the fallback every other Boki gets until its form is written (docs/DEBT.md): the Boki's own merge
##     (content/merges_v2) plus a look, the type's rider on LMB and its trail as the form dash
##     (content/rules/merge_forms.json). No tiers, no scaling by level or trust.
## The form is a plain Dictionary kept in Hunter.merge_st["form"]:
##   {id, kit, name, type, color, glow, accent, parts, style, word, haste, aug, size, ring, dur, surge, def, cue}
##   (`cue` is the sound type: boki_fuse_<cue>)
## `def` is the form's data (empty for the fallback and the surge); `kit` is true for a form with its own file. The rest crosses the net (KinNet).

static func data() -> Dictionary:
	return Content.rules("merge_forms")

static func type_of(k: Kin) -> String:
	var t := String(k.sp.get("type", "none"))
	return t if (data().get("types", {}) as Dictionary).has(t) else "none"

## The sound type of a Fusion type (boki_fuse_<cue>).
static func type_cue(ty: String) -> String:
	var types: Dictionary = data()["types"]
	return String((types[ty] if types.has(ty) else types["none"])["cue"])

## The form this Boki gives you right now.
static func for_boki(k: Kin) -> Dictionary:
	var ms := KinMerge.def_for(k)
	if ms != null and not Content.merge_form(ms.id).is_empty():
		return kit_form(ms.id)
	return fallback_form(type_of(k), k.sp["color"], k.sp.get("glow", k.sp["color"]))

## A form with a kit, from its data file.
static func kit_form(id: String, dur := 0.0) -> Dictionary:
	var fd: Dictionary = Content.merge_form(id)
	var pal: Dictionary = fd["palette"]
	var lk: Dictionary = fd["look"]
	return {"id": id, "kit": true, "name": String(fd["name"]), "type": "kit", "color": Color(String(pal["body"])), "glow": Color(String(pal["glow"])),
		"accent": Color(String(pal.get("accent", pal["glow"]))), "parts": lk["parts"], "style": "kit", "word": String(fd["name"]).to_upper(), "haste": float((fd["aug"].get("stats", {}) as Dictionary).get("cooldown", 0.0)),
		"aug": fd["aug"], "size": float(lk["scale"]), "ring": float(lk.get("ring", 3.0)), "part_k": float(lk.get("part_k", 1.7)), "dur": dur, "surge": false, "def": fd,
		"cue": String(fd["sound"]["cue"])}

## The stat-style look of a Boki with no form yet, from its type.
static func fallback_form(ty: String, col: Color, glow: Color) -> Dictionary:
	var d := data()
	var td: Dictionary = d["types"][ty if (d["types"] as Dictionary).has(ty) else "none"]
	var fb: Dictionary = d["fallback"]
	return {"id": "", "kit": false, "name": String(td["word"]).capitalize(), "type": ty, "color": col, "glow": glow, "accent": glow, "parts": td["parts"], "style": String(td["style"]),
		"word": String(td["word"]), "haste": float(fb["haste"]), "aug": _fallback_aug(td), "size": float(fb["size"]), "ring": 3.0, "part_k": 1.3, "dur": 0.0,
		"surge": false, "def": {}, "cue": type_cue(ty)}

## The weak merge you get with no Boki able to fight: no silhouette, a plain light.
static func surge_form() -> Dictionary:
	var sd: Dictionary = data()["surge"]
	var c := Color(String(sd["color"]))
	return {"id": "", "kit": false, "name": String(sd["name"]), "type": "none", "color": c, "glow": c, "accent": c, "parts": [], "style": "nova",
		"word": String(sd["name"]).to_upper(), "haste": float(sd["haste"]), "aug": {}, "size": 1.0, "ring": 3.0, "part_k": 1.0, "dur": 0.0, "surge": true, "def": {}, "cue": "normal"}

## The surge as a MergeSpec, so it runs through the same state and tick as a merge.
static func surge_spec() -> MergeSpec:
	var sd: Dictionary = data()["surge"]
	var ms := MergeSpec.new()
	ms.id = "surge"
	ms.display_name = String(sd["name"])
	ms.flavor = String(sd["flavor"])
	ms.duration = float(sd["duration"])
	for pr in sd["passives"]:
		ms.passives.append({"stat": String(pr[0]), "amount": float(pr[1]), "category": String(KinParts.OWNER_STATS[pr[0]][0])})
	return ms

## The owner stats a form's weight-class baseline gives (shield hp, run speed): the only scaling a form has.
static func baseline(f: Dictionary, cls: String) -> Dictionary:
	var b: Dictionary = (f["def"] as Dictionary).get("baseline", {})
	return b.get(cls, b.get("medium", {}))

## Is this a form with its own file (not the fallback, not the surge)?
static func has_kit(f: Dictionary) -> bool:
	return bool(f.get("kit", false))

## The form you wear right now ({} when not merged).
static func of(h: Hunter) -> Dictionary:
	return h.merge_st.get("form", {}) if h != null and not h.merge_st.is_empty() else {}

## The augment set of a form (docs/decisions/0004): {lmb, rmb, e, dash, stats}. Same for every hero.
static func aug_of(f: Dictionary) -> Dictionary:
	return f.get("aug", {})

## A fallback form's augments, from its Boki type: the type's rider on every attack, and as the form dash a rush
## that leaves the type's trail.
static func _fallback_aug(td: Dictionary) -> Dictionary:
	var r: Dictionary = td["rider"]
	var lmb := {"name": String(td["word"]).capitalize(), "icon": "bolt", "desc": "Every hit carries the %s rider." % String(td["word"]).to_lower()}
	for key in ["burn", "burn_for", "slow_k", "leech"]:
		if r.has(key):
			lmb[key] = r[key]
	if r.has("slow_k"):
		lmb["slow_s"] = float(r.get("slow_s", 1.5))
	if r.has("chain"):
		lmb["chain"] = 1
		lmb["chain_dmg"] = float(r["chain"])
	var dash: Dictionary = (data()["fallback"]["dash"] as Dictionary).duplicate()
	dash.merge(td["dash"])
	var word := String(td["word"]).to_lower()
	var said := "Your dash leaves a %s trail: what you pass through takes %s damage and the rider, then %ss of haste."
	dash["desc"] = said % [word, KinText.n(float(dash["dmg"])), KinText.n(float(dash["haste_s"]))]
	return {"lmb": lmb, "dash": dash, "stats": {}}
