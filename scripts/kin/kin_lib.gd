class_name KinLib
extends RefCounted
## The live game's kin library (docs/KIN_GRAMMAR.md, Phase 2). Loads every grammar file under
## res://content once (abilities_v2, merges_v2, evolution_v2, kin_v2) through the checker, keeps
## only files that passed it, and builds what the match needs from them:
##
##   species(id)      the Data.KIN entry (name, colours, stats from points, slots, carry...)
##   nodes_for()      the evolution nodes a kin has taken, from its record's forms
##   points()         its stat points after evolution's budget-neutral shifts
##   effective()      an ability as one kin actually casts it: evolution sidegrades and added
##                    modifiers, the merged patch while merged, the slot's rank, all clamped to bounds
##
## Everything here is data in, data out: nothing named in a file is loaded or called.

const ROOT := "res://content"
## A species' theme as its standard type (DECISIONS 2026-11-08 22:29). The type picks the cast cue k_<type>.
const TYPE_OF_THEME := {"ember": "fire", "bloom": "grass", "storm": "electric", "frost": "ice", "venom": "poison",
	"swarm": "bug", "tempest": "flying", "stone": "rock", "titan": "steel", "lunar": "fairy", "prism": "crystal",
	"shadow": "dark", "echo": "sound", "gravity": "psychic", "spore": "spore"}

static var _lib := {}
static var _reports := {}
static var _eff_cache := {}

static func lib() -> Dictionary:
	if _lib.is_empty():
		_load()
	return _lib

static func _load() -> void:
	_reports = {}
	var raw := KinGrammar.load_root(ROOT, _reports)
	var out := {"abilities": {}, "merges": {}, "evolution": {}, "kin": {}}
	var folder_of := {"abilities": "abilities_v2", "merges": "merges_v2", "evolution": "evolution_v2", "kin": "kin_v2"}
	for kind in out:
		for id in raw[kind]:
			var rep: GrammarReport = _reports.get("%s/%s.json" % [folder_of[kind], id], null)
			if rep and not rep.ok():
				push_warning("KinLib: skipping %s/%s.json (%d grammar errors; run --grammar-check)" % [folder_of[kind], id, rep.errors.size()])
				continue
			out[kind][id] = raw[kind][id]
	# a kin whose slots point at a skipped file is skipped too
	for id in out["kin"].keys():
		var k: KinSpec = out["kin"][id]
		if not out["abilities"].has(k.active) or not out["merges"].has(k.merge) or (k.auto != "" and not out["abilities"].has(k.auto)):
			push_warning("KinLib: skipping kin %s (an ability or merge it needs didn't load)" % id)
			out["kin"].erase(id)
	_lib = out
	_eff_cache.clear()

static func reload() -> void:
	_lib = {}
	lib()

static func kin(id: String) -> KinSpec:
	return lib()["kin"].get(id, null)

static func ability(id: String) -> AbilitySpec:
	return lib()["abilities"].get(id, null)

static func merge(id: String) -> MergeSpec:
	return lib()["merges"].get(id, null)

static func node(id: String) -> EvolutionNode:
	return lib()["evolution"].get(id, null)

## The cast cue of a theme: k_<type>.
static func cue_of(theme: String) -> String:
	return "k_" + String(TYPE_OF_THEME.get(theme, "normal"))

static func kin_ids() -> Array:
	var ids: Array = lib()["kin"].keys()
	ids.sort()
	return ids

static func merge_of(species_id: String) -> MergeSpec:
	var k := kin(species_id)
	return merge(k.merge) if k else null

