class_name Unique
## What makes each kin itself: a set of inborn rolls kept on its record in rec["dna"], so no two
## kin of the same species look, sound or act quite the same. See docs/BOKI_IDENTITY.md.
##
##   size     a bell curve (z-score, sd SIZE_SD of height); the tails are tagged XS and XL. Giant and
##            Tiny (Mutations) are the rarer extreme tier on top. Shown as cm / kg from the species'
##            base size (content/kin/<id>.json "size": {cm, kg}).
##   girth    stocky or slender (weight, and a touch of width on the model)
##   head, limb, tail, ear   proportions, each a scalar about 1 (at most +-PROP_MAX)
##   hue, sat, val           a small shift of the species palette
##   mark, mark_col, mark_seed   a coat pattern (spots, stripes, patches, freckles or plain), its
##            colour, and the seed that places it: two kin never wear the same marks
##   eye      eye colour (or the species' classic colour)
##   ears, tailv   shape variants for the ear/horn group and the tail
##   quirk    an idle habit (KinPuppet plays it)
##   voice    pitch of its sounds
##   birth    a birthmark [shape, place]
##   sex      "f" or "m", from the seed by a hash of its own (not the roll stream, so adding it
##            changed none of the other rolls; every Boki made before it gets the same answer)
##
## Everything rolls from one seed (rec["dna"]["seed"]) with its own RandomNumberGenerator, so it
## never touches the global random stream. Wild and bot kin get their seed from the match seed
## (Match.kin_seed), so a seeded match is repeatable; kin made at home get a fresh seed from the
## system's random bytes. Eggs blend both parents plus noise (inherit()).
##
## Size gives a small, capped trade-off in matches (SIZE_STAT: bigger is a little tougher and a
## little slower) and scales the hitbox. Both are switched off when the match is normalized
## (normalized(): Unique.normalize, or the match option "normalize_size"), the hook for ranked or
## low tiers to neutralize it later.

const V := 1
const SIZE_SD := 0.07          # sd of height, as a fraction of the species' base
const SIZE_Z_MAX := 3.0
const XS_Z := -2.0             # about 1 in 44 at each tail
const XL_Z := 2.0
const S_Z := -0.8
const L_Z := 0.8
const SIZE_STAT := 0.04        # the most size moves health and speed in a match (+-4%)
const SIZE_STAT_Z := 2.5       # the z where that cap is reached
const HIT_MIN := 0.7
const HIT_MAX := 1.4
const GIRTH_SD := 0.035
const GIRTH_MAX := 0.09
const PROPS := ["head", "limb", "tail", "ear"]
const PROP_SD := 0.04
const PROP_MAX := 0.10
const HUE_SD := 0.016
const HUE_MAX := 0.045
const SAT_SD := 0.06
const SAT_MAX := 0.15
const VAL_SD := 0.05
const VAL_MAX := 0.13
const VOICE_SD := 0.07
const VOICE_MIN := 0.82
const VOICE_MAX := 1.2
const FAV_FILL := 1.15         # a favourite food fills this much more (Care.feed)

## [id, weight]
const MARKS := [["plain", 14], ["spots", 26], ["stripes", 20], ["patches", 22], ["freckles", 18]]
const MARK_INFO := {
	"plain": {"name": "Plain coat", "k": 0, "scale": 9.0, "amt": 0.0},
	"spots": {"name": "Spotted", "k": 1, "scale": 9.0, "amt": 0.5},
	"stripes": {"name": "Striped", "k": 2, "scale": 7.0, "amt": 0.5},
	"patches": {"name": "Patched", "k": 3, "scale": 4.5, "amt": 0.5},
	"freckles": {"name": "Freckled", "k": 4, "scale": 20.0, "amt": 0.5},
}
const MARK_COLS := [["dark", 55], ["light", 38], ["glow", 7]]
const MARK_COL_NAMES := {"dark": "dark", "light": "pale", "glow": "glowing"}
## [id, weight, colour ("" = the species' own)]
const EYES := [["classic", 40, ""], ["amber", 8, "#f2a23a"], ["hazel", 7, "#9a7a3a"], ["moss", 7, "#5a9a3a"],
	["sky", 8, "#5aa8e8"], ["violet", 6, "#8a5ae0"], ["rose", 6, "#e05a8a"], ["gold", 5, "#f2d04a"],
	["jet", 5, "#2a2a3a"], ["ice", 4, "#bfe8ff"], ["ember", 4, "#e0482a"]]
