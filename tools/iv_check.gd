extends RefCounted
## --iv-check: kin IVs (Care.IVS). Rolls in range, stable IVs for old saves (from the kin's id),
## breeding passing 3 of 5 from the parents (and a sane spread over many eggs), the Rare Egg floor,
## the capped multiplier, shimmer not touching IVs, and a save/load round trip. Never touches the
## real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("IVS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _in_range(v: Dictionary) -> bool:
	if v.size() != Care.IV_KEYS.size(): return false
	for k in Care.IV_KEYS:
		if not v.has(k) or int(v[k]) < 0 or int(v[k]) > Care.IV_MAX: return false
	return true

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var sps: Array = Data.common_kin()
	var rng := RandomNumberGenerator.new(); rng.seed = 1234
	# ---------------------------------------------------------------- 1. rolls
	var all_ok := true
	var lo := 99; var hi := -1
	var sum := 0.0; var n := 0
	for i in 2000:
		var v := Care.roll_ivs(rng)
		if not _in_range(v): all_ok = false
		for k in v:
			lo = mini(lo, int(v[k])); hi = maxi(hi, int(v[k])); sum += float(v[k]); n += 1
	ok(all_ok and lo == 0 and hi == 31, "2000 rolls stay 0..31 and reach both ends (%d..%d)" % [lo, hi])
	ok(absf(sum / n - 15.5) < 0.6, "rolls average about 15.5 (%.2f)" % (sum / n))
	var fresh := Save.new_kin(sps[0], "Fresh")
	ok(_in_range(fresh.get("ivs", {})), "a new kin is born with all five IVs: %s" % str(fresh["ivs"]))
	var many := {}
	for i in 40: many[str(Save.new_kin(sps[i % sps.size()])["ivs"])] = true
	ok(many.size() >= 38, "new kin get different IVs (%d distinct of 40)" % many.size())
	# ---------------------------------------------------------------- 2. old saves
	var old := {"uid": "k123456789", "species": sps[1], "name": "Old", "level": 7, "xp": 0, "traits": {}, "trust": 60.0, "memory": []}
	var want := Care.ivs_from_uid("k123456789")
	ok(Care.ivs(old) == want, "a record with no IVs reads the ones its id gives, without changing it (%s)" % str(want))
	ok(not old.has("ivs"), "reading doesn't write")
	Care.ensure(old)
	ok(old.get("ivs", {}) == want, "Care.ensure backfills the same IVs")
	var again := old.duplicate(true); again.erase("ivs"); Care.ensure(again)
	ok(again["ivs"] == old["ivs"] and Care.ivs_from_uid("k123456789") == want, "the backfill is the same every time (deterministic from the uid)")
	ok(Care.ivs_from_uid("k1") != Care.ivs_from_uid("k2"), "different ids, different IVs")
	# ---------------------------------------------------------------- 3. breeding
	var a := Save.new_kin(sps[0], "Ma"); var b := Save.new_kin(sps[1 % sps.size()], "Pa")
	a["ivs"] = {"hp": 31, "atk": 31, "spd": 31, "work": 31, "bond": 31}
	b["ivs"] = {"hp": 30, "atk": 30, "spd": 30, "work": 30, "bond": 30}
	var inh_counts := {}
	var side := [0, 0]
	var per_stat := {}
	for k in Care.IV_KEYS: per_stat[k] = 0
	var three_ok := true
	var kids := 3000
	var kid_sum := 0.0
	for i in kids:
		var kid := Care.breed(a, b, rng)
		var from: Dictionary = kid.get("iv_from", {})
		if from.size() != Care.IV_INHERIT: three_ok = false
		for k in from:
			per_stat[k] += 1
			side[int(from[k])] += 1
			var want_v := 31 if int(from[k]) == 0 else 30
			if int(kid["ivs"][k]) != want_v: three_ok = false
		if not _in_range(kid["ivs"]): three_ok = false
		kid_sum += Care.iv_total(kid)
	ok(three_ok, "every egg takes exactly %d IVs from a parent, with that parent's value" % Care.IV_INHERIT)
	var spread := true
	for k in per_stat:
		if absf(float(per_stat[k]) / kids - 0.6) > 0.04: spread = false
	ok(spread, "each stat is inherited about 60%% of the time: %s" % str(per_stat))
	ok(absf(float(side[0]) / (side[0] + side[1]) - 0.5) < 0.03, "both parents pass on equally (%d / %d)" % side)
	# 3 of 5 from ~30.5 parents plus 2 fresh (15.5): about 122.5
	ok(absf(kid_sum / kids - (3.0 * 30.5 + 2.0 * 15.5)) < 2.0, "great parents give great eggs: average total %.1f (expected ~122.5)" % (kid_sum / kids))
	var five := Care.breed(a, b, rng, "", Care.IV_INHERIT_MAX)
	ok((five["iv_from"] as Dictionary).size() == 5, "inherit_n 5 (a future nest upgrade) passes all five")
	var r1 := RandomNumberGenerator.new(); r1.seed = 99
	var r2 := RandomNumberGenerator.new(); r2.seed = 99
	ok(Care.inherit_ivs(a, b, r1)["ivs"] == Care.inherit_ivs(a, b, r2)["ivs"], "inheritance is repeatable with a seeded rng")
	# ---------------------------------------------------------------- 4. Rare Eggs
	var floor_ok := true
	var rare_sum := 0.0
	for i in 500:
		var rk := Care.hatch_rare({"sp": sps[0], "boss": ""}, rng)
		var hi_n := 0
		for k in Care.IV_KEYS:
			if int(rk["ivs"][k]) >= Care.IV_RARE_FLOOR: hi_n += 1
		if hi_n < Care.IV_RARE_HIGH or not _in_range(rk["ivs"]): floor_ok = false
		rare_sum += Care.iv_total(rk)
	ok(floor_ok, "every Rare Egg kin has at least %d IVs of %d or better" % [Care.IV_RARE_HIGH, Care.IV_RARE_FLOOR])
	ok(rare_sum / 500.0 > 105.0, "Rare Egg kin average well above plain ones (%.1f vs 77.5)" % (rare_sum / 500.0))
	# ---------------------------------------------------------------- 5. the multiplier
	var zero := {"ivs": {"hp": 0, "atk": 0, "spd": 0, "work": 0, "bond": 0}}
	var top := {"ivs": {"hp": 31, "atk": 31, "spd": 31, "work": 31, "bond": 31}}
	var cap_ok := true
	for k in Care.IV_KEYS:
		if absf(Care.iv_mult(zero, k) - 1.0) > 0.0001: cap_ok = false
		if Care.iv_mult(top, k) > 1.1001 or Care.iv_mult(top, k) < 1.0: cap_ok = false
	ok(cap_ok, "0 gives x1.00, 31 gives at most x1.10 (hp %.3f, atk %.3f, spd %.3f, work %.3f, bond %.3f)" % [Care.iv_mult(top, "hp"), Care.iv_mult(top, "atk"), Care.iv_mult(top, "spd"), Care.iv_mult(top, "work"), Care.iv_mult(top, "bond")])
	var mid := {"ivs": {"hp": 15, "atk": 0, "spd": 0, "work": 0, "bond": 0}}
	ok(absf(Care.iv_mult(mid, "hp") - (1.0 + 0.10 * 15.0 / 31.0)) < 0.0001, "linear in between (hp 15: x%.4f)" % Care.iv_mult(mid, "hp"))
	ok(Care.iv_mult(top, "nope") == 1.0 and Care.iv_mult({}, "hp") == 1.0, "unknown stats and empty records are x1.00")
	var wild := {"ivs": {"hp": 400, "atk": -5, "spd": "x", "work": 31.0, "bond": 12.9}}
	ok(Care.iv_mult(wild, "hp") <= 1.1001 and Care.iv(wild, "atk") == 0 and Care.iv(wild, "work") == 31, "bad values are clamped (a hacked record can't go past +10%)")
	# ---------------------------------------------------------------- 6. shimmer doesn't touch IVs
	var sh := Save.new_kin(sps[0], "Glint"); var before: Dictionary = (sh["ivs"] as Dictionary).duplicate()
	sh["shimmer"] = true; Care.ensure(sh)
	ok(Care.ivs(sh) == before, "shimmering doesn't change IVs")
	# ---------------------------------------------------------------- 7. words
	ok(Care.iv_word(0) == "Faint" and Care.iv_word(10) == "Decent" and Care.iv_word(20) == "Pretty good" and Care.iv_word(28) == "Very good" and Care.iv_word(30) == "Fantastic" and Care.iv_word(31) == "Best", "the judge's words per stat")
	ok(String(Care.iv_grade(top)[0]) == "Remarkable" and String(Care.iv_grade(zero)[0]) == "Ordinary stock", "overall grades: %s / %s" % [Care.iv_grade(top)[0], Care.iv_grade(zero)[0]])
	print("IVS  judge: %s" % Care.iv_judge(fresh))
	# ---------------------------------------------------------------- 8. save / load
	var path := "user://iv_check_tmp.json"
	Save.d["roster"] = [fresh, old, five]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(Save.d)); f.close()
	var back = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	var rt := true
	for i in 3:
		var r0: Dictionary = Save.d["roster"][i]
		var rb: Dictionary = back["roster"][i]
		if Care.ivs(rb) != Care.ivs(r0) or absf(Care.iv_mult(rb, "atk") - Care.iv_mult(r0, "atk")) > 0.00001: rt = false
	ok(rt, "IVs survive a save and load (JSON floats read back as the same whole numbers)")
	print("IV CHECK DONE, failures: ", bad)
	m.get_tree().quit()
