class_name Arch
extends RefCounted
## Archetypes (docs/ARCHETYPES.md): six whole characters, two per weight class. Core data under
## content/archetypes/<id>.json (reviewed, never community-authored): the weapon family, the dash
## shape, the passive and its resource, the RMB with its contextual variants, E and R, sockets,
## the level-up order. The weight class (Data.CLASSES) still sets health, speed, mass and dash
## charges. ArchKit runs one hunter's kit; this file is the data side: lookups, weapon families,
## and the kin's infusion (how a kin's typing fills an archetype ability's sockets, ARCHETYPES §4).

const ORDER := ["gunslinger", "juggernaut", "ashwick", "tender", "dolm", "archer", "dredge", "rimewright", "ostra", "bulwark", "mage", "thief"]   # canonical Hunter order (display order everywhere): Vex, Kael, Cinder, Meeko, Tenzo, Lace, Grimble, Neve, Motley, Mossy, Sparkle, Sable
const DEFAULT := {"light": "thief", "medium": "gunslinger", "heavy": "juggernaut"}

static func def(id: String) -> Dictionary:
	return Content._load("archetypes", id)

## A hero's own body over its class (content "body"): size and build multiply the class look, hit_r
## replaces the class hit radius. Empty for none.
static func body(id: String) -> Dictionary:
	if id == "" or not exists(id):
		return {}
	return def(id).get("body", {})

## The hitbox radius of a hunter of this archetype and class (the body's hit_r, else the class's).
static func hit_r(id: String, cdat: Dictionary) -> float:
	return float(body(id).get("hit_r", cdat.get("hit_r", 0.38 * float(cdat["scale"]))))

static func ids() -> Array:
	var out: Array = []
	for a in ORDER:
		if not def(a).is_empty(): out.append(a)
	return out

static func exists(id: String) -> bool:
	return id != "" and not def(id).is_empty()

static func weight(id: String) -> String:
	return String(def(id).get("weight", ""))

## The stored title without "the" ("Unbroken"); for ids, file names and the one place that adds "the".
static func bare_title(id: String) -> String:
	return String(def(id).get("title", id.capitalize())).trim_prefix("The ")

## A title shown on its own, the one display helper: "The Hired Gun" at the start of a line, with
## mid=true "the Hired Gun" inside a sentence. Names with the title go through HeroTitle.label.
static func name_of(id: String, mid := false) -> String:
	var t := bare_title(id)
	return ("the " if mid else "The ") + t if def(id).has("title") else t

## The Hunter's display name, or "Hunter" for a body with no Hunter kit (dummies, old saves).
static func label(id: String) -> String:
	return name_of(id) if exists(id) else "Hunter"

static func color(id: String) -> Color:
	return Color(String(def(id).get("color", "#ffffff")))

## The two archetypes of a weight class.
static func of_class(cls: String) -> Array:
	return ids().filter(func(a): return weight(a) == cls)

static func default_for(cls: String) -> String:
	return String(DEFAULT.get(cls, "gunslinger"))

## An archetype that fits the class: the one asked for if it does, else the class's default.
static func fix(id: String, cls: String) -> String:
	if exists(id) and weight(id) == cls:
		return id
	return default_for(cls)

## The archetype saved for the local player (Save.d["arch"]), checked against the saved class.
static func of_save() -> String:
	return fix(String(Save.d.get("arch", "")), Data.class_of_save())

