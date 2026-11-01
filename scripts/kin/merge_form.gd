class_name MergeForm
extends RefCounted
## What a merge does to YOU and how it looks, from the Boki's type and power tier (content/rules/
## merge_forms.json, docs/decisions/0001). Never per hero x Boki pair: every class gets the same
## kit-agnostic changes. The Boki's own merge (content/merges_v2, KinMerge) still brings its passives,
## shot riders and merged Boki abilities; this adds, on top:
##   - the form worn on you (colour and silhouette parts, MergeLook) and the activation moment (style)
##   - faster cooldowns on every class ability (owner stat "cooldown")
##   - a rider on every class-ability hit (burn, slow, shove or pull, life steal, an arc to a second foe)
##   - a burst where each dodge starts and ends
## The form is a plain Dictionary kept in Hunter.merge_st["form"]:
##   {type, tier, tier_name, color, glow, parts, style, word, haste, rider, dash, stun, size, k, dur}

const RIDER_RANGE := 5.0     # m: how far an arc jumps from the foe you hit
const STUN_CD := 3.0         # s: the top tier's stun on an ability hit lands on a foe at most this often

static func data() -> Dictionary:
	return Content.rules("merge_forms")

## The Boki's power: level and trust (KinMerge.growth) plus a little per evolved form.
static func power(k: Kin) -> float:
	return KinMerge.growth(k) + float(data().get("forms_bonus", 0.08)) * float((k.rec.get("forms", []) as Array).size())

## 0..2: the last tier whose `from` the power reaches.
static func tier_of(p: float) -> int:
	var t := 0
	var rows: Array = data().get("tiers", [])
	for i in rows.size():
		if p >= float(rows[i]["from"]): t = i
	return t

static func type_of(k: Kin) -> String:
	var t := String(k.sp.get("type", "none"))
	return t if (data().get("types", {}) as Dictionary).has(t) else "none"

## The form this Boki gives you right now.
static func for_boki(k: Kin) -> Dictionary:
	var d := data()
	var ty := type_of(k)
	var td: Dictionary = d["types"][ty]
	var tier := tier_of(power(k))
	var tr: Dictionary = (d["tiers"] as Array)[tier]
	var rk := float(tr["rider"])
	var rider: Dictionary = {}
	for key in (td["rider"] as Dictionary):
		rider[key] = float(td["rider"][key]) * (rk if key in ["burn", "slow_k", "kb", "leech", "chain"] else 1.0)
	rider["slow_k"] = minf(float(rider.get("slow_k", 0.0)), 0.6)
	var dash: Dictionary = {}
	for key in (td["dash"] as Dictionary):
		dash[key] = float(td["dash"][key]) * (rk if key in ["burst", "burn", "kb", "leech", "chain"] else 1.0)
	var glow: Color = k.sp.get("glow", k.sp["color"])
	return {"type": ty, "tier": tier, "tier_name": String(tr["name"]), "color": k.sp["color"], "glow": glow, "parts": (td["parts"] as Array).slice(0, int(tr["parts"])),
		"style": String(td["style"]), "word": String(td["word"]), "haste": float(tr["haste"]), "rider": rider, "dash": dash, "stun": float(tr["stun"]),
		"size": float(tr["size"]), "k": float(tr["k"]), "dur": float(tr["dur"]), "surge": false}

## The weak merge you get with no Boki able to fight: no silhouette, a plain light.
static func surge_form() -> Dictionary:
	var sd: Dictionary = data()["surge"]
	return {"type": "none", "tier": 0, "tier_name": String(sd["name"]), "color": Color(String(sd["color"])), "glow": Color(String(sd["color"])), "parts": [], "style": "nova",
		"word": String(sd["name"]).to_upper(), "haste": float(sd["haste"]), "rider": {}, "dash": {}, "stun": 0.0, "size": 1.0, "k": 1.0, "dur": 0.0, "surge": true}

## The surge as a MergeSpec, so it runs through the same state and tick as a merge.
static func surge_spec() -> MergeSpec:
	var sd: Dictionary = data()["surge"]
	var ms := MergeSpec.new()
	ms.id = "surge"
	ms.display_name = String(sd["name"])
	ms.flavor = String(sd["flavor"])
	ms.duration = float(sd["duration"])
	ms.grow_duration = 0.0
	ms.grow_strength = 0.0
	for pr in sd["passives"]:
		ms.passives.append({"stat": String(pr[0]), "amount": float(pr[1]), "category": String(KinParts.OWNER_STATS[pr[0]][0])})
	return ms

