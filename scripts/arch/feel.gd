class_name Feel
extends RefCounted
## The global feel spec (docs/DASHES_AND_ABILITY_FEEL.md §5), derived from what actually happened
## and from grammar parts, so archetype abilities, kin abilities and community kin all get the same
## telegraph floors, hitstop, screen shake, sound layering and category colours without any data
## file setting them. Data can lengthen a telegraph (a delay), never shorten it.

# ---- §5.1 effect categories: fill colour says what it does ----
const CAT := {
	"damage": Color("ff7a3d"),
	"control": Color("c46bff"),
	"sustain": Color("b8f06a"),     # heal
	"shield": Color("fff1b8"),      # shield and reflect (sustain, white-gold)
	"utility": Color("5fd8ff"),
}
const CAT_ORDER := ["control", "damage", "sustain", "utility"]
## §5.2 allegiance: rim says whose it is.
const RIM_ENEMY := Color("ff2d55")
const RIM_OWN := Color(1, 1, 1, 0.9)

static func cat_color(cat: String) -> Color:
	return CAT.get(cat, Color("e8f4ff"))

## The colour a stage takes: its highest-priority category (control > damage > sustain > utility).
static func stage_category(effs: Array) -> String:
	var cats := {}
	for e in effs:
		var c := (e as PartSpec).category() if e is PartSpec else KinParts.category(String((e as Dictionary).get("type", "")))
		cats[c] = true
	for c in CAT_ORDER:
		if cats.has(c): return c
	return "utility"

# ---- §5.3 telegraph floors ----
## Severity -> delivery kind -> the least enemy-visible time from the first tell to the effect.
## "instant": a burst / zone / cone / beam at range or a leap landing; "projectile": a cast glint
## (travel time also counts); "trap": the click before it fires; "self": a ring around the caster.
const FLOOR := {
	"hard_cc": {"instant": 0.40, "projectile": 0.15, "trap": 0.15, "self": 0.30},
	"soft_cc": {"instant": 0.30, "projectile": 0.0, "trap": 0.10, "self": 0.20},
	"heavy_dmg": {"instant": 0.20, "projectile": 0.0, "trap": 0.0, "self": 0.15},
	"chip": {"instant": 0.0, "projectile": 0.0, "trap": 0.0, "self": 0.0},
}
const KIN_TELL := 0.25        # an auto cast (kin-triggered): an eye and glow flare plus a bark
const MERGE_TELL := 0.35      # merges and bonded R: a transform tell with a column
const HARD_DMG := 22.0        # >= 15% of a medium hunter's health counts as heavy damage

## How dangerous a list of effects is: hard_cc | soft_cc | heavy_dmg | chip.
static func severity(effs: Array, mods: Array = []) -> String:
	var dmg := 0.0
	var soft := false
	var lift := false
	for e0 in effs:
		var t := ""; var p := {}
		if e0 is PartSpec:
			t = (e0 as PartSpec).type; p = (e0 as PartSpec).params
		elif e0 is Dictionary:
			t = String(e0.get("type", "")); p = e0
		match t:
			"stun":
				if float(p.get("duration", 0.0)) >= 0.5: return "hard_cc"
				soft = true
			"root":
				if float(p.get("duration", 0.0)) >= 1.0: return "hard_cc"
				soft = true
			"pull":
				if String(p.get("to", "center")) in ["caster", "owner"] and float(p.get("strength", 0.0)) >= 20.0: return "hard_cc"
				soft = true
			"signature":
				if String(p.get("id", "")) == "swap": return "hard_cc"
			"lift":
				lift = true; soft = true
			"slow", "push":
				soft = true
			"damage":
				if float(p.get("over", 0.0)) <= 0.0: dmg += float(p.get("amount", 0.0))
	for md in mods:
		var mt := (md as PartSpec).type if md is PartSpec else String((md as Dictionary).get("type", ""))
		if mt == "spike" and lift: return "hard_cc"
	if soft: return "soft_cc"
	if dmg >= HARD_DMG: return "heavy_dmg"
	return "chip"

