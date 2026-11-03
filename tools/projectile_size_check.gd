extends RefCounted
## --projectile-size-check: every grammar projectile a hero fires has the hit radius its kit asks for,
## clamped to the grammar's bounds (KinParts projectile size, 0.08-0.6 m). An out-of-range ask used to
## fall back to the 0.2 default (the Searing Wave's 0.55-0.95 flew at 0.2). All 12 heroes at rank 1 and
## rank 3, at min and max charge where the shot charges; every kit stage literal is covered; and every
## projectile in the grammar's ability files. Prints PSCHECK lines (MEASURE lines are the table).

const AKCheck := preload("res://tools/archetype_check.gd")
const KITS := "res://scripts/arch/kits/"
const HEROES := ["archer", "ashwick", "bulwark", "dolm", "dredge", "gunslinger", "juggernaut", "mage", "ostra",
		"rimewright", "tender", "thief"]
const RANK_SLOTS := ["sec", "kin", "dash", "ult"]
var A: AKCheck

func run(main_node: Node) -> void:
	A = AKCheck.new()
	A.main = main_node
	_validator()
	_literals_covered()
	for hero in HEROES:
		await _hero(hero)
	_grammar_files()
	print("PSCHECK DONE, %d checks, failures: %d" % [A.n, A.fails])
	main_node.get_tree().quit(1 if A.fails > 0 else 0)

## Each hero's grammar projectiles: [name, kit file holding its stage literal, charges?].
const SITES := {
	"archer": [["Heavy Shot", "archer_kit.gd", true]],
	"ashwick": [["Cinder Shot", "ashwick_kit.gd", false]],
	"dredge": [["Grapnel", "dredge_kit.gd", false]],
	"juggernaut": [["Searing Wave", "juggernaut_kit.gd", true], ["Warchain", "juggernaut_chain.gd", false]],
	"mage": [["Coilshot", "mage_kit.gd", true]],
	"thief": [["Bola", "thief_kit.gd", false], ["Shadow Knife", "thief_kit.gd", false]],
}

## Fires one site through the kit's own code at charge k (0..1).
func _fire(site: String, K: ArchKit, k: float) -> void:
	match site:
		"Heavy Shot": (K as ArcherKit)._pin(K.aim(), k)
		"Cinder Shot":
			K.ch_rmb = 1.0
			K.fire_rmb({})
		"Grapnel":
			var D := K as DredgeKit
			D.flying = false
			D.pull = {}
			D.ch_rmb = 1.0
			D.fire_rmb({})
		"Searing Wave":
			var ld: Dictionary = K.lmb_def()
			(K as JuggernautKit).lmb_t = lerpf(float(ld["tap"]), float(ld["full"]), k)
			(K as JuggernautKit)._wave()
		"Warchain": (K as JuggernautKit).warchain._throw()
		"Coilshot": (K as MageKit)._coil(k)
		"Bola": (K as ThiefKit)._throw_bola()
		"Shadow Knife": (K as ThiefKit)._throw_knife()

## The size the kit asks for at charge k (its literal, or its data).
func _ask(site: String, K: ArchKit, k: float) -> float:
	match site:
		"Heavy Shot": return lerpf(0.2, 0.34, k)
		"Cinder Shot": return float(K.rmb_def()["size"])
		"Grapnel": return 0.24
		"Searing Wave": return lerpf(float(K.lmb_def()["wave_size"][0]), float(K.lmb_def()["wave_size"][1]), k)
		"Warchain", "Coilshot": return 0.22
		"Bola": return 0.3
	return 0.2      # Shadow Knife

## Out of bounds is reported and clamped, not swapped for the default (0.95 -> 0.6, not 0.2; pierce 6 -> 5, not 3).
func _validator() -> void:
	var rep := GrammarReport.new()
	rep.file = "pscheck"
	var st := StageSpec.parse({"delivery": {"type": "projectile", "size": 0.95},
			"effects": [{"type": "damage", "amount": 5}], "modifiers": [{"type": "pierce", "count": 6}]}, "", rep)
	var sz := float(st.delivery.params["size"])
	var pc := int(st.modifier("pierce").params["count"])
	A.ok("pscheck validator: clamps out-of-bounds numbers",
			is_equal_approx(sz, 0.6) and pc == 5 and rep.errors.size() == 2,
			"size %.2f pierce %d, %d errors" % [sz, pc, rep.errors.size()])

