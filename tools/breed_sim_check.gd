extends RefCounted
## --breed-sim-check: 500 random pairs are bred headlessly (Care.breed) and the owner's rules asserted
## (DECISIONS 2026-11-08/11-09): the sex split is half and half (species with a documented female_share in
## content/rules/boki_quirks.json follow that share instead), every trait comes from one parent or the
## documented blend, and a baby has nothing neither parent carries except a documented fresh roll
## (mutation or shimmer at base odds, a new look now and then). Never touches the real save.

const PAIRS := 500
const SIGMA := 4.5          # allowed distance from the expected count, in standard deviations
const TRAIT_NOISE := 0.12   # Care.breed: the traits' blend is the parents' mean, plus or minus this
const EPS := 0.0001
## dna looks Unique.inherit hands down from a parent: the least share of babies that must match one
## parent (the documented chance, minus room for noise)
const LOOKS := {"mark": 0.8, "mark_col": 0.8, "eye": 0.8, "ears": 0.7, "tailv": 0.7, "quirk": 0.4}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BREED %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## A random adult: any species, a spread of traits, now and then a mutation or a lean.
func _parent(rng: RandomNumberGenerator, species: Array) -> Dictionary:
	var k := Save.new_kin(species[rng.randi() % species.size()])
	for t in k["traits"]: k["traits"][t] = rng.randf_range(0.05, 0.95)
	if rng.randf() < 0.4: k["mutations"] = [Mutations.ids()[rng.randi() % Mutations.ids().size()]]
	if rng.randf() < 0.4: k["lean"] = {["fire", "water", "leaf"][rng.randi() % 3]: rng.randf_range(2.0, 24.0)}
	Care.ensure(k)
	Evo.ensure(k)
	return k