const EAR_VARIANTS := [["standard", 50], ["splayed", 20], ["folded", 12], ["tufted", 18]]
const TAIL_VARIANTS := [["standard", 55], ["tufted", 20], ["kinked", 15], ["bobbed", 10]]
const VARIANT_NAMES := {"standard": "", "splayed": "Splayed ears", "folded": "Folded ears", "tufted": "Tufted ears",
	"t_tufted": "Tufted tail", "t_kinked": "Kinked tail", "t_bobbed": "Bobbed tail"}
const QUIRKS := [["tail_chase", 10], ["head_tilt", 16], ["hop", 14], ["sway", 14], ["sneeze", 10], ["stretch", 12],
	["ear_flick", 12], ["look_around", 12]]
const QUIRK_NAMES := {"tail_chase": "Chases its tail", "head_tilt": "Tilts its head at things", "hop": "Bounces on the spot",
	"sway": "Sways side to side", "sneeze": "Sneezes now and then", "stretch": "Stretches a lot",
	"ear_flick": "Flicks its ears", "look_around": "Always looking around"}
const BIRTH_SHAPES := [["star", 1], ["heart", 1], ["crescent", 1], ["diamond", 1], ["dot", 1], ["swirl", 1]]
const BIRTH_PLACES := [["left cheek", 1], ["right cheek", 1], ["brow", 1], ["left flank", 1], ["right flank", 1],
	["back", 1], ["chest", 1]]
## A species with no "size" in content/kin/<id>.json.
const DEFAULT_SIZE := {"cm": 30.0, "kg": 3.0}

## Normalized matches: size stops changing health, speed and the hitbox (looks stay).
static var normalize := false

static var _crypto: Crypto = null
static var _sizes := {}

# ------------------------------------------------------------------ seeds and rolls
## A fresh seed from the system's random bytes (never the global random stream).
static func fresh_seed() -> int:
	if _crypto == null: _crypto = Crypto.new()
	var b := _crypto.generate_random_bytes(4)
	return int(b.decode_u32(0)) & 0x7fffffff

static func _pick(r: RandomNumberGenerator, table: Array) -> String:
	var tot := 0.0
	for row in table: tot += float(row[1])
	var x := r.randf() * tot
	for row in table:
		x -= float(row[1])
		if x < 0.0: return String(row[0])
	return String(table[table.size() - 1][0])

static func _n(r: RandomNumberGenerator, sd: float, lim: float) -> float:
	return clampf(r.randfn(0.0, sd), -lim, lim)

static func _r4(x: float) -> float:
	return snappedf(x, 0.0001)

