extends RefCounted
## --mystery-egg-check: the black mystery egg of the hatch scene (MysteryEgg, briefs/DECISIONS.md).
## Its pool is many early wild species (rares included, drawn less often than commons, never a starter
## or a boss kin), it hatches with a mutation far more often than an egg at base odds while the
## starter eggs roll none, and in the scene the three starters stand front and centre while the black
## egg sits in its basket at the back, its card showing only once you've found it. Never touches the
## real save.

const HATCH := preload("res://scripts/ui/hatch.gd")
const DRAWS := 30000
const ROLLS := 20000

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MYSTERYEGG %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_pool()
	_mutations()
	await _scene(main)
	print("MYSTERYEGG DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _pool() -> void:
	var w := MysteryEgg.weights()
	var tiers: Dictionary = MysteryEgg.rules()["pool"]
	ok(w.size() == tiers.size(), "every pool species is in the game (%d of %d)" % [w.size(), tiers.size()])
	ok(w.size() >= 20, "the pool is many early species, not just a few (%d)" % w.size())
	var wrong: Array = w.keys().filter(func(sp): return Data.is_rare(sp) or sp in HATCH.STARTERS)
	ok(wrong.is_empty(), "no starter or boss kin in the pool %s" % str(wrong))
	var rares: Array = w.keys().filter(func(sp): return tiers[sp] == "rare")
	var commons: Array = w.keys().filter(func(sp): return tiers[sp] == "common")
	ok(rares.size() >= 3, "rares are in the pool (%d)" % rares.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var got := {}
	for i in DRAWS:
		var sp := MysteryEgg.roll_species(rng)
		got[sp] = int(got.get(sp, 0)) + 1
	ok(got.keys().all(func(sp): return w.has(sp)), "every draw comes from the pool")
	var rare_missing: Array = rares.filter(func(sp): return not got.has(sp))
	ok(rare_missing.is_empty(), "every rare can hatch (%s never drawn in %d)" % [str(rare_missing), DRAWS])
	var per_rare := _mean(got, rares)
	var per_common := _mean(got, commons)
	var odds := "%.0f vs %.0f draws each" % [per_rare, per_common]
	ok(per_common > 3.0 * per_rare, "a rare is much less likely than a common (%s)" % odds)

func _mean(got: Dictionary, ids: Array) -> float:
	var n := 0
	for sp in ids: n += int(got.get(sp, 0))
	return float(n) / maxf(1.0, ids.size())

func _mutations() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var mystery := 0
	var base := 0
	for i in ROLLS:
		if not MysteryEgg.roll_mutations(rng).is_empty(): mystery += 1
		if not Mutations.roll(rng, 1.0).is_empty(): base += 1
	var pm := float(mystery) / ROLLS
	var pb := float(base) / ROLLS
	var rates := "%.1f%% of the time, an egg at base odds %.1f%%" % [pm * 100.0, pb * 100.0]
	ok(pm > 0.15 and pm > 3.0 * pb, "the black egg hatches mutated far more often (%s)" % rates)

func _scene(main: Node) -> void:
	var tree := main.get_tree()
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}
	Save.d["look"] = Unmasked.default_look()
	var hx = HATCH.new()
	main.add_child(hx)
	for i in 4: await tree.process_frame
	hx._looks_good()
	await tree.process_frame
	var m: int = hx.egg_defs.find_custom(func(d): return d.get("mystery", false))
	var first_three: Array = hx.egg_defs.slice(0, 3).map(func(d): return d["species"])
	ok(m == 3 and first_three == HATCH.STARTERS, "three starter eggs and the mystery egg")
	var starters_plain: bool = hx.egg_defs.slice(0, 3).all(func(d): return not d.has("rec"))
	ok(starters_plain and hx.egg_defs[m].has("rec"), "only the mystery egg rolls mutations at birth")
	var front: Array = hx.eggs.slice(0, 3).map(func(e): return (e["holder"] as Node3D).position)
	var back: Vector3 = (hx.eggs[m]["holder"] as Node3D).position
	var up_front := front.all(func(p): return absf(p.x) <= 1.8 and p.z > back.z + 2.0)
	ok(up_front, "the starters stand front and centre, the black egg well behind (%s)" % str(back))
	var holder: Node3D = hx.eggs[m]["holder"]
	var egg: EggHatch = hx.eggs[m]["egg"]
	var in_basket := holder.get_children().any(func(c): return c is MysteryEgg)
	ok(in_basket and egg.shell_col.get_luminance() < 0.15, "it's a black egg in a basket")
	ok(_cards(hx) == 3, "its card is hidden until you find it (%d cards)" % _cards(hx))
	hx._pick(m)
	await tree.process_frame
	ok(_cards(hx) == 4 and hx.chosen == m, "clicking the black egg picks it and shows its card")
	hx.egg_defs[m]["rec"]["mutations"] = ["giant"]
	hx.kin_node = Models.kin(hx.egg_defs[m]["species"], {"level": 1})
	hx.add_child(hx.kin_node)
	hx._finish(hx.egg_defs[m]["species"], "Nyx", "Orri", true)
	ok(Mutations.of(Save.d["roster"][0]) == ["giant"], "the hatchling keeps the mutation it was born with")
	hx.queue_free()
	await tree.process_frame

## The egg cards in the pick row (the last thing in the bottom box).
func _cards(hx) -> int:
	var rows: Array = hx.bottom.get_children().filter(func(c): return not c.is_queued_for_deletion())
	return (rows[-1] as Node).get_child_count() if not rows.is_empty() else 0