# ------------------------------------------------------------------ species
## The Data.KIN entry for a species. Kin stats come from its points; slots are ability and merge ids.
static func species(id: String) -> Dictionary:
	var k := kin(id)
	if k == null:
		return {}
	var c: Dictionary = k.colors
	var out := {
		"name": k.display_name, "type": k.theme, "theme": k.theme,
		"color": Color(String(c.get("body", "#ffffff"))), "belly": Color(String(c.get("belly", "#ffffff"))),
		"glow": Color(String(c.get("glow", c.get("body", "#ffffff")))),
		"hp": k.stat("kin_hp"), "dmg": k.stat("kin_damage"), "speed": k.stat("kin_speed"), "range": k.reach,
		"mass": k.mass, "size": k.size, "gait": k.gait.duplicate(),
		"ears": String(k.look.get("ears", "none")), "look": k.look.duplicate(),
		"skill": k.active, "abilities": [k.active] + ([k.auto] if k.auto != "" else []), "ultimate": k.merge,
		"carry": k.carry_style, "carry_name": k.carry_name,
		"traits": k.personality.duplicate(),
		"ai": {"aggression": float(k.ai.get("aggression", 0.5)), "loyalty": float(k.ai.get("loyalty", 0.5)), "caution": float(k.ai.get("caution", 0.5)),
			"style": String(k.ai.get("role", "")), "role": String(k.ai.get("role", ""))},
		"animals": k.animals.duplicate(), "desc": k.flavor, "egg": k.egg.duplicate(),
		"voice": String(k.voice.get("line", "friendly")),
	}
	if c.has("wing"):
		out["wing"] = Color(String(c["wing"]))
	return out

# ------------------------------------------------------------------ evolution
## The evolution nodes a kin has taken, in order: its n-th form on an affinity takes the next node
## on that affinity's path, if the kin is old enough and the node's "after" nodes came first.
static func nodes_for(ks: KinSpec, rec: Dictionary) -> Array:
	var out: Array = []
	if ks == null:
		return out
	var lv := int(rec.get("level", 1))
	var at := {}           # affinity -> next index on its path
	var taken: Array = []
	for f in rec.get("forms", []):
		var aff := String(f)
		var path: Dictionary = {}
		for p in ks.evo_paths:
			if String(p["affinity"]) == aff: path = p; break
		if path.is_empty():
			continue
		var i := int(at.get(aff, 0))
		var ids: Array = path["nodes"]
		if i >= ids.size():
			continue
		var n := node(String(ids[i]))
		if n == null or n.level > lv:
			continue
		var ok := true
		for req in n.after:
			if not taken.has(req): ok = false
		if not ok:
			continue
		at[aff] = i + 1
		taken.append(n.id)
		out.append(n)
	return out

## Stat points after evolution's shifts (the total never changes).
static func points(ks: KinSpec, rec: Dictionary) -> Dictionary:
	var pts: Dictionary = ks.stat_points.duplicate()
	for n in nodes_for(ks, rec):
		for g in (n as EvolutionNode).grants:
			if String(g["kind"]) != "stat_shift":
				continue
			var a := String(g["from"]); var b := String(g["to"])
			var moved := mini(int(g["points"]), int(pts.get(a, 0)))
			moved = mini(moved, int(KinParts.STATS[b]["max_points"]) - int(pts.get(b, 0)))
			if moved <= 0:
				continue
			pts[a] = int(pts.get(a, 0)) - moved
			pts[b] = int(pts.get(b, 0)) + moved
	return pts

static func stat_value(key: String, pts: Dictionary) -> float:
	var s: Dictionary = KinParts.STATS.get(key, {})
	return float(s.get("base", 0.0)) + float(s.get("per_point", 0.0)) * float(pts.get(key, 0))

## The owner bonuses a kin gives its hunter for the run: {owner_max_hp: hp, owner_armor: x, ...}
## (only the stats it has points in).
static func owner_bonus(ks: KinSpec, rec: Dictionary) -> Dictionary:
	var out := {}
	if ks == null:
		return out
	var pts := points(ks, rec)
	for key in KinParts.STATS:
		if String(key).begins_with("owner_") and int(pts.get(key, 0)) > 0:
			out[key] = stat_value(key, pts)
	return out

# ------------------------------------------------------------------ copying and patching specs
static func copy_part(p: PartSpec) -> PartSpec:
	if p == null:
		return null
	var q := PartSpec.new()
	q.kind = p.kind; q.type = p.type; q.preset = p.preset; q.target = p.target
	q.params = p.params.duplicate(true)
	q.explicit = p.explicit.duplicate(true)
	return q

static func copy_stage(s: StageSpec) -> StageSpec:
	var t := StageSpec.new()
	t.delivery = copy_part(s.delivery)
	for e in s.effects: t.effects.append(copy_part(e))
	for md in s.modifiers: t.modifiers.append(copy_part(md))
	for ev in s.then:
		var arr: Array = []
		for sub in s.then[ev]: arr.append(copy_stage(sub))
		t.then[ev] = arr
	return t