## A bot's archetype from a key (its id and the match seed): its own random stream, so picking one
## never shifts the match's (seeded maps, loot and tests stay as they were).
static func pick_for(cls: String, key: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	return pick(cls, r)

## A random archetype of a class (bots).
static func pick(cls: String, rng: RandomNumberGenerator) -> String:
	var opts := of_class(cls)
	if opts.is_empty():
		return default_for(cls)
	return String(opts[rng.randi_range(0, opts.size() - 1)])

# ------------------------------------------------------------------ weapon families
## The rank previews for one slot ("sec", "dash", "kin", "ult"), from the rank you have: always the
## NEXT rank's concrete change first (rank 2 when you're rank 1), then rank 3's special after it.
## cur 0 (or -1: no context, e.g. the kit card) lists every rank to come. [[label, text]...]
static func next_ranks(id: String, slot: String, cur: int) -> Array:
	var d := def(id)
	var r2: Dictionary = d.get("rank2", {})
	var r3: Dictionary = d.get("rank_next", {})
	var out: Array = []
	var mx := 2 if slot == "ult" else 3
	if cur < mx and cur <= 1 and r2.has(slot):
		out.append(["Rank 2", String(r2[slot]).trim_prefix("Rank 2: ").trim_prefix("Rank 2 (level 9): ")])
	if slot != "ult" and cur < 3 and r3.has(slot):
		out.append(["Rank 3", String(r3[slot]).trim_prefix("Rank 3: ")])
	return out

## The archetype's one signature weapon: a hunter carries it for the whole run and never swaps it
## (it grows through WeaponUps instead). An archetype names it with "signature": "<weapon id>" in
## its JSON (the weapon itself lives in content/weapons). The old "weapons" list still loads: its first
## entry is taken, so a hero file written before the gear model keeps working.
static func signature(id: String) -> String:
	var d := def(id)
	if d.has("signature"):
		return String(d["signature"])
	var w: Array = d.get("weapons", [])
	return String(w[0]) if not w.is_empty() else ""

## Kept as a list for callers that iterate the weapon (always exactly one).
static func weapons(id: String) -> Array:
	var sg := signature(id)
	return [sg] if sg != "" else []

static func weapon_ok(id: String, wid: String) -> bool:
	return wid == signature(id)

## The weapon a hunter of this archetype carries: always its signature (with no archetype, the class rule).
static func weapon_for(id: String, cls: String, wid: String) -> String:
	if not exists(id):
		return Data.weapon_for(cls, wid)
	return signature(id)

## Which archetypes carry a weapon as their signature.
static func archetypes_of(wid: String) -> Array:
	return ids().filter(func(a): return weapon_ok(a, wid))

# ------------------------------------------------------------------ infusion (ARCHETYPES §4)
## Socket caps on hard control (§4.1): soft sockets cap stun 0.3 and root 0.6; hard 0.8 and 1.2.
const CAPS := {"soft": {"stun": 0.3, "root": 0.6}, "hard": {"stun": 0.8, "root": 1.2}}
## How much of a kin part's own number a socket keeps, by the ability it sits in (the socket's
## budget, Phase 3 placeholder): a kin part's numbers are relative intensity.
const BUDGET := {"rmb": 0.35, "e": 0.3, "r": 0.5, "dash": 0.3}
const FALLBACK_K := 0.1        # an empty socket: +10% to the stage's primary number
## Control parts that suit each delivery family, in order of preference (§4.2 notes per kin: lift on
## bursts and cones, a gravity-well pull on zones and landings, a barb pull on projectiles).
const CTRL_PREF := {
	"projectile": ["stun", "root", "slow", "pull", "push", "lift"],
	"beam": ["stun", "slow", "root", "push", "lift", "pull"],
	"cone": ["lift", "push", "stun", "slow", "root", "pull"],
	"burst": ["lift", "push", "stun", "root", "slow", "pull"],
	"zone": ["pull", "slow", "root", "push", "lift", "stun"],
	"leap": ["pull", "lift", "push", "stun", "root", "slow"],
	"dash": ["push", "pull", "slow", "stun", "lift", "root"],
}

static var _inf_cache := {}

## The kin's infusion: {hit, ctrl: [PartSpec...], guard, util, mod: [PartSpec...], move}. An
## explicit KinSpec "infusion" wins; otherwise it's derived from the kin's active, its dodge rider
## and its throw (§4.2), so a community kin maps automatically.
static func infusion(ks: KinSpec) -> Dictionary:
	if ks == null:
		return {}
	if _inf_cache.has(ks.id):
		return _inf_cache[ks.id]
	var out := {"hit": null, "ctrl": [], "guard": null, "util": null, "mod": [], "move": "", "src": ks.id}
	var effs: Array = []
	var mods: Array = []
	var ab := KinLib.ability(ks.active)
	if ab:
		for st in ab.all_stages():
			effs.append_array(st.effects)
			mods.append_array(st.modifiers)
	effs.append_array(ks.dodge_rider.get("on_pass", []))
	for key in ["on_start", "on_end"]:
		for st in ks.dodge_rider.get(key, []):
			effs.append_array((st as StageSpec).effects)
	effs.append_array(ks.throw_effects)
	mods.append_array(ks.dodge_rider.get("modifiers", []))
	for e0 in effs:
		var e: PartSpec = e0
		match e.category():
			"damage":
				if out["hit"] == null and float(e.params.get("over", 0.0)) > 0.0: out["hit"] = e
			"control":
				if not (out["ctrl"] as Array).any(func(x): return (x as PartSpec).type == e.type): (out["ctrl"] as Array).append(e)
			"sustain":
				if out["guard"] == null and e.type in ["shield", "heal", "reflect"]: out["guard"] = e
			"utility":
				if e.type == "mark" and String(e.params.get("mode", "")) == "blight":
					if out["hit"] == null: out["hit"] = e
				elif out["util"] == null and e.type in ["mark", "buff"]:
					out["util"] = e
	for md in mods:
		if (md as PartSpec).type in ["delay", "spike"]:
			continue
		if not (out["mod"] as Array).any(func(x): return (x as PartSpec).type == (md as PartSpec).type): (out["mod"] as Array).append(md)
	out["move"] = String(ks.dodge_rider.get("as", ""))
	# an explicit infusion block replaces whatever it names
	for key in ks.infusion:
		out[key] = ks.infusion[key]
	_inf_cache[ks.id] = out
	return out

## A part as the plain dictionary the grammar parser reads back.
static func part_dict(p: PartSpec) -> Dictionary:
	var d := {"type": p.type}
	for k in p.params:
		d[k] = p.params[k]
	if p.kind == "effect" and p.target != "" and p.target != String((KinParts.EFFECTS.get(p.type, {}).get("targets", ["foes"]) as Array)[0]):
		d["target"] = p.target
	return d

## Fills an ability's sockets from the kin's infusion. sockets: {"hit": "add", "ctrl": "add"|"swap",
## "ctrl_cap": "soft"|"hard", "guard": "add", "util": "add", "mod": "add"}; slot: rmb | e | r | dash
## (the socket budget); delivery: the stage's delivery type (which modifiers and control fit).
## Returns {"effects": [dicts to add], "swap": bool (drop the base control), "mods": [dicts],
## "fallback": extra fraction for the primary number, "notes": [what each socket got]}.
static func fill(sockets: Dictionary, inf: Dictionary, slot: String, delivery: String, have_mods: Array = [], budget_k := 1.0) -> Dictionary:
	var out := {"effects": [], "swap": false, "mods": [], "fallback": 0.0, "notes": []}
	if inf.is_empty():
		return out
	var b := float(BUDGET.get(slot, 0.35)) * budget_k
	var cap: Dictionary = CAPS.get(String(sockets.get("ctrl_cap", "soft")), CAPS["soft"])
	var empty := 0
	if sockets.has("hit"):
		var hp: PartSpec = inf.get("hit")
		if hp:
			var d := part_dict(hp)
			if hp.type == "damage":
				d["amount"] = clampf(float(d["amount"]) * b, 1.0, 20.0)
			elif hp.type == "mark":
				d["duration"] = clampf(float(d["duration"]), 0.5, 4.0)
			(out["effects"] as Array).append(d)
			(out["notes"] as Array).append("hit: " + _desc(d))
		else:
			empty += 1
	if sockets.has("ctrl"):
		var pick: PartSpec = null
		for t in CTRL_PREF.get(delivery, CTRL_PREF["burst"]):
			for c in inf.get("ctrl", []):
				if (c as PartSpec).type == t:
					pick = c; break
			if pick: break
		if pick:
			var d := part_dict(pick)
			match pick.type:
				"stun": d["duration"] = minf(float(d["duration"]), float(cap["stun"]))
				"root": d["duration"] = minf(float(d["duration"]), float(cap["root"]))
				"slow": d["strength"] = minf(float(d["strength"]), 0.5); d["duration"] = clampf(float(d["duration"]), 0.4, 1.5)
				"push": d["strength"] = clampf(float(d["strength"]) * 0.75, 4.0, 12.0); d["from"] = "center" if delivery in ["burst", "zone"] else String(d.get("from", "center"))
				"lift": d["strength"] = clampf(float(d["strength"]) * 0.6, 3.0, 8.0); d["forward"] = 0.0
				"pull":
					d["strength"] = clampf(float(d["strength"]), 4.0, 10.0)
					if delivery == "projectile" and float(d.get("gap", 0.0)) > 0.0:
						d["gap"] = 1.5      # a short barb pull on shots
						d["strength"] = clampf(float(pick.params["strength"]), 10.0, 30.0)
					else:
						d["gap"] = 0.0
						d["to"] = "center"
			(out["effects"] as Array).append(d)
			out["swap"] = String(sockets["ctrl"]) == "swap"
			(out["notes"] as Array).append(("ctrl %s: " % sockets["ctrl"]) + _desc(d))
		else:
			empty += 1
	if sockets.has("guard"):
		var gp: PartSpec = inf.get("guard")
		if gp:
			var d := part_dict(gp)
			match gp.type:
				"shield": d["amount"] = clampf(float(d["amount"]) * b * 1.2, 5.0, 25.0); d["target"] = "owner"
				"heal": d["amount"] = clampf(float(d["amount"]) * b, 5.0, 20.0); d["target"] = "owner"
				"reflect": d["power"] = 0.5; d["duration"] = minf(float(d["duration"]), 0.6); d["target"] = "owner"; d["arc"] = 140.0
			(out["effects"] as Array).append(d)
			(out["notes"] as Array).append("guard: " + _desc(d))
		else:
			empty += 1
	if sockets.has("util"):
		var up: PartSpec = inf.get("util")
		if up:
			var d := part_dict(up)
			if up.type == "mark" and String(d.get("mode", "")) == "vulnerable":
				d["amount"] = minf(float(d["amount"]), 0.15)
			if up.type == "mark":
				d["duration"] = clampf(float(d["duration"]), 1.0, 4.0)
			(out["effects"] as Array).append(d)
			(out["notes"] as Array).append("util: " + _desc(d))
		else:
			empty += 1
	if sockets.has("mod"):
		var got: Dictionary = {}
		for md in inf.get("mod", []):
			var mp: PartSpec = md
			if have_mods.has(mp.type) or not (KinParts.MODIFIERS[mp.type]["on"] as Array).has(delivery):
				continue
			got = part_dict(mp)
			break
		if got.is_empty():
			empty += 1
		else:
			if String(got["type"]) == "split": got["count"] = 2; got["angle"] = minf(float(got.get("angle", 20.0)), 20.0)
			if String(got["type"]) == "chain": got["count"] = mini(int(got.get("count", 1)), 2)
			if String(got["type"]) == "pierce": got["count"] = mini(int(got.get("count", 1)), 1)
			(out["mods"] as Array).append(got)
			(out["notes"] as Array).append("mod: " + String(got["type"]))
	out["fallback"] = FALLBACK_K * float(empty)
	if empty > 0:
		(out["notes"] as Array).append("fallback +%d%%" % int(round(float(out["fallback"]) * 100.0)))
	return out

static func _desc(d: Dictionary) -> String:
	var t := String(d["type"])
	match t:
		"damage": return "%s %s%s" % ["poison" if float(d.get("over", 0.0)) > 0.0 else "damage", KinParts._num(float(d["amount"])), (" over %ss" % KinParts._num(float(d["over"]))) if float(d.get("over", 0.0)) > 0.0 else ""]
		"slow": return "slow %s for %ss" % [KinParts._num(float(d["strength"])), KinParts._num(float(d["duration"]))]
		"stun", "root": return "%s %ss" % [t, KinParts._num(float(d["duration"]))]
		"push", "pull", "lift": return "%s %s" % [t, KinParts._num(float(d["strength"]))]
		"shield", "heal": return "%s %s" % [t, KinParts._num(float(d["amount"]))]
		"mark": return "%s %ss" % [String(d["mode"]), KinParts._num(float(d["duration"]))]
		"reflect": return "reflect %s" % KinParts._num(float(d["power"]))
	return t

## A readable table of what a kin does to every archetype's RMB, E and R (§4.3 rule 6).
static func infusion_table(ks: KinSpec) -> Array:
	var rows: Array = []
	var inf := infusion(ks)
	for a in ids():
		var ad := def(a)
		for slot in ["rmb", "e", "r"]:
			var sd: Dictionary = ad.get(slot, {})
			if sd.is_empty():
				continue       # a hero without this slot (no class R: the Merge owns it) has no row
			var f := fill(sd.get("sockets", {}), inf, slot, String(sd.get("delivery", "projectile" if slot == "rmb" else "burst")))
			rows.append("%-10s %-3s %-14s %s" % [a, slot.to_upper(), String(sd.get("name", "")), "; ".join(f["notes"])])
	return rows