func _z(count: int, n: int, p: float) -> float:
	var sd := sqrt(float(n) * p * (1.0 - p))
	return 0.0 if sd == 0.0 else absf(float(count) - float(n) * p) / sd

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1109
	var species: Array = Data.KIN.keys()
	species.sort()
	var even_n := 0
	var even_f := 0
	var set_n := 0
	var set_off := 0           # babies off a documented share of 0 or 1 (must be none)
	var set_f := {}            # species -> [hatched, female]
	var trait_bad := 0
	var iv_bad := 0
	var sp_bad := 0
	var aff_bad := 0
	var lean_bad := 0
	var habit_bad := 0
	var group_bad := 0
	var own_mut := 0
	var from_bad := 0
	var look_ok := {}
	for k in LOOKS: look_ok[k] = 0
	var shimmered := 0
	var mut_ids: Array = Mutations.ids()
	for i in PAIRS:
		var a := _parent(rng, species)
		var b := _parent(rng, species)
		var leads: Array = [Evo.leading(a), Evo.leading(b)]
		var baby := Care.breed(a, b, rng)
		var sp := String(baby["species"])
		if sp != String(a["species"]) and sp != String(b["species"]): sp_bad += 1
		# sex: half and half, unless its species has a documented share
		var f := 1 if Unique.sex(baby) == "f" else 0
		if BokiQuirks.female_share(sp) == BokiQuirks.EVEN_SHARE:
			even_n += 1
			even_f += f
		else:
			set_n += 1
			var share := BokiQuirks.female_share(sp)
			if (share == 1.0 and f == 0) or (share == 0.0 and f == 1): set_off += 1
			var c: Array = set_f.get(sp, [0, 0])
			set_f[sp] = [int(c[0]) + 1, int(c[1]) + f]
		# traits: the parents' mean plus or minus the documented noise (clamped), nothing else
		for t in baby["traits"]:
			var mean := (float(a["traits"].get(t, 0.5)) + float(b["traits"].get(t, 0.5))) * 0.5
			var lo := clampf(mean - TRAIT_NOISE, 0.05, 0.95)
			var hi := clampf(mean + TRAIT_NOISE, 0.05, 0.95)
			if float(baby["traits"][t]) < lo - EPS or float(baby["traits"][t]) > hi + EPS: trait_bad += 1
		# IVs: three from a named parent (value copied), the rest fresh inside 0..IV_MAX
		var from: Dictionary = baby["iv_from"]
		if from.size() != Care.IV_INHERIT: iv_bad += 1
		for st in Care.IV_KEYS:
			var v := int(baby["ivs"][st])
			if v < 0 or v > Care.IV_MAX: iv_bad += 1
			if from.has(st):
				var src: Dictionary = a if int(from[st]) == 0 else b
				if v != int(Care.ivs(src)[st]): iv_bad += 1
		# evolution head start: one axis, the one of a parent's leading way
		var grown := (baby["aff"] as Dictionary).keys().filter(func(x): return float(baby["aff"][x]) > 0.0)
		if grown.size() != 1 or not leads.has(grown[0]): aff_bad += 1
		# lean: only the stronger parent's elements
		var lean := Care.stronger(a, b).get("lean", {}) as Dictionary
		for el in baby.get("lean", {}): if not lean.has(el): lean_bad += 1
		# habits: favourite food from one parent, play from one (the other's, when they differ)
		var likes: Dictionary = baby["likes"]
		var foods: Array = [a["likes"]["food"], b["likes"]["food"]]
		var plays: Array = [a["likes"]["play"], b["likes"]["play"]]
		if not foods.has(likes["food"]) or not plays.has(likes["play"]): habit_bad += 1
		# mutations: from a parent, or the egg's own base-odds roll (a known id); one per group
		var groups := {}
		for id in Mutations.of(baby):
			if not mut_ids.has(id): from_bad += 1
			if not Mutations.has(a, id) and not Mutations.has(b, id): own_mut += 1
			var g := String(Mutations.info(id).get("group", ""))
			if g != "" and groups.has(g): group_bad += 1
			groups[g] = true
		if baby.get("shimmer", false): shimmered += 1
		# dna: looks from one parent or (now and then) new; blended numbers stay in range
		var da: Dictionary = Unique.of(a)
		var db: Dictionary = Unique.of(b)
		var dc: Dictionary = baby["dna"]
		for k in LOOKS:
			if dc[k] == da[k] or dc[k] == db[k]: look_ok[k] += 1
		if dc["from"] != [da["seed"], db["seed"]]: from_bad += 1
	# half and half (a lopsided count is a bug)
	var z := _z(even_f, even_n, 0.5)
	ok(even_n >= 100, "enough even-share babies to test the split (%d of %d)" % [even_n, PAIRS])
	ok(z <= SIGMA, "even-share babies split half and half: %d female of %d (%.1f sigma)" % [even_f, even_n, z])
	ok(set_off == 0, "a share of 0 or 1 never hatches the other sex (%d off of %d)" % [set_off, set_n])
	for sp in set_f:
		var share := BokiQuirks.female_share(sp)
		var c: Array = set_f[sp]
		var fits := _z(int(c[1]), int(c[0]), share) <= SIGMA
		ok(fits, "%s hatches %.0f%% female as documented (%d of %d)" % [sp, share * 100.0, c[1], c[0]])
	ok(sp_bad == 0, "every baby's species is one of its parents' (%d off)" % sp_bad)
	ok(trait_bad == 0, "every trait is its parents' mean within %.2f (%d off)" % [TRAIT_NOISE, trait_bad])
	ok(iv_bad == 0, "IVs: %d copied from a named parent, the rest in range (%d off)" % [Care.IV_INHERIT, iv_bad])
	ok(aff_bad == 0, "the evolution head start is one parent's leading way (%d off)" % aff_bad)
	ok(lean_bad == 0, "a baby's lean is only the stronger parent's elements (%d off)" % lean_bad)
	ok(habit_bad == 0, "favourite food and play come from a parent (%d off)" % habit_bad)
	var muts_ok := from_bad == 0 and group_bad == 0
	ok(muts_ok, "mutations known, one per group, dna names parents (%d, %d off)" % [from_bad, group_bad])
	# a mutation neither parent carries is the egg's own roll: rare (sum of 1/rarity, a hundred or two in all)
	var base := 0.0
	for id in mut_ids: base += 1.0 / float(Mutations.info(id)["rarity"])
	var cap := float(PAIRS) * base + SIGMA * sqrt(float(PAIRS) * base)
	ok(float(own_mut) <= cap, "mutations no parent carries are base-odds rolls: %d (at most %.0f)" % [own_mut, cap])
	ok(shimmered <= 3, "shimmer stays about 1 in 4096 (%d of %d)" % [shimmered, PAIRS])
	for k in LOOKS:
		var share := float(look_ok[k]) / PAIRS
		var least := float(LOOKS[k])
		ok(share >= least, "%s matches a parent in %d of %d (min %.0f%%)" % [k, look_ok[k], PAIRS, least * 100.0])
	print("BREED done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