# ------------------------------------------------------------------ the activation moment
## The big signature effect when the merge goes off: a style per type, in the Boki's colours, bigger
## with the tier. Local to this game (other games see it from the "kcmd merge" event, KinNet).
static func activate(m: Match, at: Vector3, form: Dictionary) -> void:
	var col: Color = form["glow"]
	var tier := int(form["tier"])
	var big := 1.0 + 0.35 * float(tier)
	m.fx.flash(at + Vector3(0, 1.0, 0), col, 2.4 * big, 0.14)
	m.fx.ring(at, 3.4 * big, Color(col, 0.95), 0.5)
	m.fx.ring(at, 1.8 * big, Color(1, 1, 1, 0.9), 0.3)
	m.fx.burst(at + Vector3(0, 1.0, 0), col, int(34 * big), 7.0, 0.6, 2.0, 1.4)
	match String(form["style"]):
		"nova":
			m.fx.ring(at, 5.0 * big, Color(col, 0.6), 0.7)
		"spiral":
			for i in 8:
				var a := TAU * float(i) / 8.0
				m.later(0.04 * i, func(): m.fx.burst(at + Vector3(cos(a) * 1.8 * big, 0.4 + 0.25 * i, sin(a) * 1.8 * big), col, 8, 2.5, 0.5, -1.0))
		"pillar":
			for i in 6:
				m.later(0.03 * i, func(): m.fx.burst(at + Vector3(0, 0.5 + 0.7 * i, 0), col, 10, 1.5, 0.6, -3.0, 1.2))
		"storm":
			for i in 6:
				var a := TAU * float(i) / 6.0 + 0.3
				m.fx.bolt(at + Vector3(0, 1.0, 0), at + Vector3(cos(a) * 5.0 * big, 0.6, sin(a) * 5.0 * big), col)
		"quake":
			for i in 3:
				m.later(0.1 * i, func(): m.fx.ring(at, (2.0 + 1.6 * i) * big, Color(col, 0.8), 0.4))
			m.fx.dust(at, int(22 * big))
		"bloom":
			for i in 8:
				var a := TAU * float(i) / 8.0
				m.fx.burst(at + Vector3(cos(a) * 2.2 * big, 0.3, sin(a) * 2.2 * big), col, 7, 2.0, 0.7, -1.5)
		"prism":
			for i in 6:
				var a := TAU * float(i) / 6.0
				var c2 := Color.from_hsv(fposmod(col.h + 0.08 * i, 1.0), 0.55, 1.0)
				m.fx.bolt(at + Vector3(0, 1.1, 0), at + Vector3(cos(a) * 4.5 * big, 1.1, sin(a) * 4.5 * big), c2)
	m.fx.word(at + Vector3(0, 3.0, 0), String(form["word"]), col.lerp(Color.WHITE, 0.25), true)

# ------------------------------------------------------------------ the changes to your abilities
## The form you wear right now ({} when not merged).
static func of(h: Hunter) -> Dictionary:
	return h.merge_st.get("form", {}) if h != null and not h.merge_st.is_empty() else {}

## A class ability of a merged hunter hit a foe: the type's rider rides on it (Match.on_damage, src "abil").
static func on_ability_hit(h: Hunter, target: Ent, dmg: float, opts: Dictionary) -> void:
	var f := of(h)
	if f.is_empty() or opts.get("form", false) or target.remote or target.dead or target.team == h.team:
		return
	_apply(h, target, dmg, f["rider"], float(f["stun"]))

static func _apply(h: Hunter, t: Ent, dmg: float, r: Dictionary, stun: float) -> void:
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
	if stun > 0.0 and h.m.time >= float(t.get_meta("form_stun", -9.0)) + STUN_CD:
		var s := t.cc_dr("stun", stun)
		if s > 0.0:
			t.stun_t = maxf(t.stun_t, s)
			t.set_meta("form_stun", h.m.time)

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
	for t in h.m.foes_of(h.team):
		if t.dead or not t.hittable() or Vector2(t.pos.x - at.x, t.pos.z - at.z).length() > rad + t.r:
			continue
		var dmg: float = float(dd.get("burst", 6.0)) * h.m.dmg_mult(h)
		t.hurt(dmg, h, {"src": "abil", "ab": "form", "tags": ["dodge", "form"], "form": true})
		_apply(h, t, dmg, dd, 0.0)