static func copy_ability(a: AbilitySpec) -> AbilitySpec:
	var b := AbilitySpec.new()
	for f in ["id", "display_name", "short", "flavor", "theme", "tier", "from", "cast_range", "cooldown", "charges", "bond_cost"]:
		b.set(f, a.get(f))
	b.trigger = a.trigger
	b.cue = a.cue
	for s in a.stages: b.stages.append(copy_stage(s))
	return b

## A number on one stage by path ("delivery.range", "effects.4.duration"): [part, key] or [].
static func _locate(st: StageSpec, path: String) -> Array:
	var bits := path.split(".")
	if bits.size() == 2 and bits[0] == "delivery" and st.delivery:
		return [st.delivery, bits[1]]
	if bits.size() == 3 and bits[0] == "effects" and bits[1].is_valid_int() and int(bits[1]) < st.effects.size():
		return [st.effects[int(bits[1])], bits[2]]
	return []

static func _scale(st: StageSpec, path: String, k: float) -> void:
	var loc := _locate(st, path)
	if loc.is_empty():
		return
	var p: PartSpec = loc[0]
	var key: String = loc[1]
	if typeof(p.params.get(key)) in [TYPE_FLOAT, TYPE_INT]:
		p.params[key] = KinRules.clamp_param(p.kind, p.type, key, float(p.params[key]) * k)

static func _add_mod(st: StageSpec, mp: PartSpec) -> void:
	if mp == null or st.delivery == null or st.has_modifier(mp.type):
		return
	if not (KinParts.MODIFIERS[mp.type]["on"] as Array).has(st.delivery.type):
		return
	if st.modifiers.size() >= KinParts.MAX_MODIFIERS:
		return
	st.modifiers.append(copy_part(mp))

## The ability one kin actually casts: evolution grants for its slot, the merged patch (while
## merged), then the slot's rank through the core rank table. Every number is clamped to its bounds.
## Cached, so it's cheap to call on every cast.
static func effective(ab: AbilitySpec, slot: String, ks: KinSpec, rec: Dictionary, rank := 1, merged: Dictionary = {}) -> AbilitySpec:
	if ab == null:
		return null
	var nodes: Array = nodes_for(ks, rec) if ks else []
	var key := "%s|%s|%d|%s|%s" % [ab.id, slot, rank, ",".join(nodes.map(func(n): return n.id)), str(merged.hash()) if not merged.is_empty() else "-"]
	if _eff_cache.has(key):
		return _eff_cache[key]
	var out := copy_ability(ab)
	var evo_slot := "active" if slot in ["k1", "active"] else "auto"
	for n in nodes:
		for g in (n as EvolutionNode).grants:
			if String(g.get("slot", "")) != evo_slot:
				continue
			var si := int(g.get("stage", 0))
			if si >= out.stages.size():
				continue
			var st: StageSpec = out.stages[si]
			match String(g["kind"]):
				"add_modifier":
					_add_mod(st, g["modifier"])
				"sidegrade":
					_scale(st, String(g["up"]["param"]), clampf(float(g["up"]["scale"]), KinParts.SIDEGRADE_UP[0], KinParts.SIDEGRADE_UP[1]))
					_scale(st, String(g["down"]["param"]), clampf(float(g["down"]["scale"]), KinParts.SIDEGRADE_DOWN[0], KinParts.SIDEGRADE_DOWN[1]))
	if not merged.is_empty():
		var si2 := int(merged.get("stage", 0))
		if si2 < out.stages.size():
			var st2: StageSpec = out.stages[si2]
			for mp in merged.get("add_modifiers", []):
				_add_mod(st2, mp)
			var sc: Dictionary = merged.get("scale", {})
			for k in sc:
				_scale(st2, "delivery." + String(k), KinRules.merge_scale(float(sc[k])))
	if rank > 1:
		for st3 in out.all_stages():
			for p in [st3.delivery] + Array(st3.effects) + Array(st3.modifiers):
				if p == null: continue
				var grow: Dictionary = KinRules.RANK_GROW.get((p as PartSpec).type, {})
				for gk in grow:
					if typeof(p.params.get(gk)) in [TYPE_FLOAT, TYPE_INT]:
						p.params[gk] = float(p.params[gk]) * (1.0 + float(grow[gk]) * float(rank - 1))
	for st4 in out.all_stages():
		for p in [st4.delivery] + Array(st4.effects) + Array(st4.modifiers):
			if p: KinRules.clamp_part(p)
	_eff_cache[key] = out
	return out
