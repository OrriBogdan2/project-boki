extends RefCounted
## --nook-check: the Nesting Nook gate (NookRules: Grown, friends, rested, one egg) and what Care.breed
## passes on (the stronger parent's lean as a head start, one habit from each parent).
## Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("NOOK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _kin(sp: String, nick: String, lv: int, trust: float) -> Dictionary:
	var k := Save.new_kin(sp, nick)
	k["level"] = lv
	k["trust"] = trust
	return k

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var a := _kin("cindle", "Ash", 8, 60.0)
	var b := _kin("puddlet", "Bri", 8, 60.0)
	ok(NookRules.pair_why(a, b) == "", "two Grown friends are ready (%s)" % NookRules.pair_why(a, b))
	b["level"] = 7
	ok(NookRules.pair_why(a, b) != "", "a Youngling is not ready")
	b["level"] = 8
	b["trust"] = 40.0
	ok(NookRules.pair_why(a, b) != "", "no friendship, no egg (trust 40 and no bonds)")
	b["bonds"] = {a["uid"]: 55.0}
	ok(NookRules.pair_why(a, b) == "", "a recorded bond of 55 makes them friends")
	b["bonds"] = {a["uid"]: 20.0}
	ok(NookRules.pair_why(a, b) != "", "a recorded bond of 20 does not, whatever the trust")
	b.erase("bonds")
	b["trust"] = 60.0
	a["bred_t"] = Time.get_unix_time_from_system()
	ok(NookRules.pair_why(a, b) != "", "a parent that just laid an egg must rest")
	a["bred_t"] = Time.get_unix_time_from_system() - NookRules.REST_SEC - 1.0
	ok(NookRules.pair_why(a, b) == "", "rested after %d seconds" % int(NookRules.REST_SEC))
	Save.d["egg"] = {"a": a["uid"], "b": b["uid"]}
	ok(NookRules.pair_why(a, b) != "", "one egg in the nest at a time")
	Save.d["egg"] = {}
	# ---- breeding: the stronger parent's lean, a habit from each, the unstable mix
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	a["lean"] = {"ember": 6.0, "storm": 1.0}
	b["lean"] = {"frost": 2.0}
	var took := 0
	var habits := 0
	var kind := true
	for i in 20:
		var pa: Dictionary = a if i % 2 == 0 else b
		var pb: Dictionary = b if i % 2 == 0 else a
		var kid := Care.breed(pa, pb, rng)
		var lean: Dictionary = kid["lean"]
		if lean.has("ember") and not lean.has("frost") and Care.lean_total(kid) < Care.lean_total(a): took += 1
		var fa: bool = kid["likes"]["food"] == a["likes"]["food"] and kid["likes"]["play"] == b["likes"]["play"]
		var fb: bool = kid["likes"]["food"] == b["likes"]["food"] and kid["likes"]["play"] == a["likes"]["play"]
		if fa or fb: habits += 1
		if kid["likes"]["food"] == kid["likes"]["hates"]: kind = false
	ok(took == 20, "20 of 20 babies take the stronger parent's lean as a head start (%d)" % took)
	ok(habits == 20, "20 of 20 babies take the food from one parent and the play from the other (%d)" % habits)
	ok(kind, "a baby never hates its own favourite food")
	a.erase("lean")
	b.erase("lean")
	ok(not Care.breed(a, b, rng).has("lean"), "parents with no lean (older saves) breed a baby with none")
	# ---- the pairing sounds (an unstable pair: tempers far apart)
	var fire := _kin("cindle", "Fi", 8, 60.0)
	var ice := _kin("cindle", "Ic", 8, 60.0)
	fire["traits"]["temper"] = 0.1
	ice["traits"]["temper"] = 0.95
	await _sounds(m, fire, ice)
	print("NOOK done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

## The pairing sounds: each step once and at the nest, notes pitched by size, a wobble only for an unstable
## mix, and the commit plays them.
func _sounds(m: Node, fire: Dictionary, ice: Dictionary) -> void:
	var big := _kin("cindle", "Big", 8, 60.0)
	var tiny := _kin("cindle", "Tiny", 8, 60.0)
	big["dna"] = {"seed": 1, "size": 2.0, "voice": 0.8}
	tiny["dna"] = {"seed": 2, "size": -2.0, "voice": 1.2}
	var steps := NookSfx.plan(big, tiny)
	var notes: Array = _of(steps, "nook_note")
	var low_first: bool = notes.size() == 2 and notes[0]["pitch"] < notes[1]["pitch"]
	ok(low_first, "the chime is two notes, the bigger parent's the lower")
	var chirps: Array = _of(steps, "kin_happy")
	var own: bool = chirps.size() == 2 and is_equal_approx(chirps[0]["pitch"], 0.8)
	own = own and is_equal_approx(chirps[1]["pitch"], 1.2)
	ok(own, "each parent chirps in its own voice")
	var seen := {}
	for s in steps:
		var key := "%s@%.2f" % [s["snd"], s["t"]]
		ok(not seen.has(key) and Sfx.ensure(String(s["snd"])), "%s plays once and loads" % key)
		seen[key] = true
	for cue in ["nook_nuzzle", "nook_settle", "garden_egg"]:
		ok(_of(steps, cue).size() == 1, "%s plays once" % cue)
	ok(_of(steps, "nook_wobble").is_empty(), "a stable pair has no wobble")
	var wobbles := _of(NookSfx.plan(fire, ice), "nook_wobble").size()
	ok(UnstableMix.unstable(fire, ice) and wobbles == 1, "an unstable mix gets one wobble")
	var home_src := FileAccess.get_file_as_string("res://scripts/home/home.gd")
	ok(home_src.contains("NookSfx.commit(get_tree(), rec, ok, NEST_AT)"), "pairing plays them at the nest")
	Sfx.last_played.clear()
	var at := Vector3(3, 0, 4)
	NookSfx.commit(m.get_tree(), big, tiny, at)
	await m.get_tree().create_timer(float(steps[-1]["t"]) + 0.3).timeout
	var heard := true
	for s in steps:
		heard = heard and Sfx.last_played.has(s["snd"])
	ok(heard, "the commit plays every step")

func _of(steps: Array, snd: String) -> Array:
	return steps.filter(func(s): return s["snd"] == snd)
