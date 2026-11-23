extends RefCounted
## --egg-rules-check: eggs only ever hatch the first form of a Boki line, and the legendaries (content/kin
## "no_egg") never come from an egg. An evolved parent gives a first-form baby, an old save's egg of a later
## form hatches the first form, a legendary never turns up in a boss, Heart or old-save egg over 1000 rolls,
## and two legendaries get no egg, with a message. Never touches the real save.

const ROLLS := 1000
const FAKE := ["sporcupine", "amanitusk"]  # burrlet's later forms (evolve.json), given data for this check

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("EGGRULES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _adult(sp: String, name: String) -> Dictionary:
	var r := Save.new_kin(sp, name)
	r["level"] = NookRules.GROWN_LV
	r["trust"] = 80.0
	return r


func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var legends: Array = Data.KIN.keys().filter(func(k): return Data.is_rare(k))
	ok(not legends.is_empty() and legends.all(func(k): return Data.no_egg(k)), "every legendary is no_egg")
	var pool: Array = Data.egg_pool()
	ok(
		not pool.is_empty() and pool.all(func(k): return not Data.no_egg(k) and Evo.base_form(k) == k),
		"the egg pool is first forms only, no legendary"
	)
	for sp in FAKE:
		Data.KIN[sp] = Data.KIN["burrlet"].duplicate(true)
	var firsts := ["amanitusk", "sporcupine", "burrlet"].map(func(sp): return Evo.base_form(sp))
	ok(firsts == ["burrlet", "burrlet", "burrlet"], "base_form walks a line back to its first form")
	var later_forms := Data.egg_pool().filter(func(sp): return sp in FAKE)
	ok(later_forms.is_empty(), "later forms are not in the pool")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# an evolved parent gives a first-form baby
	var dad := _adult("amanitusk", "Dad")
	var mum := _adult("sporcupine", "Mum")
	var baby := Care.breed(dad, mum, rng)
	ok(baby["species"] == "burrlet", "a T3 and a T2 parent's baby is the first form (%s)" % baby["species"])
	ok(Care.breed(dad, mum, rng, "amanitusk")["species"] == "burrlet", "...even when the egg was laid as a later form")
	# an old save's egg of a T3 hatches the first form, in the Incubator and the shelf
	var egg := {"sp": "amanitusk", "boss": "", "rare": true}
	ok(Care.hatch_rare(egg, rng)["species"] == "burrlet", "an old save's T3 egg hatches the first form")
	Save.d["rare_eggs"] = [
		{"sp": "amanitusk", "boss": "", "rare": true, "id": "a"},
		{"sp": String(legends[0]), "boss": "colossus", "rare": true, "id": "b"}
	]
	Incubator.ensure()
	var held: Array = Incubator.eggs() + Incubator.shelf()
	var held_sp: Array = held.map(func(e): return String(e["sp"]))
	ok(held.size() == 2 and held_sp.all(func(sp): return pool.has(sp)), "old Incubator eggs are first forms")
	for sp in FAKE:
		Data.KIN.erase(sp)
	# no legendary in any egg pool over many rolls
	var bosses: Array = Data.MOBS.keys().filter(func(b): return Data.MOBS[b].has("egg"))
	var seen := {}
	var leaks := 0
	for i in ROLLS:
		var b := String(bosses[i % bosses.size()])
		var drop := Loot.rare_egg(String(Data.MOBS[b]["egg"]), b)
		var heart_sp := Data.egg_species("", rng)
		var old_egg := {"sp": legends[i % legends.size()], "boss": b}
		var old_sp := String(Care.hatch_rare(old_egg, rng)["species"])
		for sp in [String(drop["sp"]), heart_sp, old_sp]:
			seen[sp] = true
			if not pool.has(sp):
				leaks += 1
	ok(leaks == 0, "%d boss, Heart and old-save rolls: first forms only (%d kinds)" % [ROLLS * 3, seen.size()])
	# two legendaries get no egg, with a message; one legendary and a friend still can
	var l1 := _adult(String(legends[0]), "Tor")
	var l2 := _adult(String(legends[-1]), "Vee")
	var friend := _adult("burrlet", "Pip")
	var why := NookRules.pair_why(l1, l2)
	ok(why != "" and why.contains("never come from an egg"), "two legendaries: no egg (%s)" % why)
	ok(NookRules.pair_why(l1, friend) == "", "a legendary and a friend can still pair")
	ok(Data.egg_species(String(legends[0])) != String(legends[0]), "a legendary's egg is rerolled")
	print("EGG RULES CHECK DONE, failures: ", bad)
	m.get_tree().quit()
