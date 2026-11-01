extends RefCounted
## --unique-check: every kin is its own (Unique, Save ids and provenance; docs/BOKI_IDENTITY.md).
## Rolls are deterministic from their seed and never touch the global random stream; the spread
## is a bell curve with rare XS / XL tails; eggs inherit from both parents; a v1 save fixture
## (tests/save_fixtures/v1_save.json) migrates with every reference rewritten and every taste,
## IV and look kept; 100,000 ids are all different; the hitbox and the small stat trade-off follow
## size, and the normalize switch turns them off; the model and the About UI build. Never touches
## the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("UNIQUE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _mean_sd(xs: Array) -> Vector2:
	var s := 0.0
	for x in xs: s += float(x)
	var m := s / maxf(1.0, xs.size())
	var v := 0.0
	for x in xs: v += (float(x) - m) * (float(x) - m)
	return Vector2(m, sqrt(v / maxf(1.0, xs.size())))

func _with_size(rec: Dictionary, z: float) -> Dictionary:
	var r := rec.duplicate(true)
	r["dna"]["size"] = z
	return r

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var sps: Array = Data.common_kin()
	# ---------------------------------------------------------------- 1. determinism
	ok(Unique.roll(1234) == Unique.roll(1234), "the same seed always gives the same rolls")
	ok(Unique.roll(1234) != Unique.roll(1235), "a different seed gives different rolls")
	seed(777); var g0 := randi(); seed(777)
	Unique.roll(99); Unique.fresh_seed(); Save.new_id()
	ok(randi() == g0, "rolls, fresh seeds and ids never touch the global random stream")
	# new_kin uses the global stream exactly as it always did (traits, then one roll)
	seed(4242)
	var nk := Save.new_kin(sps[0], "", 555)
	var after := randi()
	seed(4242)
	for k in Data.KIN[sps[0]]["traits"]: randf_range(-0.15, 0.15)
	randi()
	ok(after == randi(), "new_kin takes the same global rolls as before ids changed")
	ok(nk["dna"] == Unique.roll(555) and Save.new_kin(sps[0], "", 555)["dna"] == nk["dna"], "new_kin with a seed is the same kin every time")
	var mscript = load("res://scripts/match/match.gd")
	var m1 = mscript.new(); var m2 = mscript.new()
	m1.seed_val = 5; m2.seed_val = 5
	var s1 := [m1.kin_seed("wild"), m1.kin_seed("bot")]
	var s2 := [m2.kin_seed("wild"), m2.kin_seed("bot")]
	m2.seed_val = 6
	ok(s1 == s2 and s1[0] != s1[1] and m2.kin_seed("wild") != s1[0], "wild and bot kin seeds come from the match seed (same seed, same kin)")
	m1.free(); m2.free()
	# ---------------------------------------------------------------- 2. the spread
	var zs: Array = []
	var xs := 0; var xl := 0
	var marks := {}; var eyes := {}; var quirks := {}
	var props_ok := true; var voice_ok := true
	var N := 20000
	for i in N:
		var dd := Unique.roll(100000 + i)
		zs.append(float(dd["size"]))
		if float(dd["size"]) <= Unique.XS_Z: xs += 1
		if float(dd["size"]) >= Unique.XL_Z: xl += 1
		marks[dd["mark"]] = int(marks.get(dd["mark"], 0)) + 1
		eyes[dd["eye"]] = true; quirks[dd["quirk"]] = true
		for p in Unique.PROPS:
			if absf(float(dd[p]) - 1.0) > Unique.PROP_MAX + 1e-6: props_ok = false
		if float(dd["voice"]) < Unique.VOICE_MIN or float(dd["voice"]) > Unique.VOICE_MAX: voice_ok = false
	var ms := _mean_sd(zs)
	ok(absf(ms.x) < 0.03 and absf(ms.y - 1.0) < 0.04, "size is a bell curve: mean %.3f, sd %.3f" % [ms.x, ms.y])
	ok(absf(float(xs) / N - 0.0228) < 0.006 and absf(float(xl) / N - 0.0228) < 0.006, "XS and XL tails are rare: %.2f%% / %.2f%%" % [100.0 * xs / N, 100.0 * xl / N])
	ok(props_ok and voice_ok, "proportions stay within +-%d%% and voice within its range" % int(Unique.PROP_MAX * 100))
	ok(marks.size() == Unique.MARKS.size() and eyes.size() == Unique.EYES.size() and quirks.size() == Unique.QUIRKS.size(), "every coat, eye colour and habit turns up (%s)" % str(marks))
	# sex: half and half, from the seed alone, and never moving the other rolls
	var fem := 0
	for i in N:
		if Unique.roll(100000 + i)["sex"] == "f": fem += 1
	ok(absf(float(fem) / N - 0.5) < 0.02, "Boki are about half female, half male (%.1f%% female)" % (100.0 * fem / N))
	var r0 := Unique.roll(31337)
	var r0b := r0.duplicate(); r0b.erase("sex")
	var pre_sex := {"dna": r0b, "uid": "x"}
	ok(Unique.sex(pre_sex) == r0["sex"] and Unique.sex_for_seed(31337) == r0["sex"], "a record written before sex existed reads the same sex its seed gives")
	var same_rest := true
	for i in 200:
		var a := Unique.roll(700 + i); a.erase("sex")
		var b := Unique.roll(700 + i); b.erase("sex")
		if a != b: same_rest = false
	ok(same_rest and r0.has("birth") and r0.has("voice"), "sex is its own hash of the seed: the other rolls are untouched")
	var old2 := {"v": 2, "roster": [{"uid": "kA", "species": "cindle", "dna": r0b.duplicate()}], "lost_kin": [], "graves": []}
	ok(Save.migrate(old2) and int(old2["v"]) == Save.VERSION and String(old2["roster"][0]["dna"].get("sex", "")) == r0["sex"], "a v2 save gets every Boki's sex written down (%s)" % r0["sex"])
	var big := Save.new_kin("cindle", "Big", 1); big["dna"]["size"] = 2.6
	var small := Save.new_kin("cindle", "Small", 2); small["dna"]["size"] = -2.6
	var bi := Unique.size_info(big); var si := Unique.size_info(small)
	ok(String(bi["tag"]) == "XL" and String(si["tag"]) == "XS" and float(bi["cm"]) > 38.0 and float(si["cm"]) < 30.0, "sizes in cm and tags: big %.1f cm %s, small %.1f cm %s" % [bi["cm"], bi["tag"], si["cm"], si["tag"]])
	var giant := big.duplicate(true); giant["mutations"] = ["giant"]
	ok(Unique.size_info(giant)["cm"] > float(bi["cm"]) * 1.3, "Giant still sits on top as the extreme tier (%.1f cm)" % Unique.size_info(giant)["cm"])
	# ---------------------------------------------------------------- 3. inheritance
	var pa := Save.new_kin("cindle", "Ma", 11); var pb := Save.new_kin("cindle", "Pa", 12)
	pa["dna"]["size"] = 1.5; pb["dna"]["size"] = 1.5
	pa["dna"]["eye"] = "violet"; pb["dna"]["eye"] = "violet"
	pa["dna"]["mark"] = "stripes"; pb["dna"]["mark"] = "stripes"
	pa["dna"]["limb"] = 1.09; pb["dna"]["limb"] = 1.09
	var kz: Array = []; var kl: Array = []
	var violet := 0; var stripes := 0; var new_seed := true
	for i in 3000:
		var c := Unique.inherit(pa, pb, 500000 + i)
		kz.append(float(c["size"])); kl.append(float(c["limb"]))
		if c["eye"] == "violet": violet += 1
		if c["mark"] == "stripes": stripes += 1
		if int(c["mark_seed"]) == int(pa["dna"]["mark_seed"]) or int(c["mark_seed"]) == int(pb["dna"]["mark_seed"]): new_seed = false
	var kms := _mean_sd(kz)
	ok(absf(kms.x - 1.2) < 0.08 and absf(kms.y - 0.82) < 0.06, "big parents have big young (mean z %.2f, sd %.2f; 0.4 of each parent plus noise)" % [kms.x, kms.y])
	ok(_mean_sd(kl).x > 1.06, "long-legged parents have long-legged young (%.3f)" % _mean_sd(kl).x)
	ok(float(violet) / 3000.0 > 0.86 and float(stripes) / 3000.0 > 0.86, "eye colour and coat pass on (%d%% / %d%%)" % [violet * 100 / 3000, stripes * 100 / 3000])
	ok(new_seed, "each egg's marks are placed by its own seed: never a copy of a parent's")
	ok(Unique.inherit(pa, pb, 42) == Unique.inherit(pa, pb, 42), "the same parents and egg seed give the same young")
	var brng := RandomNumberGenerator.new(); brng.seed = 9
	pa["lineage"] = {"parents": [], "names": [], "gen": 2}
	var baby := Care.breed(pa, pb, brng, "cindle")
	var lin: Dictionary = baby.get("lineage", {})
	ok((lin.get("parents", []) as Array) == [pa["uid"], pb["uid"]] and int(lin.get("gen", 0)) == 3 and String(baby["origin"]["how"]) == "egg", "a bred kin knows its parents' ids and its generation (%s)" % str(lin))
	ok(baby["dna"].has("from"), "a bred kin's rolls come from its parents")
	# ---------------------------------------------------------------- 4. provenance and the log
	Save.d = Save.fresh()
	Save.d["name"] = "Tess"
	var r1 := Save.new_kin("cindle"); r1["origin"] = {"how": "wild", "where": {"map": "Skyreach", "island": "The Heart", "tier": 0, "tier_name": "The Meadow"}}
	var r2 := Save.new_kin("cindle")
	var r3 := Save.new_kin("puddlet")
	for r in [r1, r2, r3]: Save.d["roster"].append(r)
	Save.register(r1); Save.register(r2, "egg"); Save.register_all()
	ok(int(r1["serial"]) == 1 and int(r2["serial"]) == 2 and int(r3["serial"]) == 1, "serials count per species (%d, %d, %d)" % [r1["serial"], r2["serial"], r3["serial"]])
	ok(Save.serial_text(r2) == "#0002 of %s" % Data.KIN["cindle"]["name"], "serial reads \"%s\"" % Save.serial_text(r2))
	ok(String(r1["ot"]["name"]) == "Tess" and String(r1["ot"]["id"]).begins_with("p") and r1.has("edition") and r1["edition"] == null, "original trainer and an empty edition slot")
	var s_before: int = int(r1["serial"])
	Save.register(r1)
	ok(int(r1["serial"]) == s_before and int(Save.d["serials"]["cindle"]) == 2, "registering twice changes nothing")
	var evs: Array = (Save.d["log"] as Array).map(func(e): return String(e["ev"]))
	ok(evs == ["caught", "hatched", "registered"], "the log has what happened: %s" % str(evs))
	for i in Save.LOG_CAP + 30: Save.log_event("renamed", r1)
	ok((Save.d["log"] as Array).size() == Save.LOG_CAP and String(Save.d["log"][-1]["ev"]) == "renamed", "the log keeps at most %d entries" % Save.LOG_CAP)
	# ---------------------------------------------------------------- 5. migration of a v1 save
	var raw := FileAccess.get_file_as_string("res://tests/save_fixtures/v1_save.json")
	var data: Dictionary = JSON.parse_string(raw)
	var old_ids := {}
	for r in data["roster"]: old_ids[String(r["name"])] = String(r["uid"])
	old_ids["Moth"] = String(data["lost_kin"][0]["rec"]["uid"])
	ok(Save.migrate(data) and int(data["v"]) == Save.VERSION, "the v1 fixture upgrades to v%d" % Save.VERSION)
	var by_name := {}
	for r in data["roster"]: by_name[String(r["name"])] = r
	var moth: Dictionary = data["lost_kin"][0]["rec"]
	by_name["Moth"] = moth
	var ids_ok := true
	var seen := {}
	for nm in by_name:
		var r: Dictionary = by_name[nm]
		var u := String(r["uid"])
		if not u.begins_with("b") or u.length() != 23 or seen.has(u) or String(r.get("legacy_uid", "")) != String(old_ids[nm]): ids_ok = false
		seen[u] = true
	ok(ids_ok, "every kin has a new lasting id and keeps its old one as legacy_uid")
	ok(String(data["active"]) == String(by_name["Pip"]["uid"]) and String(data["active2"]) == String(by_name["Drip"]["uid"]), "partner and second point at the new ids")
	ok(String(data["egg"]["a"]) == String(by_name["Pip"]["uid"]) and String(data["egg"]["b"]) == String(by_name["Drip"]["uid"]), "the nest egg's parents point at the new ids")
	ok(String(data["offers"][0]["uid"]) == String(by_name["Drip"]["uid"]), "a rival's buy-back offer points at the new id")
	ok(String(data["graves"][0]["uid"]).begins_with("b") and String(data["graves"][0]["uid"]) == String(data["graves"][0]["rec"]["uid"]) and String(data["graves"][0]["legacy_uid"]) == "k424242", "a grave and its record share the new id")
	ok(String(data["armory"][0]["uid"]) == "i1234567" and String(data["loadout"]["weapon"]) == "i1234567", "item ids are left alone")
	var kept := true
	for nm in by_name:
		var r: Dictionary = by_name[nm]
		var old := String(old_ids[nm])
		if r["ivs"] != Care.ivs_from_uid(old): kept = false
		if r["dna"] != Unique.roll(Unique.legacy_seed(old)): kept = false
		var probe := {"uid": old}
		Care.ensure(probe)
		if r["likes"] != probe["likes"]: kept = false
	ok(kept, "IVs, tastes and looks are the ones the old id gave (nothing about a kin changes)")
	var hows := {}
	for nm in by_name: hows[nm] = String(by_name[nm]["origin"]["how"])
	ok(hows == {"Pip": "starter", "Drip": "wild", "Sprig": "egg", "Tor": "boss_egg", "Fizz": "taken", "Moth": "unknown"}, "origins told from the old records: %s" % str(hows))
	ok(int(by_name["Pip"]["serial"]) == 1 and int(by_name["Sprig"]["serial"]) == 2 and String(by_name["Pip"]["ot"]["name"]) == "Fixture", "serials in the order they were got, the save as original trainer")
	ok(String(data["log"][-1]["ev"]) == "migrated" and data.has("profile"), "the log notes the upgrade")
	var data2: Dictionary = JSON.parse_string(raw)
	Save.migrate(data2)
	ok(data2["roster"][2]["dna"] == data["roster"][2]["dna"] and data2["roster"][2]["uid"] != data["roster"][2]["uid"], "migrating twice gives the same kin (looks from the old id; only the new id is fresh)")
	# the real load path: a v1 file upgrades, leaving a backup; a newer file is never touched
	var tmp := "user://unique_check_v1.json"
	var f := FileAccess.open(tmp, FileAccess.WRITE); f.store_string(raw); f.close()
	Save.no_write = false
	Save.load_from(tmp)
	Save.no_write = true
	ok(int(Save.d["v"]) == Save.VERSION and (Save.d["roster"] as Array).size() == 5 and FileAccess.file_exists(tmp + ".bak-v1"), "loading a v1 file upgrades it and keeps a .bak-v1 copy")
	var nf := FileAccess.open(tmp, FileAccess.WRITE); nf.store_string(JSON.stringify({"v": 99, "name": "Future", "roster": []})); nf.close()
	Save.load_from(tmp)
	ok(Save.newer and (Save.d["roster"] as Array).is_empty(), "a save from a newer game isn't loaded and is marked never to overwrite")
	Save.newer = false
	DirAccess.remove_absolute(tmp); DirAccess.remove_absolute(tmp + ".bak-v1")
	Save.d = Save.fresh()
	# ---------------------------------------------------------------- 6. ids
	var many := {}
	var len_ok := true
	var t0 := Time.get_ticks_msec()
	for i in 100000:
		var id := Save.new_id()
		if id.length() != 23: len_ok = false
		many[id] = true
	ok(many.size() == 100000 and len_ok, "100,000 ids, all different, all 23 characters (%d ms)" % (Time.get_ticks_msec() - t0))
	var ida := Save.new_id()
	OS.delay_msec(3)
	var idb := Save.new_id()
	ok(ida.substr(0, 10) < idb.substr(0, 10), "ids sort by when they were made (%s < %s)" % [ida.substr(0, 10), idb.substr(0, 10)])
	# ---------------------------------------------------------------- 7. size in a match
	var base := Save.new_kin("cindle", "Mid", 3); base["dna"]["size"] = 0.0
	var kb := _with_size(base, 2.8); var ksm := _with_size(base, -2.8)
	var gs := GDScript.new()
	gs.source_code = "extends Node\nvar opts := {}\nvar tier := 0\n"
	gs.reload()
	var mn = gs.new()
	var kins := []
	for r in [base, kb, ksm]:
		var k := Kin.new(); k.init_kin(mn, "u%d" % kins.size(), "cindle", r, null); kins.append(k)
	ok(kins[1].r > kins[0].r * 1.15 and kins[2].r < kins[0].r * 0.85, "the hitbox scales with size (%.3f / %.3f / %.3f)" % [kins[0].r, kins[1].r, kins[2].r])
	var hp_up: float = kins[1].max_hp / kins[0].max_hp; var sp_dn: float = kins[1].speed / kins[0].speed
	ok(hp_up > 1.0 and hp_up <= 1.0 + Unique.SIZE_STAT + 1e-4 and sp_dn < 1.0 and sp_dn >= 1.0 - Unique.SIZE_STAT - 1e-4, "bigger: a little more health (x%.3f), a little slower (x%.3f), capped at %d%%" % [hp_up, sp_dn, int(Unique.SIZE_STAT * 100)])
	ok(kins[2].speed > kins[0].speed and kins[2].max_hp < kins[0].max_hp, "smaller: a little faster, a little less health")
	var mm := Unique.match_mods(_with_size(base, 3.0))
	ok(absf(float(mm["hp"]) - 1.04) < 1e-4 and absf(float(mm["speed"]) - 0.96) < 1e-4, "the trade-off is capped at +-4%")
	mn.opts = {"normalize_size": true}
	var kn := Kin.new(); kn.init_kin(mn, "n1", "cindle", kb, null)
	ok(is_equal_approx(kn.r, kins[0].r) and is_equal_approx(kn.max_hp, kins[0].max_hp) and is_equal_approx(kn.speed, kins[0].speed), "a normalized match (opts.normalize_size) neutralizes size: same hitbox and stats as an average one")
	mn.opts = {}
	Unique.normalize = true
	var kn2 := Kin.new(); kn2.init_kin(mn, "n2", "cindle", ksm, null)
	Unique.normalize = false
	ok(is_equal_approx(kn2.r, kins[0].r) and is_equal_approx(kn2.speed, kins[0].speed), "so does the global Unique.normalize switch")
	for k in kins + [kn, kn2]: k.free()
	mn.free()
	# ---------------------------------------------------------------- 8. the model
	var mb := Models.kin("cindle", kb); var msm := Models.kin("cindle", ksm); var mmid := Models.kin("cindle", base)
	var r_big := float(mb.get_meta("evo_scale", 1.0)) / float(mmid.get_meta("evo_scale", 1.0))
	ok(absf(r_big - Unique.height_k(kb)) < 0.001 and msm.scale.x < mmid.scale.x, "the model is the size it rolled (x%.3f)" % r_big)
	var mats: Array = mb.get_meta("mats", [])
	var spotted := base.duplicate(true); spotted["dna"]["mark"] = "spots"; spotted["dna"]["ears"] = "tufted"; spotted["dna"]["tailv"] = "tufted"; spotted["dna"]["birth"] = ["star", "left flank"]
	var ms_m := Models.kin("cindle", spotted)
	var m0: ShaderMaterial = (ms_m.get_meta("mats", []) as Array)[0]
	ok(int(m0.get_shader_parameter("mark_kind")) == 1, "a spotted kin wears spots")
	ok(ms_m.find_child("Tuft", true, false) != null and ms_m.find_child("TailTuft", true, false) != null and ms_m.find_child("Birthmark", true, false) != null, "tufted ears and tail and a birthmark are on the model")
	var twin := spotted.duplicate(true); twin["uid"] = Save.new_id(); twin["dna"]["mark_seed"] = int(spotted["dna"]["mark_seed"]) + 1
	var mt := Models.kin("cindle", twin)
	ok(((mt.get_meta("mats", []) as Array)[0] as ShaderMaterial).get_shader_parameter("mark_seed") != m0.get_shader_parameter("mark_seed"), "two spotted kin never wear the same spots")
	ok(String(mb.get_meta("quirk", "")) == String(kb["dna"]["quirk"]), "its idle habit is handed to the puppet (%s)" % mb.get_meta("quirk", ""))
	var plain := Models.kin("cindle", {})
	ok(not plain.has_meta("quirk") and is_equal_approx(plain.scale.x, 1.0), "a look-only model (galleries) stays the species' plain look")
	for n in [mb, msm, mmid, ms_m, mt, plain]: n.free()
	# ---------------------------------------------------------------- 9. care and UI
	var fav := Save.new_kin("cindle", "Fav", 7)
	Care.ensure(fav)
	var food := String(fav["likes"]["food"])
	fav["needs"]["food"] = 10.0
	var twin_f := fav.duplicate(true)
	twin_f["likes"]["food"] = "nothing"
	Care.feed(fav, food); Care.feed(twin_f, food)
	ok(Care.need(fav, "food") > Care.need(twin_f, "food"), "its favourite food fills it a little more (%.1f vs %.1f)" % [Care.need(fav, "food"), Care.need(twin_f, "food")])
	Save.d = Save.fresh()
	for r in [pa, baby]: Save.d["roster"].append(r)
	Save.register_all()
	var box := VBoxContainer.new()
	AboutView.block(baby, box)
	var n_full := box.get_child_count()
	var box2 := VBoxContainer.new()
	AboutView.block(baby, box2, true)
	ok(n_full >= 12 and box2.get_child_count() == 3, "the About section builds (%d rows full, %d compact)" % [n_full, box2.get_child_count()])
	var texts := []
	for o in [{"how": "wild", "where": {"island": "The Heart", "map": "Skyreach", "tier_name": "The Meadow"}}, {"how": "boss_egg", "where": {"lair": ""}}, {"how": "starter"}, {"how": "market", "from": "Wren"}, {"how": "taken", "from": "Vexa"}, {}]:
		texts.append(AboutView.origin_text({"origin": o}))
	ok(texts[0] == "Tamed in the wild at The Heart, Skyreach (The Meadow)" and texts[5] == "From before records were kept", "origins read well: %s" % str(texts))
	ok(AboutView.parents_text(baby).begins_with("Ma and Pa"), "parents shown: %s" % AboutView.parents_text(baby))
	box.free(); box2.free()
	print("UNIQUE DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