## Everything from one seed. The same seed always gives the same kin.
static func roll(seed: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var d := {"v": V, "seed": seed}
	d["size"] = _r4(clampf(r.randfn(0.0, 1.0), -SIZE_Z_MAX, SIZE_Z_MAX))
	d["girth"] = _r4(1.0 + _n(r, GIRTH_SD, GIRTH_MAX))
	for p in PROPS: d[p] = _r4(1.0 + _n(r, PROP_SD, PROP_MAX))
	d["hue"] = _r4(_n(r, HUE_SD, HUE_MAX))
	d["sat"] = _r4(_n(r, SAT_SD, SAT_MAX))
	d["val"] = _r4(_n(r, VAL_SD, VAL_MAX))
	d["mark"] = _pick(r, MARKS)
	d["mark_col"] = _pick(r, MARK_COLS)
	d["mark_seed"] = r.randi() & 0x7fffffff
	d["eye"] = _pick(r, EYES)
	d["ears"] = _pick(r, EAR_VARIANTS)
	d["tailv"] = _pick(r, TAIL_VARIANTS)
	d["quirk"] = _pick(r, QUIRKS)
	d["voice"] = _r4(clampf(1.0 + r.randfn(0.0, VOICE_SD), VOICE_MIN, VOICE_MAX))
	d["birth"] = [_pick(r, BIRTH_SHAPES), _pick(r, BIRTH_PLACES)]
	d["sex"] = sex_for_seed(seed)
	return d

# ------------------------------------------------------------------ sex
## A Boki's sex from its seed: half and half, never drawn from the roll stream (so it reads the
## same for a record that has its rolls and for one written before sex existed).
static func sex_for_seed(seed: int) -> String:
	return "f" if (hash("%d|sex" % seed) & 1) == 0 else "m"

## "f" or "m" ("" for a bare look-only record).
static func sex(rec: Dictionary) -> String:
	var d := of(rec)
	if d.is_empty():
		return ""
	var x := String(d.get("sex", ""))
	return x if x in ["f", "m"] else sex_for_seed(int(d.get("seed", 0)))

static func sex_name(rec: Dictionary) -> String:
	return {"f": "Female", "m": "Male"}.get(sex(rec), "")

## Writes the sex into a record's rolls if they don't have it yet (save migration).
static func ensure_sex(rec: Dictionary) -> void:
	if typeof(rec.get("dna", null)) == TYPE_DICTIONARY and rec["dna"].has("seed") and not rec["dna"].has("sex"):
		rec["dna"]["sex"] = sex_for_seed(int(rec["dna"]["seed"]))

## A record's rolls; a record without any (an old save, another player's kin) reads the ones its
## id gives, without being changed. {} for a bare look-only record (no uid, no dna).
static func of(rec: Dictionary) -> Dictionary:
	var d = rec.get("dna", null)
	if typeof(d) == TYPE_DICTIONARY and d.has("seed"):
		return d
	if String(rec.get("uid", "")) == "":
		return {}
	return roll(legacy_seed(String(rec["uid"])))

static func legacy_seed(uid: String) -> int:
	return hash(uid + "|dna") & 0x7fffffff

## Fills in rolls for a record that has none (from its id, so it's the same every time).
static func ensure(rec: Dictionary) -> void:
	if rec.is_empty() or (typeof(rec.get("dna", null)) == TYPE_DICTIONARY and rec["dna"].has("seed")):
		return
	rec["dna"] = roll(legacy_seed(String(rec.get("uid", "x"))))

## An egg's rolls: a blend of both parents with some noise of its own, from child_seed (so a
## seeded breed is repeatable). Size and proportions are heritable but regress a little toward
## the middle; pattern, eye colour and shapes come from one parent or (now and then) are new;
## placement of marks, the birthmark and most quirks are always the egg's own.
static func inherit(a: Dictionary, b: Dictionary, child_seed: int) -> Dictionary:
	var da := of(a)
	var db := of(b)
	var d := roll(child_seed)
	if da.is_empty() or db.is_empty():
		return d
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%d|%d|inherit" % [int(da.get("seed", 0)), int(db.get("seed", 0)), child_seed])
	# size: 0.4 of each parent's z plus fresh noise, so the spread stays about the same
	d["size"] = _r4(clampf(0.4 * (float(da["size"]) + float(db["size"])) + r.randfn(0.0, 0.82), -SIZE_Z_MAX, SIZE_Z_MAX))
	d["girth"] = _r4(clampf((float(da["girth"]) + float(db["girth"])) * 0.5 + r.randfn(0.0, GIRTH_SD * 0.7), 1.0 - GIRTH_MAX, 1.0 + GIRTH_MAX))
	for p in PROPS:
		d[p] = _r4(clampf((float(da.get(p, 1.0)) + float(db.get(p, 1.0))) * 0.5 + r.randfn(0.0, PROP_SD * 0.7), 1.0 - PROP_MAX, 1.0 + PROP_MAX))
	d["hue"] = _r4(clampf((float(da["hue"]) + float(db["hue"])) * 0.5 + r.randfn(0.0, HUE_SD * 0.6), -HUE_MAX, HUE_MAX))
	d["sat"] = _r4(clampf((float(da["sat"]) + float(db["sat"])) * 0.5 + r.randfn(0.0, SAT_SD * 0.6), -SAT_MAX, SAT_MAX))
	d["val"] = _r4(clampf((float(da["val"]) + float(db["val"])) * 0.5 + r.randfn(0.0, VAL_SD * 0.6), -VAL_MAX, VAL_MAX))
	d["voice"] = _r4(clampf((float(da["voice"]) + float(db["voice"])) * 0.5 + r.randfn(0.0, VOICE_SD * 0.6), VOICE_MIN, VOICE_MAX))
	for k in ["mark", "mark_col", "eye"]:
		var x := r.randf()
		if x < 0.45: d[k] = da[k]
		elif x < 0.9: d[k] = db[k]
	for k in ["ears", "tailv"]:
		var x := r.randf()
		if x < 0.4: d[k] = da[k]
		elif x < 0.8: d[k] = db[k]
	var q := r.randf()
	if q < 0.25: d["quirk"] = da["quirk"]
	elif q < 0.5: d["quirk"] = db["quirk"]
	d["from"] = [int(da.get("seed", 0)), int(db.get("seed", 0))]
	return d

## The look inherit() rolls around for these two: their size, build, proportions and colour shifts
## averaged the same way, with no noise and a plain coat ({} when either has no rolls).
static func blend_center(a: Dictionary, b: Dictionary) -> Dictionary:
	var da := of(a)
	var db := of(b)
	if da.is_empty() or db.is_empty():
		return {}
	var d := da.duplicate()
	d["size"] = _r4(clampf(0.4 * (float(da["size"]) + float(db["size"])), -SIZE_Z_MAX, SIZE_Z_MAX))
	for k in ["girth", "hue", "sat", "val", "voice"] + PROPS:
		d[k] = _r4((float(da.get(k, 1.0)) + float(db.get(k, 1.0))) * 0.5)
	d["mark"] = "plain"
	return d

# ------------------------------------------------------------------ size
static func base_size(species: String) -> Dictionary:
	if _sizes.has(species):
		return _sizes[species]
	var j: Dictionary = Content._load("kin", species)
	var s = j.get("size", null)
	var out := DEFAULT_SIZE.duplicate()
	if typeof(s) == TYPE_DICTIONARY:
		out = {"cm": float(s.get("cm", DEFAULT_SIZE["cm"])), "kg": float(s.get("kg", DEFAULT_SIZE["kg"]))}
	_sizes[species] = out
	return out

## Height as a multiple of the species' base, from the bell-curve roll alone.
static func height_k(rec: Dictionary) -> float:
	var d := of(rec)
	return 1.0 + float(d.get("size", 0.0)) * SIZE_SD

## The Giant / Tiny mutation's scale on top (1.0 without).
static func mut_scale(rec: Dictionary) -> float:
	var s := 1.0
	for id in Mutations.of(rec):
		s *= clampf(float((Mutations.info(id).get("visual", {}) as Dictionary).get("scale", 1.0)), 0.6, 1.45)
	return s

## The whole size, roll times mutation: what the model and the hitbox use.
static func size_scale(rec: Dictionary) -> float:
	return height_k(rec) * mut_scale(rec)

static func size_tag(rec: Dictionary) -> String:
	var z := float(of(rec).get("size", 0.0))
	if z <= XS_Z: return "XS"
	if z >= XL_Z: return "XL"
	if z <= S_Z: return "S"
	if z >= L_Z: return "L"
	return "M"

## {cm, kg, tag, z, build}: its height and weight as shown to the player.
static func size_info(rec: Dictionary) -> Dictionary:
	var d := of(rec)
	var b := base_size(String(rec.get("species", "")))
	var h := size_scale(rec)
	var g := float(d.get("girth", 1.0))
	var build := "slender" if g < 0.975 else ("stocky" if g > 1.025 else "")
	return {"cm": float(b["cm"]) * h, "kg": float(b["kg"]) * h * h * h * g * g, "tag": size_tag(rec),
		"z": float(d.get("size", 0.0)), "build": build}

## Is size neutralized here? (Unique.normalize, or the match's "normalize_size" option.)
static func normalized(match_node: Object = null) -> bool:
	if normalize:
		return true
	if match_node != null:
		var o = match_node.get("opts")
		if typeof(o) == TYPE_DICTIONARY and bool(o.get("normalize_size", false)):
			return true
	return false

## Size's small trade-off in a match: {"hp", "speed"} multipliers, at most +-SIZE_STAT.
static func match_mods(rec: Dictionary, norm := false) -> Dictionary:
	if norm or rec.is_empty():
		return {"hp": 1.0, "speed": 1.0}
	var t := clampf(float(of(rec).get("size", 0.0)) / SIZE_STAT_Z, -1.0, 1.0)
	return {"hp": 1.0 + SIZE_STAT * t, "speed": 1.0 - SIZE_STAT * t}

## How much its hitbox grows or shrinks with its size (1.0 when normalized).
static func hit_scale(rec: Dictionary, norm := false) -> float:
	if norm or rec.is_empty():
		return 1.0
	return clampf(size_scale(rec), HIT_MIN, HIT_MAX)

# ------------------------------------------------------------------ colour, voice, words
static func tint(c: Color, d: Dictionary) -> Color:
	if d.is_empty():
		return c
	var h := fposmod(c.h + float(d.get("hue", 0.0)), 1.0)
	var s := clampf(c.s * (1.0 + float(d.get("sat", 0.0))), 0.0, 1.0)
	var v := clampf(c.v * (1.0 + float(d.get("val", 0.0))), 0.0, 1.0)
	return Color.from_hsv(h, s, v, c.a)

## Its iris colour, or `classic` (the species' own) when it has the classic eyes.
static func iris(rec: Dictionary, classic: Color) -> Color:
	var e := String(of(rec).get("eye", "classic"))
	for row in EYES:
		if String(row[0]) == e and String(row[2]) != "":
			return Color(String(row[2]))
	return classic

static func eye_name(rec: Dictionary) -> String:
	var e := String(of(rec).get("eye", "classic"))
	return "Classic" if e == "classic" else e.capitalize()

static func eye_col(rec: Dictionary) -> Color:
	var sp: Dictionary = Data.KIN.get(String(rec.get("species", "")), {})
	var g: Color = sp.get("glow", sp.get("color", Color.WHITE))
	return iris(rec, g.lerp(sp.get("color", g), 0.35).darkened(0.08))

## Pitch for its sounds (1.0 for a record with no rolls).
static func voice(rec: Dictionary) -> float:
	return float(of(rec).get("voice", 1.0)) if not rec.is_empty() else 1.0

static func voice_word(rec: Dictionary) -> String:
	var v := voice(rec)
	if v < 0.9: return "Deep voice"
	if v > 1.1: return "High voice"
	return "Ordinary voice"

static func mark_name(rec: Dictionary) -> String:
	var d := of(rec)
	var m := String(d.get("mark", "plain"))
	if m == "plain": return "Plain coat"
	return "%s (%s)" % [String(MARK_INFO.get(m, {}).get("name", m.capitalize())), String(MARK_COL_NAMES.get(String(d.get("mark_col", "dark")), "dark"))]

static func quirk_name(rec: Dictionary) -> String:
	return String(QUIRK_NAMES.get(String(of(rec).get("quirk", "")), "None"))

static func birthmark_text(rec: Dictionary) -> String:
	var b = of(rec).get("birth", [])
	if typeof(b) != TYPE_ARRAY or (b as Array).size() < 2: return ""
	return "a %s-shaped mark on its %s" % [String(b[0]), String(b[1])]

## Its shape variants in words ("Folded ears, tufted tail"), "" if both are standard.
static func shape_text(rec: Dictionary) -> String:
	var d := of(rec)
	var bits: Array = []
	var e := String(d.get("ears", "standard"))
	if e != "standard": bits.append(String(VARIANT_NAMES.get(e, e)))
	var t := String(d.get("tailv", "standard"))
	if t != "standard": bits.append(String(VARIANT_NAMES.get("t_" + t, t)))
	return ", ".join(bits)

## Proportions that stand out ("long legs, big ears"), "" if none.
static func prop_text(rec: Dictionary) -> String:
	var d := of(rec)
	var words := {"head": ["small head", "big head"], "limb": ["short legs", "long legs"], "tail": ["short tail", "long tail"], "ear": ["small ears", "big ears"]}
	var bits: Array = []
	for p in PROPS:
		var x := float(d.get(p, 1.0))
		if x <= 0.95: bits.append(words[p][0])
		elif x >= 1.05: bits.append(words[p][1])
	return ", ".join(bits)

# ------------------------------------------------------------------ the model
static func _albedo(m) -> Color:
	return (m as ShaderMaterial).get_shader_parameter("albedo") if m is ShaderMaterial else Color.WHITE

static func _set_albedo(m, c: Color) -> void:
	if m is ShaderMaterial: (m as ShaderMaterial).set_shader_parameter("albedo", c)

## Dresses a built kin model (Models.kin, before Mutations.dress): palette shift, coat marks,
## proportions, shape variants, a birthmark, its size, and the metas KinPuppet reads (quirk, girth).
static func dress(root: Node3D, rec: Dictionary) -> void:
	var d := of(rec)
	if d.is_empty():
		return
	var mats: Array = root.get_meta("mats", [])
	var flex: Node3D = root.get_node_or_null("Body/Flex")
	var sp: Dictionary = Data.KIN.get(String(rec.get("species", "")), {})
	# colour: body, belly and dark shift a little together (a shimmer or a ghost keeps its
	# hand-picked palette exactly)
	if not rec.get("shimmer", false) and not rec.get("ghost", false):
		for i in mini(3, mats.size()):
			_set_albedo(mats[i], tint(_albedo(mats[i]), d))
	# coat marks on the body material (toon shader mark_*), placed from its own seed
	var mk := String(d.get("mark", "plain"))
	var mi: Dictionary = MARK_INFO.get(mk, MARK_INFO["plain"])
	if int(mi["k"]) > 0 and mats.size() > 0 and mats[0] is ShaderMaterial:
		var body_c := _albedo(mats[0])
		var mc := body_c.darkened(0.42)
		match String(d.get("mark_col", "dark")):
			"light": mc = body_c.lerp(_albedo(mats[1]) if mats.size() > 1 else Color.WHITE, 0.6).lightened(0.25)
			"glow": mc = (sp.get("glow", body_c) as Color)
		var r := RandomNumberGenerator.new(); r.seed = int(d.get("mark_seed", 0))
		var m0 := mats[0] as ShaderMaterial
		m0.set_shader_parameter("mark_kind", int(mi["k"]))
		m0.set_shader_parameter("mark_color", mc)
		m0.set_shader_parameter("mark_seed", Vector3(r.randf_range(-50.0, 50.0), r.randf_range(-50.0, 50.0), r.randf_range(-50.0, 50.0)))
		m0.set_shader_parameter("mark_scale", float(mi["scale"]) * r.randf_range(0.85, 1.2))
		m0.set_shader_parameter("mark_amt", clampf(float(mi["amt"]) + r.randf_range(-0.12, 0.12), 0.2, 0.8))
		if String(d.get("mark_col", "")) == "glow": m0.set_shader_parameter("mark_glow", 0.6)
	if flex:
		_proportions(flex, d, String(rec.get("species", "")))
		_variants(flex, d, mats)
		_birthmark(flex, d, mats)
		var rig := flex.get_node_or_null("BokiRig") as BokiRig
		if rig:
			BokiDna.wear(rig.skeleton(), flex, d, mats, rec)
	root.set_meta("quirk", String(d.get("quirk", "")))
	root.set_meta("girth", float(d.get("girth", 1.0)))
	root.set_meta("voice", float(d.get("voice", 1.0)))
	# size: the bell-curve roll (Giant and Tiny scale on top in Mutations.dress)
	var hk := height_k(rec)
	if absf(hk - 1.0) > 0.001:
		var es := float(root.get_meta("evo_scale", 1.0)) * hk
		root.set_meta("evo_scale", es)
		root.scale = Vector3.ONE * es

static func _proportions(flex: Node3D, d: Dictionary, species: String) -> void:
	var ears: Node3D = flex.get_node_or_null("Ears")
	if ears: ears.scale *= float(d.get("ear", 1.0))
	var tail: Node3D = flex.get_node_or_null("Tail")
	if tail: tail.scale *= float(d.get("tail", 1.0))
	var hk := float(d.get("head", 1.0))
	for nm in ["EyeL", "EyeR", "ShineL", "ShineR"]:
		var e: Node3D = flex.get_node_or_null(nm)
		if e: e.scale *= hk
	var lk := float(d.get("limb", 1.0))
	var legs: Node3D = flex.get_node_or_null("Legs")
	if legs and absf(lk - 1.0) > 0.001:
		var hip := 0.0
		for l in legs.get_children():
			if String(l.name).begins_with("Leg"):
				(l as Node3D).scale.y *= lk
				hip = maxf(hip, (l as Node3D).position.y)
		# longer legs stand it taller (its feet stay on the ground); flyers' legs just dangle
		if String(KinPuppet.BODY.get(species, "blob")) in ["quad", "biped"]:
			flex.position.y += hip * (lk - 1.0) * 0.9

## Splits a group's children into a left and a right pivot (by which side of the middle they sit).
static func _split(group: Node3D) -> Array:
	var l := Node3D.new(); l.name = "VarL"
	var r := Node3D.new(); r.name = "VarR"
	var kids := group.get_children()
	group.add_child(l); group.add_child(r)
	for ch in kids:
		if not (ch is Node3D): continue
		var side: Node3D = l if (ch as Node3D).position.x < 0.0 else r
		ch.reparent(side, false)
	return [l, r]

## The top (highest point) of everything under a node, in that node's space.
static func _top(n: Node3D) -> Vector3:
	var best := Vector3(0, -1e9, 0)
	for ch in n.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh:
			var mi := ch as MeshInstance3D
			var ab := mi.mesh.get_aabb()
			for i in 8:
				var p := mi.transform * ab.get_endpoint(i)
				if p.y > best.y: best = p
		elif ch is Node3D:
			var p2 := (ch as Node3D).transform * _top(ch)
			if p2.y > best.y: best = p2
	return best

## The point of a group farthest from its pivot (the tip of a tail).
static func _far(n: Node3D) -> Vector3:
	var best := Vector3.ZERO
	for ch in n.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh:
			var mi := ch as MeshInstance3D
			var c := mi.transform * mi.mesh.get_aabb().get_center()
			if c.length() > best.length(): best = c
	return best

static func _variants(flex: Node3D, d: Dictionary, mats: Array) -> void:
	var tuft_m: Material = mats[1] if mats.size() > 1 else Models.toon(Color.WHITE)
	var ears: Node3D = flex.get_node_or_null("Ears")
	var ev := String(d.get("ears", "standard"))
	if ears and ears.get_child_count() > 0 and ev != "standard":
		var lr := _split(ears)
		match ev:
			"splayed":
				(lr[0] as Node3D).rotation.z = 0.32; (lr[1] as Node3D).rotation.z = -0.32
			"folded":
				for s in lr:
					(s as Node3D).rotation.x = -0.42
					(s as Node3D).scale = Vector3(1.0, 0.88, 1.0)
			"tufted":
				for s in lr:
					if (s as Node3D).get_child_count() == 0: continue
					var tp := _top(s)
					if tp.y > -1e8:
						Models.part(s, Models.sphere(0.035, 6), tuft_m, tp + Vector3(0, 0.012, 0), Vector3(0.8, 1.4, 0.8), Vector3.ZERO, "Tuft")
	var tail: Node3D = flex.get_node_or_null("Tail")
	var tv := String(d.get("tailv", "standard"))
	if tail and tail.get_child_count() > 0:
		match tv:
			"tufted":
				var tip := _far(tail)
				Models.part(tail, Models.sphere(0.06, 8), tuft_m, tip, Vector3(1.0, 1.0, 1.3), Vector3.ZERO, "TailTuft")
			"kinked":
				tail.rotation.z = 0.32 if int(d.get("mark_seed", 0)) % 2 == 0 else -0.32
			"bobbed":
				tail.scale *= 0.7

## A small mark on the main body part, on the side its birthmark names (flank, back, chest); the
## face ones (cheek, brow) are words only.
static func _birthmark(flex: Node3D, d: Dictionary, mats: Array) -> void:
	var b = d.get("birth", [])
	if typeof(b) != TYPE_ARRAY or (b as Array).size() < 2 or mats.is_empty():
		return
	var place := String(b[1])
	if not place in ["left flank", "right flank", "back", "chest"]:
		return
	# the biggest piece wearing the body material
	var best: MeshInstance3D = null
	var bv := 0.0
	for ch in flex.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).material_override == mats[0] and (ch as MeshInstance3D).mesh:
			var ab := (ch as MeshInstance3D).mesh.get_aabb()
			var vol := ab.size.x * ab.size.y * ab.size.z * absf((ch as MeshInstance3D).basis.determinant())
			if vol > bv: bv = vol; best = ch
	if best == null:
		return
	var ab2 := best.mesh.get_aabb()
	var c := ab2.get_center()
	var hs := ab2.size * 0.5
	var pts := [c + Vector3(hs.x, 0, 0), c - Vector3(hs.x, 0, 0), c + Vector3(0, hs.y, 0), c - Vector3(0, hs.y, 0), c + Vector3(0, 0, hs.z), c - Vector3(0, 0, hs.z)]
	var pick := Vector3.ZERO
	var score := -1e9
	var nrm := Vector3.UP
	for p in pts:
		var q: Vector3 = best.transform * p
		var s := 0.0
		match place:
			"left flank": s = -q.x
			"right flank": s = q.x
			"back": s = q.y + q.z * 0.3
			"chest": s = -q.z
		if s > score:
			score = s; pick = q
			nrm = (best.basis * (p - c)).normalized()
	var col: Color = _albedo(mats[0]).darkened(0.5) if _albedo(mats[0]).v > 0.45 else _albedo(mats[0]).lightened(0.55)
	var bm := Models.toon(col, false)
	var m := Models.part(flex, Models.sphere(0.042, 8), bm, pick + nrm * 0.004, Vector3(1.0, 0.25, 1.0), Vector3.ZERO, "Birthmark")
	m.basis = Basis(Quaternion(Vector3.UP, nrm)) * Basis.from_scale(Vector3(1.0, 0.25, 1.0))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