## Which column of FLOOR a delivery falls in.
static func kind_of(delivery: String, origin: String) -> String:
	match delivery:
		"projectile", "tether": return "projectile"
		"trap": return "trap"
		"burst", "zone", "aura":
			return "self" if origin in ["caster", "owner"] else "instant"
		"cone", "beam": return "instant"
		"leap": return "instant"
	return "self"

## The floor for one grammar stage, and how much of it the stage already covers by itself
## (its own delay, a leap's flight, a projectile's travel at 2/3 range). Returns the windup to add.
static func missing_windup(st: StageSpec) -> float:
	if st == null or st.delivery == null:
		return 0.0
	var dt := st.delivery.type
	var sev := severity(st.effects, st.modifiers)
	var kind := kind_of(dt, String(st.delivery.params.get("origin", "caster")))
	var need := float(FLOOR[sev][kind])
	if need <= 0.0:
		return 0.0
	var have := 0.0
	var dl := st.modifier("delay")
	if dl: have = float(dl.params["time"])
	match dt:
		"leap": have = maxf(have, float(st.delivery.params.get("time", 0.5)))
		"projectile":
			var spd := maxf(1.0, float(st.delivery.params.get("speed", 30.0)))
			have = maxf(have, float(st.delivery.params.get("range", 9.0)) * 0.667 / spd)
			need = maxf(need, 0.2 if sev == "soft_cc" else (0.25 if sev == "hard_cc" else 0.0))
			if have < need: need = 0.15      # or a 0.15s cast glint plus the visible projectile
			have = 0.0 if have < need else have
		"trap": have = maxf(have, 0.0)
	return maxf(0.0, need - have)

## Floor for a plain severity + kind (archetype abilities state their own tells; this checks them).
static func floor_for(sev: String, kind: String) -> float:
	return float(FLOOR.get(sev, FLOOR["chip"]).get(kind, 0.0))

## Should this cast's telegraph floor be inserted? Rivals' casts always (what you have to react
## to), and every cast online, where each client runs its own hunter.
static func floors_apply(m: Node, team: int) -> bool:
	if m == null:
		return false
	if bool(m.get("net_on")):
		return true
	var p = m.get("player")
	return p != null and int(p.team) != team

# ---- §5.4 hitstop ----
## Tier -> [attacker (melee), target] seconds. Projectiles never freeze the attacker.
const HITSTOP := [[0.0, 0.0], [0.0, 0.025], [0.035, 0.045], [0.05, 0.065], [0.07, 0.09], [0.10, 0.0]]
const HS_CAP := 0.11           # at most this much freeze in any 0.5s per player
const HS_WINDOW := 0.5
const HS_MULTI := 0.25         # further hits on the same pair inside this get a third of their tier
static var _pair_t := {}       # "a|b" -> last time
static var _budget := {}       # nid -> [window start, spent]

## The hitstop tier of one hit (T0..T5), from what it did (§5.4 table).
static func tier(target: Ent, d: float, o: Dictionary) -> int:
	if String(o.get("src", "")) in ["burn", "fall", "heat", "mob"] or o.get("tick", false):
		return 0
	if o.get("bonded", false) or o.get("merge_start", false):
		return 5
	if o.get("payoff", false) or o.get("spiked", false) or o.get("exploit", false) or String(o.get("src", "")) == "wall":
		return 4
	var mh := maxf(1.0, target.max_hp)
	var cc := float(o.get("stun", 0.0)) > 0.0 or float(o.get("root", 0.0)) > 0.0 or float(o.get("lift", 0.0)) > 0.0
	if cc or d >= mh * 0.15:
		return 3
	var kb: Vector2 = o.get("kb", Vector2.ZERO) if o.get("kb", null) is Vector2 else Vector2.ZERO
	if d >= mh * 0.08 or kb.length() >= 8.0 or o.get("reflected", false):
		return 2
	if d > 0.0 and float(o.get("slow", 0.0)) <= 0.0:
		return 1
	return 0

