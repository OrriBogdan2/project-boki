class_name MergeForm
extends RefCounted
## What a merge is and how it looks (docs/decisions/0003), the same for everyone. Two kinds:
##   - a FORM with a kit (content/merge_forms/<merge id>.json): its palette, look, weight-class baseline,
##     dodge flavour and the four slots LMB / RMB / E / R that replace yours while merged (MergeKit)
##   - the fallback every other Boki gets until its form is written (docs/DEBT.md): the Boki's own merge
##     (content/merges_v2) plus a look, a rider on class-ability hits and a dodge burst from its type
##     (content/rules/merge_forms.json). No tiers, no scaling by level or trust.
## The form is a plain Dictionary kept in Hunter.merge_st["form"]:
##   {id, kit, name, type, color, glow, accent, parts, style, word, haste, rider, dash, size, ring, dur, surge, def}
## `def` is the kit's data (empty for the fallback and the surge). The rest crosses the net (KinNet).

const RIDER_RANGE := 5.0     # m: how far an arc jumps from the foe you hit

static func data() -> Dictionary:
	return Content.rules("merge_forms")

static func type_of(k: Kin) -> String:
	var t := String(k.sp.get("type", "none"))
	return t if (data().get("types", {}) as Dictionary).has(t) else "none"

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
		"accent": Color(String(pal.get("accent", pal["glow"]))), "parts": lk["parts"], "style": "kit", "word": String(fd["name"]).to_upper(), "haste": 0.0,
		"rider": {}, "dash": fd.get("dash", {}), "size": float(lk["scale"]), "ring": float(lk.get("ring", 3.0)), "part_k": float(lk.get("part_k", 1.7)), "dur": dur, "surge": false, "def": fd}

## The stat-style look of a Boki with no form yet, from its type.
static func fallback_form(ty: String, col: Color, glow: Color) -> Dictionary:
	var d := data()
	var td: Dictionary = d["types"][ty if (d["types"] as Dictionary).has(ty) else "none"]
	var fb: Dictionary = d["fallback"]
	return {"id": "", "kit": false, "name": String(td["word"]).capitalize(), "type": ty, "color": col, "glow": glow, "accent": glow, "parts": td["parts"], "style": String(td["style"]),
		"word": String(td["word"]), "haste": float(fb["haste"]), "rider": td["rider"].duplicate(), "dash": td["dash"].duplicate(), "size": float(fb["size"]), "ring": 3.0, "part_k": 1.3, "dur": 0.0,
		"surge": false, "def": {}}

## The weak merge you get with no Boki able to fight: no silhouette, a plain light.
static func surge_form() -> Dictionary:
	var sd: Dictionary = data()["surge"]
	var c := Color(String(sd["color"]))
	return {"id": "", "kit": false, "name": String(sd["name"]), "type": "none", "color": c, "glow": c, "accent": c, "parts": [], "style": "nova",
		"word": String(sd["name"]).to_upper(), "haste": float(sd["haste"]), "rider": {}, "dash": {}, "size": 1.0, "ring": 3.0, "part_k": 1.0, "dur": 0.0, "surge": true, "def": {}}

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

## Is this a form with a kit (not the fallback, not the surge)?
static func has_kit(f: Dictionary) -> bool:
	return bool(f.get("kit", false))

# ------------------------------------------------------------------ the changes to your abilities
## The form you wear right now ({} when not merged).
static func of(h: Hunter) -> Dictionary:
	return h.merge_st.get("form", {}) if h != null and not h.merge_st.is_empty() else {}

## A class ability of a merged hunter hit a foe: the type's rider rides on it (Match.on_damage, src "abil").
static func on_ability_hit(h: Hunter, target: Ent, dmg: float, opts: Dictionary) -> void:
	var f := of(h)
	if f.is_empty() or opts.get("form", false) or target.remote or target.dead or target.team == h.team:
		return
	_apply(h, target, dmg, f["rider"])

static func _apply(h: Hunter, t: Ent, dmg: float, r: Dictionary) -> void:
	if r.has("burn"):
		t.burn_t = maxf(t.burn_t, float(r.get("burn_for", 3.0))); t.burn_dps = maxf(t.burn_dps, float(r["burn"])); t.burn_by = h
	if r.has("slow_k"):
		t.slow_k = maxf(t.slow_k, float(r["slow_k"])) if t.slow_t > 0.0 else float(r["slow_k"])
		t.slow_t = maxf(t.slow_t, float(r.get("slow_s", 1.5)))
	if r.has("kb"):
		t.impulse(h.dir_to(t) * float(r["kb"]))      # a negative shove pulls it toward you
	if r.has("leech") and not h.downed:
		h.heal(dmg * float(r["leech"]))
	if r.has("chain"):
		var best: Ent = null
		var bd := RIDER_RANGE
		for o in h.m.foes_of(h.team):
			if o == t or o.dead or not o.hittable():
				continue
			var dd: float = o.flat_dist(t)
			if dd < bd: bd = dd; best = o
		if best:
			h.m.fx.bolt(t.pos + Vector3(0, 1.0, 0), best.pos + Vector3(0, 1.0, 0), Color(1, 1, 1, 0.9))
			best.hurt(maxf(1.0, dmg * float(r["chain"])), h, {"src": "abil", "ab": "form", "tags": ["form"], "form": true})

## A dodge while merged: a burst where it starts and where it ends.
static func on_dash(h: Hunter) -> void:
	var f := of(h)
	if f.is_empty() or (f["dash"] as Dictionary).is_empty():
		return
	_burst(h, h.pos, f)
	var tt := maxf(0.05, h.roll_t)
	h.m.later(tt, func(): if is_instance_valid(h) and not h.dead and not h.out and not of(h).is_empty(): _burst(h, h.pos, f))

static func _burst(h: Hunter, at: Vector3, f: Dictionary) -> void:
	var dd: Dictionary = f["dash"]
	var rad := float(dd.get("radius", 2.0))
	h.m.fx.ring(at, rad, Color(f["glow"], 0.8), 0.3)
	h.m.fx.burst(at + Vector3(0, 0.3, 0), f["glow"], 8, 2.5, 0.35)
	match String(dd.get("visual", "")):
		"spark":
			for i in 3:
				var a := TAU * (float(i) + randf()) / 3.0
				h.m.fx.bolt(at + Vector3(0, 0.6, 0), at + Vector3(cos(a) * rad, 0.3, sin(a) * rad), Color(f["glow"]))
		"rock":
			h.m.fx.dust(at, 10)
		"prism":
			for i in 4:
				h.m.fx.burst(at + Vector3(0, 0.8, 0), Color.from_hsv(randf(), 0.45, 1.0), 3, 3.0, 0.4)
	for t in h.m.foes_of(h.team):
		if t.dead or not t.hittable() or Vector2(t.pos.x - at.x, t.pos.z - at.z).length() > rad + t.r:
			continue
		var dmg: float = float(dd.get("burst", 6.0)) * h.m.dmg_mult(h)
		t.hurt(dmg, h, {"src": "abil", "ab": "form", "tags": ["dodge", "form"], "form": true})
		_apply(h, t, dmg, dd)