## Every `"type": "projectile"` stage literal in the kits belongs to a site above (a new one can't slip by).
func _literals_covered() -> void:
	var want := {}
	for hero in SITES:
		for s in SITES[hero]:
			want[s[1]] = int(want.get(s[1], 0)) + 1
	var found := {}
	for f in DirAccess.get_files_at(KITS):
		if not f.ends_with(".gd"): continue
		var n := FileAccess.get_file_as_string(KITS + f).count("\"type\": \"projectile\"")
		if n > 0: found[f] = n
	A.ok("pscheck: every kit projectile stage is measured", found == want, "kits %s, measured %s" % [found, want])

func _hero(hero: String) -> void:
	var r := A.setup(hero, 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	var sites: Array = SITES.get(hero, [])
	if sites.is_empty():
		A.ok("pscheck %s: no grammar projectile" % hero, true, "its shots don't pass the grammar's size cap")
	for rank in [1, 3]:
		for s in RANK_SLOTS: P.slot_lv[s] = rank
		for site in sites:
			for k in ([0.0, 1.0] if site[2] else [0.0]):
				A.aim_at(P, home + Vector3(0, 0, -7.0))      # off to the side: nothing in its way
				var n0 := m.shots.size()
				_fire(String(site[0]), P.ak, k)
				var got := _effective(String(site[0]), m, P, n0)
				var ask := _ask(String(site[0]), P.ak, k)
				var want := float(KinRules.clamp_param("delivery", "projectile", "size", ask))
				print("MEASURE %-10s %-13s rank %d charge %.0f%%  asks %.3f  intended %.3f  effective %.3f"
						% [hero, site[0], rank, k * 100.0, ask, want, got])
				A.ok("pscheck %s %s r%d k%.0f" % [hero, site[0], rank, k], is_equal_approx(got, want),
						"asks %.3f, intended %.3f, effective %.3f" % [ask, want, got])
				A.step(m, 1.5)
	await A.done(m)

## The hit radius the site's grammar stage got: the newest grammar shot (it carries a grammar event hook)
## the hunter fired since n0; the Bola flies itself, so its parsed stage. -1 when there's none.
func _effective(site: String, m: Match, P: Hunter, n0: int) -> float:
	if site == "Bola":
		var b: Dictionary = (P.ak as ThiefKit).bola
		return float((b["stg"] as StageSpec).delivery.params["size"]) if b.has("stg") else -1.0
	for i in range(m.shots.size() - 1, n0 - 1, -1):
		var s: Dictionary = m.shots[i]
		if s["by"] == P and (s["x"] as Dictionary).has("kx"):
			return float(s["r"])
	return -1.0

## The grammar's ability files: each projectile's parsed size is what the file set, inside the bounds.
func _grammar_files() -> void:
	var lib := KinGrammar.load_root("res://content", {})
	var bad := []
	var n := 0
	for id in lib["abilities"]:
		for st in (lib["abilities"][id] as AbilitySpec).stages:
			n += _stage_sizes(st, String(id), bad)
	A.ok("pscheck grammar files: every projectile at its set size", bad.is_empty() and n > 0,
			"%d projectiles %s" % [n, bad])

func _stage_sizes(st: StageSpec, id: String, bad: Array) -> int:
	var n := 0
	if st.delivery and st.delivery.type == "projectile" and st.delivery.explicit.has("size"):
		n += 1
		var want := float(KinRules.clamp_param("delivery", "projectile", "size", float(st.delivery.explicit["size"])))
		if not is_equal_approx(float(st.delivery.params["size"]), want):
			bad.append("%s %.2f (wants %.2f)" % [id, float(st.delivery.params["size"]), want])
	for ev in st.then:
		for sub in st.then[ev]:
			n += _stage_sizes(sub, id, bad)
	return n
