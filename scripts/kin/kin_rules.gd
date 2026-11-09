class_name KinRules
extends RefCounted
## Runtime rules for the kin grammar (docs/KIN_GRAMMAR.md, "Runtime rules"). These are core: no data
## file can change them. The executor (KinExec), the body (Ent.hurt) and the verbs (walls, mirrors)
## all read the numbers here, so the checker's caps and the game's caps are the same caps.
##
##   diminishing returns  repeated slow, root and stun on one target get shorter (DR_STEPS), and a
##                        target coming out of a stun can't be stunned or rooted for STUN_IMMUNE s.
##                        Zones, pulses and auras go through the same path, so nothing can stun-lock.
##   no self-trigger      an ability never fires because of its own hits (see KinExec.trigger)
##   caps                 reflected shots never reflect again; reflect power <= REFLECT_MAX;
##                        a vulnerable mark adds at most VULN_MAX damage taken; every number an
##                        ability ends up with (ranks, merges, sidegrades) is clamped to its part's bounds
##   slot locks           a kin's abilities are locked until its slot is unlocked with a skill point;
##                        the merge until run level Hunter.ULT_AT[0]

# ---- diminishing returns ----
const DR_WINDOW := 5.0             # seconds since the last one before a target's count resets
const DR_STEPS := {
	"stun": [1.0, 0.6, 0.35, 0.0],   # the 4th stun inside the window doesn't land at all
	"root": [1.0, 0.6, 0.35, 0.0],
	"slow": [1.0, 0.75, 0.5, 0.35],  # slows never stop working, but a fresh one is weaker each time
}
const STUN_IMMUNE := 0.8           # after a stun ends: no stun or root for this long

# ---- hard caps ----
const VULN_MAX := 0.35
const REFLECT_MAX := 1.5
const DEFAULT_SLOW := 0.35         # a slow with no strength (old content) takes this much speed away

# ---- growth: small, and capped by the expedition tier (Meadow, Dusk Isles, the Hollow) ----
const LEVEL_GROWTH := 0.03         # per kin level past the first: kin health, damage and ability power
const LEVEL_CAP := [0.15, 0.25, 0.35]

## How much a kin's level adds (0 .. the tier's cap).
static func level_growth(level: int, tier: int) -> float:
	return minf(LEVEL_GROWTH * float(maxi(0, level - 1)), float(LEVEL_CAP[clampi(tier, 0, LEVEL_CAP.size() - 1)]))

# ---- ranks: skill points into the kin's slot grow its numbers through this core table ----
## Fraction per rank past the first. Damage grows through power (+15% a rank, Effects.level_k), not here.
## Dash, leap and blink distances never grow.
const RANK_GROW := {
	"stun": {"duration": 0.15}, "root": {"duration": 0.15}, "slow": {"duration": 0.15},
	"pull": {"strength": 0.15}, "shield": {"amount": 0.15, "duration": 0.1}, "heal": {"amount": 0.15},
	"mark": {"duration": 0.2}, "buff": {"duration": 0.2}, "reflect": {"duration": 0.2},
	"wall": {"hp": 0.2, "duration": 0.15, "length": 0.1}, "zone": {"duration": 0.15, "radius": 0.1},
	"trap": {"duration": 0.15, "radius": 0.1}, "aura": {"duration": 0.15}, "tether": {"duration": 0.15},
	"summon": {"duration": 0.15}, "projectile": {"range": 0.1}, "burst": {"radius": 0.08},
	"cone": {"radius": 0.08}, "beam": {"range": 0.05}, "chain": {"count": 0.34},
}

# ---- readability: colour means effect category, never a theme ----
const CAT_COLORS := {
	"damage": Color("ff7a52"),
	"control": Color("b48cff"),
	"sustain": Color("6fe8a6"),
	"utility": Color("ffd84a"),
}
const CAT_ORDER := ["control", "damage", "sustain", "utility"]   # which colour a mixed stage takes

static func cat_color(cat: String) -> Color:
	return CAT_COLORS.get(cat, Color("e8f4ff"))

## The colour of a list of effects: the most important category it has (crowd control first,
## because that's what you need to dodge).
static func effects_color(effs: Array) -> Color:
	var cats := {}
	for e in effs:
		cats[(e as PartSpec).category()] = true
	for c in CAT_ORDER:
		if cats.has(c): return cat_color(c)
	return Color("e8f4ff")

# ---- bounds ----
## A number clamped to its part parameter's bounds (ints rounded).
static func clamp_param(kind: String, type: String, key: String, v: float) -> Variant:
	var pd: Array = KinParts.params_of(kind, type).get(key, [])
	if kind == "effect" and type == "signature" and pd.is_empty():
		for sig in KinParts.SIGNATURES:
			if (KinParts.SIGNATURES[sig]["params"] as Dictionary).has(key):
				pd = KinParts.SIGNATURES[sig]["params"][key]
	if pd.is_empty() or not String(pd[0]) in ["int", "float"]:
		return v
	var out := clampf(v, float(pd[1]), float(pd[2]))
	return int(roundf(out)) if String(pd[0]) == "int" else out

## Every numeric parameter of a part pulled back inside its bounds (the runtime half of the caps).
static func clamp_part(p: PartSpec) -> void:
	for key in p.params:
		var v = p.params[key]
		if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
			p.params[key] = clamp_param(p.kind, p.type, key, float(v))
	if p.kind == "effect" and p.type == "mark" and String(p.params.get("mode", "")) == "vulnerable":
		p.params["amount"] = minf(float(p.params["amount"]), VULN_MAX)

# ---- marks ----
## Reveal, vulnerable or blight on a body. Vulnerable never adds more than VULN_MAX damage taken.
static func mark(t: Ent, mode: String, dur: float, amount: float) -> void:
	if t == null or t.dead or dur <= 0.0:
		return
	match mode:
		"reveal":
			if "reveal_t" in t:
				t.set("reveal_t", maxf(float(t.get("reveal_t")), dur))
		"vulnerable":
			t.vuln_t = maxf(t.vuln_t, dur)
			t.vuln_k = clampf(maxf(t.vuln_k if t.vuln_t > 0.0 else 0.0, amount), 0.0, VULN_MAX)
		"blight":
			t.blight_t = maxf(t.blight_t, dur)
			t.blight_k = clampf(amount, 0.0, 0.9) if amount > 0.0 else 0.6

## A merge or sidegrade multiplier pulled inside its allowed range.
static func merge_scale(k: float) -> float:
	return clampf(k, float(KinParts.MERGED_SCALE[0]), float(KinParts.MERGED_SCALE[1]))