static func is_melee(by: Ent, target: Ent, o: Dictionary) -> bool:
	if o.get("melee", false):
		return true
	var tags: Array = o.get("tags", [])
	if tags.has("dodge"):
		return true
	return by != null and is_instance_valid(by) and by.flat_dist(target) <= 2.6 and String(o.get("src", "")) == "abil"

## Applies the hitstop of a hit. Offline it uses the global freeze when the local player is one of
## the two involved; online (and for everyone else's fights) it freezes only the two bodies' visuals
## (Ent.freeze_t), never the simulation.
static func hitstop(m: Node, by: Ent, target: Ent, d: float, o: Dictionary) -> int:
	var t := tier(target, d, o)
	if t <= 0 or m == null:
		return t
	var now := float(m.time)
	var key := "%s|%s" % [by.get_instance_id() if by else 0, target.get_instance_id()]
	var k := 1.0
	if now - float(_pair_t.get(key, -9.0)) < HS_MULTI:
		k = 1.0 / 3.0
	if (o.get("echo", false)):
		k = minf(k, 0.5)
	_pair_t[key] = now
	var melee := is_melee(by, target, o)
	var ta := float(HITSTOP[t][0]) * k if melee else 0.0
	var tt := float(HITSTOP[t][1]) * k
	if t == 5 and by: ta = float(HITSTOP[5][0])
	var p = m.get("player")
	var mine: bool = p != null and (by == p or target == p or (by is Kin and (by as Kin).owner_h == p))
	if not bool(m.get("net_on")) and mine:
		var want := tt if target == p else (ta if melee else 0.0)
		# a payoff you land (Cash In, a wall slam, a spike) freezes you too, even from range
		if t >= 4 and by == p: want = maxf(want, float(HITSTOP[t][0]) * k)
		if want > 0.0: m.freeze_frame(want)
		# your ranged hits never freeze you (Capcom), but the body you (or your Boki) hit still holds for its tier
		if target and target != p: target.freeze_t = maxf(target.freeze_t, tt)
	else:
		if target: target.freeze_t = maxf(target.freeze_t, tt)
		if by and melee: by.freeze_t = maxf(by.freeze_t, ta)
	return t

## How much of a `want` s freeze the player may still take: at most HS_CAP in any HS_WINDOW, whatever asked for it.
static func spend(p: Ent, want: float, now: float) -> float:
	if p == null or want <= 0.0:
		return maxf(want, 0.0)
	var b: Array = _budget.get(p.get_instance_id(), [now, 0.0])
	if now - float(b[0]) > HS_WINDOW:
		b = [now, 0.0]
	var got := clampf(HS_CAP - float(b[1]), 0.0, want)
	b[1] = float(b[1]) + got
	_budget[p.get_instance_id()] = b
	return got

# ---- §5.6 sound layering (placeholder sounds from the existing Sfx set) ----
## Layer 1, the tell, by delivery: [sound, pitch].
const DELIVERY_TELL := {
	"projectile": ["throw", 1.25], "cone": ["whoosh", 0.9], "beam": ["charge", 1.4], "burst": ["charge", 1.7],
	"zone": ["cloak", 0.8], "trap": ["plant", 1.2], "wall": ["build", 0.9], "aura": ["shield", 0.8],
	"tether": ["grab", 1.0], "leap": ["whoosh", 0.7], "blink": ["portal", 1.6], "summon": ["portal", 0.9], "dash": ["dash", 1.0],
}
## The tell and impact rows come from AbilityFx (the pop branch's synthesized ability sounds), so archetype kits, Boki and weapon right clicks share one sound language; these tables are
## the fallback.
static func tell_row(delivery: String) -> Array:
	return AbilityFx.feel_tell(delivery) if AbilityFx.TELL.has(delivery) else DELIVERY_TELL.get(delivery, ["skill", 1.0])

static func impact_row(cat: String) -> Array:
	return AbilityFx.feel_impact(cat) if AbilityFx.IMPACT.has(cat) else CATEGORY_IMPACT.get(cat, ["hit", 1.0])

## Layer 3, the impact, by effect category: [sound, pitch]. Control is a hard hit then a held tone.
const CATEGORY_IMPACT := {"damage": ["thump", 1.0], "control": ["zap", 0.8], "sustain": ["heal", 1.1], "shield": ["shield", 1.2], "utility": ["ping", 1.3]}
## Layer 4, the kin theme's sweetener.
const SWEETENER := {"venom": "k_venom", "spore": "k_spore", "gravity": "k_gravity", "prism": "k_prism", "lunar": "k_lunar", "echo": "k_echo"}
## Each archetype's dash sound: [[sound, pitch, delay]...].
const DASH_SOUND := {
	"thief": [["swipe", 1.7, 0.0]], "archer": [["throw", 1.4, 0.0], ["whoosh", 1.3, 0.12]], "mage": [["portal", 1.7, 0.0]],
	"gunslinger": [["dash", 1.1, 0.0], ["reload", 1.6, 0.08]], "juggernaut": [["charge", 0.6, 0.0]], "bulwark": [["shield", 0.7, 0.0], ["whoosh", 0.7, 0.05]],
	"dolm": [["thump", 0.6, 0.0], ["charge", 0.8, 0.04]], "ostra": [["swap", 1.3, 0.0], ["hover", 1.6, 0.05]],
}
const MAX_VOICES := 4
static var _voices := {}       # event key -> voices started this frame

## Plays one layer of an ability event: at most MAX_VOICES per event; an enemy tell that can reach
## the local player is +3 dB, allies' casts are -4 dB, other people's impacts -8 dB.
static func sound(m: Node, layer: String, what: String, at: Vector3, by: Ent = null, event := "") -> void:
	if m == null:
		return
	var key := "%s|%d" % [event if event != "" else what, Engine.get_physics_frames()]
	var n := int(_voices.get(key, 0))
	if n >= MAX_VOICES:
		return
	_voices[key] = n + 1
	if _voices.size() > 64: _voices.clear()
	var row: Array = []
	match layer:
		"tell":
			# one tell per caster per frame: the grammar runner (KinExec) and a kit's own cast_sound
			# can both ask for it
			var tk := "tell|%d|%d" % [by.get_instance_id() if by else 0, Engine.get_physics_frames()]
			if _voices.has(tk):
				return
			_voices[tk] = 1
			row = tell_row(what)
		"impact": row = impact_row(what)
		"sweet":
			var sn := String(SWEETENER.get(what, ""))
			if sn == "": return
			row = [sn, 1.0]
		_: row = [what, 1.0]
	var vol := 0.0
	var p = m.get("player")
	if p != null and by != null:
		if by.team != p.team:
			vol += 3.0 if p.flat_dist(at) < 12.0 else 0.0
		elif by != p:
			vol -= 4.0
	match layer:
		"sweet": vol -= 6.0
		"impact": vol -= 3.0
	m.sfx(String(row[0]), at, vol - 4.0, float(row[1]))

## The dash's own sound per archetype (plus the kin's sweetener, played by the rider). A Hunter with its
## own <arch>_dash (HeroSfx, played with the dash itself) needs none of these shared layers.
static func dash_sound(m: Node, arch: String, at: Vector3, by: Ent) -> void:
	if by is Hunter and HeroSfx.of(by as Hunter, "dash", "") != "":
		return
	for s in DASH_SOUND.get(arch, [["dash", 1.0, 0.0]]):
		var sn := String(s[0]); var pt := float(s[1]); var dl := float(s[2])
		if dl <= 0.0:
			m.sfx(sn, at, -5.0 if by == m.player else -9.0, pt)
		else:
			m.later(dl, func(): if is_instance_valid(m): m.sfx(sn, at, -6.0 if by == m.player else -10.0, pt))

## A whole ability event: tell (delivery), impact (category) and the kin's sweetener.
static func cast_sound(m: Node, delivery: String, cat: String, at: Vector3, by: Ent, theme := "") -> void:
	var ev := "cast%d" % (by.get_instance_id() if by else 0)
	sound(m, "tell", delivery, at, by, ev)
	if cat != "":
		sound(m, "impact", cat, at, by, ev)
	if theme != "":
		sound(m, "sweet", theme, at, by, ev)
