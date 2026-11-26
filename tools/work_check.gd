extends RefCounted
## --work-check: kin at work. Every species' work elements, bonuses from mutations, old saves,
## jobs read off the farm's state, the best-suited kin taking each job, priorities (Off / High)
## and pins, real output from a few simulated minutes on the farm (watering, harvesting, sowing,
## logs, baking, the Spark Mill, hauling to the chest), hungry kin downing tools to eat, boxed and
## resting kin never working, overwork, and the shimmer odds. Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("WORK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _kin(sp: String, nm: String) -> Dictionary:
	var r := Save.new_kin(sp, nm)
	r["trust"] = 60.0; r["level"] = 5
	return r

func _full(r: Dictionary) -> void:
	Care.ensure(r)
	for n in Care.NEEDS: r["needs"][n] = 100.0
	r.erase("starve")

func _deco(lay: Dictionary, id: String, x: int, z: int) -> Dictionary:
	var e := {"u": HomeLayout._next_uid(lay), "id": id, "x": x, "z": z, "r": 0}
	lay["deco"].append(e)
	return e

func _has_job(hw, kind: String) -> bool:
	return hw.jobs.any(func(j): return String(j["kind"]) == kind)

func run(m: Node) -> void:
	FarmUnlocks.rules()["base_mode"] = false      # walks the old farm (base_mode is the shipped default)
	main = m
	Save.no_write = true
	# ---------------------------------------------------------------- 1. elements as data
	var sp_ok := true
	var lines: Array = []
	for spk in Data.KIN:
		var b := Work.base(spk)
		if b.size() < 1 or b.size() > 3: sp_ok = false
		for el in b:
			if not Work.ELEMENTS.has(el) or int(b[el]) < 1 or int(b[el]) > Work.MAX_LV: sp_ok = false
		lines.append("%s %s" % [Data.KIN[spk]["name"], ", ".join(b.keys().map(func(el): return "%s %d" % [Work.name_of(el), int(b[el])]))])
	print("WORK  elements: %s" % "; ".join(lines))
	ok(sp_ok and Work.ELEMENTS.size() == 12, "every species (%d) has 1-3 of the 12 work elements, levels 1-4" % Data.KIN.size())
	var multi := 0
	for spk in Data.KIN:
		if Work.base(spk).size() >= 2: multi += 1
	ok(multi == Data.KIN.size(), "every species has more than one element (%d of %d)" % [multi, Data.KIN.size()])
	ok(Work.FALLBACK.has("cairnback") and Work.FALLBACK.has("hivara") and Work.FALLBACK.has("zephyrak"), "the boss-egg kin (Cairnback, Hivara, Zephyrak) have elements waiting for them")
	var cov := {}
	for spk in Data.KIN:
		for el in Work.base(spk): cov[el] = true
	ok(cov.size() == 12, "every element is covered by some species (%d of 12)" % cov.size())
	var g := _kin("pebbit", "Boulder"); g["mutations"] = ["giant"]
	var c := _kin("pebbit", "Gem"); c["mutations"] = ["crystal"]
	ok(Work.level(g, "haul") == Work.level(_kin("pebbit", "x"), "haul") + 1 and Work.level(c, "stone") == mini(4, Work.base("pebbit")["stone"] + 1), "mutations sharpen a knack: Giant +1 Haul (%d), Crystal +1 Stone (%d)" % [Work.level(g, "haul"), Work.level(c, "stone")])
	var el2 := _kin("puddlet", "Elder"); el2["forms"] = ["swift", "curious"]
	ok(Work.level(el2, "tide") == 4 and Work.bonus_why(el2).get("tide", "") == "Elder", "an Elder (two forms) is a level better at its best element (Tide %d)" % Work.level(el2, "tide"))
	var fh := _kin("cindle", "Hand"); fh["farmhand"] = true
	ok(Work.level(fh, "tide") >= 1 and Work.level(_kin("cindle", "y"), "tide") == 0, "the old farmhand role still waters (counts as Tide 1)")
	# ---------------------------------------------------------------- 2. old saves
	var old := Save.fresh()
	old.erase("work"); old.erase("mats")
	var orec := {"uid": "old1", "species": "zapple", "name": "Old", "level": 3, "trust": 40.0, "traits": {}}
	old["roster"] = [orec]
	Save.d = old
	Work.ensure()
	ok(Save.d.has("work") and Save.d.has("mats") and Work.mat("wood") == 0 and Work.prio("tide") == Work.PRIO_DEFAULT, "an old save loads: work settings and materials filled in (all Normal)")
	ok(Work.level(orec, "spark") == 3 and Work.level(orec, "haul") == 2 and Work.can_work(orec), "an old kin record gets its species' elements (Echolop: Spark 3, Haul 2)")
	# ---------------------------------------------------------------- 3. a farm
	Save.d = Save.fresh()
	Econ.ensure()
	var roster := {}
	for p in [["puddlet", "Drip"], ["pebbit", "Rocky"], ["cindle", "Ash"], ["zapple", "Zip"], ["burrlet", "Moss"], ["wisplet", "Hoot"]]:
		var r := _kin(p[0], p[1])
		Save.d["roster"].append(r)
		roster[p[0]] = r
	Save.d["active"] = roster["puddlet"]["uid"]
	roster["puddlet"]["starter"] = true
	Save.d["tutorial"]["home"] = true; Save.d["tutorial"]["day1_done"] = true
	var boxed := _kin("puddlet", "Sleepy")
	Save.d["roster"].append(boxed)
	KinBox.ensure()
	KinBox.to_box(boxed)
	Save.d["gems"] = 5000
	Save.d["seeds"] = {"tidebloom": 3, "puffcorn": 2}
	Save.d["plot_cap"] = 4
	Save.d["plots"] = [{"crop": "sunroot", "stage": 0, "care": 0, "wt": 0.0}, {"crop": "puffcorn", "stage": 1, "care": 1, "wt": 0.0}, {"crop": "", "stage": 0}, {"crop": "", "stage": 0}]
	var lay := HomeLayout.ensure(Save.d)
	lay["made"] = true
	var camp := _deco(lay, "lumber_camp", 52, 34)
	var oven := _deco(lay, "hearth_oven", 52, 37)
	var mill := _deco(lay, "spark_mill", 55, 37)
	_deco(lay, "job_board", 55, 34)
	Work.ensure()
	Work.add_mat("wood", 3)
	for r in Save.d["roster"]: _full(r)
	var h = load("res://scripts/home/home.gd").new()
	main.add_child(h)
	for _f in 4: await main.get_tree().process_frame
	# built under a still-covered fade, the farm comes in slices
	while h.building: await main.get_tree().process_frame
	h.day_t = 0.5
	var hw: HomeWork = h.hw
	ok(hw != null and h.kins.size() == 6, "home puts the 6 farm kin out to work (the boxed one stays in the burrow)")
	hw.scan()
	var kinds: Array = []
	for j in hw.jobs:
		if not kinds.has(String(j["kind"])): kinds.append(String(j["kind"]))
	print("WORK  jobs on the farm: %s" % ", ".join(hw.jobs.map(func(j): return String(j["key"]))))
	ok(_has_job(hw, "water") and _has_job(hw, "harvest") and _has_job(hw, "plant") and _has_job(hw, "log") and _has_job(hw, "bake") and _has_job(hw, "power"),
		"jobs from the farm's state: dry plot -> water, ripe crop -> harvest, empty plot + seeds -> sow, camp logs -> split, oven + wood -> bake, flat mill -> crank (%s)" % ", ".join(kinds))
	Work.add_mat("wood", -3)
	hw.scan()
	ok(not _has_job(hw, "bake"), "no wood, no baking job")
	Work.add_mat("wood", 3)
	Work.station(int(camp["u"]))["ready"] = Time.get_unix_time_from_system() + 999.0
	hw.scan()
	ok(not _has_job(hw, "log"), "a camp whose logs are growing back has no job")
	Work.station(int(camp["u"]))["ready"] = 0.0
	hw.scan()
	# ---------------------------------------------------------------- 4. the best-suited kin
	var ent := func(sp: String) -> Dictionary: return h._kin_entry(roster[sp])
	# everyone in one spot by the farm, so distance doesn't decide
	var mid := Vector3(48.0, 0, 34.0)
	for k in h.kins:
		k["pos"] = mid; (k["node"] as Node3D).position = mid
	var bj := func(sp: String) -> String: return String(hw.best_job(ent.call(sp)).get("kind", "-"))
	print("WORK  each kin's pick: %s" % ", ".join(["puddlet", "pebbit", "cindle", "zapple", "burrlet", "wisplet"].map(func(s): return "%s %s" % [roster[s]["name"], bj.call(s)])))
	ok(bj.call("puddlet") == "water" and bj.call("cindle") == "bake" and bj.call("zapple") == "power" and bj.call("pebbit") == "log" and bj.call("burrlet") == "plant",
		"each kin goes for what it's best at: Tide waters, Ember bakes, Spark cranks, Timber splits logs, Bloom sows")
	# two kin who can water: the better one wins it
	var water_j: Dictionary = hw.jobs.filter(func(j): return j["kind"] == "water")[0]
	var sc_p := Work.score(Work.level(roster["puddlet"], "tide"), Work.prio("tide"), 3.0)
	roster["cindle"]["farmhand"] = true
	var sc_c := Work.score(Work.level(roster["cindle"], "tide"), Work.prio("tide"), 3.0)
	ok(sc_p > sc_c * 2.5, "for watering, a Tide 3 Prismander scores %.2f against a farmhand Vespyx's %.2f" % [sc_p, sc_c])
	roster["cindle"].erase("farmhand")
	# ---------------------------------------------------------------- 5. priorities and pins
	Work.set_prio("tide", 0)
	ok(bj.call("puddlet") != "water", "watering set to Off: nobody waters (Drip picks %s)" % bj.call("puddlet"))
	Work.set_prio("tide", 2)
	ok(bj.call("burrlet") == "plant", "Moss (Bloom 3, Forage 2) sows at Normal priorities")
	Work.set_prio("forage", 3)
	ok(bj.call("burrlet") == "harvest", "forage set to High: Moss harvests instead")
	Work.set_prio("forage", 2)
	Work.set_pin(roster["burrlet"], "forage")
	ok(bj.call("burrlet") == "harvest", "pinned to Forage: Moss only harvests")
	Work.set_pin(roster["burrlet"], "")
	Work.set_rest(roster["wisplet"], true)
	ok(not hw.pick(ent.call("wisplet")) and Work.why_not(roster["wisplet"]) == "Resting only", "a kin kept to rest never takes a job")
	Work.set_rest(roster["wisplet"], false)
	ok(not Work.can_work(boxed) and h._kin_entry(boxed).is_empty() and not hw.pick({"rec": boxed, "pos": mid, "node": Node3D.new()}), "a kin in the Kin Burrow never works (not on the island, and refused if asked)")
	# ---------------------------------------------------------------- 6. a few minutes of work
	var p0: Dictionary = Save.d["plots"][0]
	var crops0 := int(Save.d["crops"].get("puffcorn", 0))
	var wood0 := Work.mat("wood"); var kib0 := int(Save.d["items"].get("kibble", 0))
	var took := {}
	var sim := func(secs: float) -> void:
		var steps := int(secs / 0.05)
		for i in steps:
			for k in h.kins:
				if k.has("job"):
					var nm := String(k["rec"]["name"])
					if not took.has(nm): took[nm] = []
					if not (took[nm] as Array).has(String(k["job"]["kind"])): took[nm].append(String(k["job"]["kind"]))
				for n in Care.NEEDS: k["rec"]["needs"][n] = maxf(float(k["rec"]["needs"][n]), 60.0)
			h.day_t = 0.5
			h._move_kin(0.05)
			hw.tick(0.05)
			if i % 20 == 0: h._farm_tick()
			if i % 100 == 0: await main.get_tree().process_frame
	await sim.call(70.0)
	print("WORK  who did what: %s" % str(took))
	ok(float(p0.get("wt", 0.0)) > 0.0 and int(p0.get("wet", 0)) == 2, "the dry Sunroot got watered by a kin (tended)")
	ok(int(Save.d["crops"].get("puffcorn", 0)) > crops0, "the ripe Puffcorn got harvested (%d -> %d)" % [crops0, int(Save.d["crops"].get("puffcorn", 0))])
	ok(String(Save.d["plots"][2]["crop"]) != "" and int(Save.d["seeds"].get("tidebloom", 0)) + int(Save.d["seeds"].get("puffcorn", 0)) < 5, "an empty plot got sown (%s)" % Save.d["plots"][2]["crop"])
	ok(int(Save.d["items"].get("kibble", 0)) > kib0, "the Hearth Oven baked kibble (%d -> %d)" % [kib0, int(Save.d["items"].get("kibble", 0))])
	ok(float(Work.station(int(mill["u"])).get("charge", 0.0)) > 0.0, "the Spark Mill got cranked (charge %d%%)" % int(float(Work.station(int(mill["u"])).get("charge", 0.0))))
	ok(float(Work.station(int(camp["u"])).get("ready", 0.0)) > 0.0 and int(Work.ensure()["made"].get("wood", 0)) > 0, "the Lumber Camp's logs were split into wood (%d made)" % int(Work.ensure()["made"].get("wood", 0)))
	ok((took.get("Drip", []) as Array).has("water") and (took.get("Ash", []) as Array).has("bake") and (took.get("Zip", []) as Array).has("power") and (took.get("Moss", []) as Array).has("plant"),
		"the right kin did them: Drip watered, Ash baked, Zip cranked the mill, Moss sowed")
	# ---------------------------------------------------------------- 7. hauling to the chest
	_deco(lay, "storage_chest", 50, 36)
	h.hb.apply(false)
	Work.station(int(camp["u"]))["ready"] = 0.0
	Work.set_prio("ember", 0)        # the oven would burn the wood as it comes in
	var wd1 := Work.mat("wood")
	var piles_seen := 0
	var hauled := ""
	for i in 150:
		await sim.call(1.0)
		piles_seen = maxi(piles_seen, (Work.ensure()["piles"] as Array).size())
		for nm in took:
			if (took[nm] as Array).has("carry"): hauled = nm
		if Work.mat("wood") > wd1 and piles_seen > 0 and hauled != "": break
		if i % 25 == 24:
			var busy := []
			for k in h.kins:
				busy.append("%s:%s" % [k["rec"]["name"], String(k["job"]["kind"]) + "/" + String(k["job"].get("phase", "")) if k.has("job") else "-"])
			print("WORK  haul wait %ds: piles %d, camp %s, kin %s" % [i + 1, (Work.ensure()["piles"] as Array).size(), str(Work.station(int(camp["u"]))), str(busy)])
	ok(piles_seen > 0 and Work.mat("wood") > wd1 and hauled != "", "with a Storage Chest, split logs wait on a pile and a Haul kin (%s) carries them in (wood %d -> %d)" % [hauled, wd1, Work.mat("wood")])
	Work.set_prio("ember", 2)
	# ---------------------------------------------------------------- 8. hungry kin stop to eat
	var drip: Dictionary = ent.call("puddlet")
	var f: Dictionary = Econ.feeders()[0] if not Econ.feeders().is_empty() else {}
	if not f.is_empty():
		# a food Drip eats: its hated food is drawn from its random uid (Care.ensure), and 1 kin in ~14 hates kibble
		var meal := "sweetbun" if String(drip["rec"]["likes"]["hates"]) == "kibble" else "kibble"
		f["food"] = [meal, meal, meal, meal]
		h.hecon.refresh_feeder(f)
	Save.d["plots"][0] = {"crop": "sunroot", "stage": 0, "care": 0, "wt": 0.0}
	hw.scan()
	for kk in ["indoors", "leap", "exiting", "going_in", "called_t", "busy", "eat", "nap_go"]: drip.erase(kk)
	drip["nap_t"] = 0.0
	(drip["node"] as Node3D).visible = true
	drip["pos"] = Vector3(46.0, 0, 34.0); (drip["node"] as Node3D).position = drip["pos"]
	var wj: Array = hw.jobs.filter(func(j): return j["kind"] == "water")
	if not wj.is_empty(): hw.drop(drip); hw.take(drip, wj[0])
	var had := drip.has("job")
	drip["rec"]["needs"]["food"] = 12.0
	drip["t"] = 0.0
	var ate := false
	var stopped := false
	for i in 400:
		h.day_t = 0.5
		h._move_kin(0.05)
		hw.tick(0.05)
		if not drip.has("job"): stopped = true
		if drip.has("eat"): ate = true; break
		if i % 100 == 0: await main.get_tree().process_frame
	ok(had and stopped and (ate or f.is_empty()), "a hungry kin downs tools and heads to a feeder (was working %s, stopped %s, eating %s)" % [had, stopped, ate])
	var picks := hw.pick(drip)
	ok(not picks or Care.need(drip["rec"], "food") >= Work.START["food"], "and won't take new work until it's eaten (food %d)" % int(Care.need(drip["rec"], "food")))
	# ---------------------------------------------------------------- 9. breaks and overwork
	var zip: Dictionary = ent.call("zapple")
	for k in h.kins: hw.drop(k)
	Work.station(int(mill["u"]))["charge"] = 0.0
	hw.scan()
	zip["rec"]["needs"]["food"] = 100.0; zip["rec"]["needs"]["energy"] = 100.0
	var pj: Array = hw.jobs.filter(func(j): return j["kind"] == "power")
	hw.take(zip, pj[0])
	zip["shift"] = Work.SHIFT + 1.0
	hw._after_shift(zip, "spark")
	ok(zip.has("break_t") and not zip.has("job") and not zip["rec"].get("overworked", false), "after a long shift at Normal priority a kin takes a break")
	zip.erase("break_t")
	Work.set_prio("spark", 3)
	hw.take(zip, pj[0])
	zip["shift"] = Work.SHIFT + 1.0
	hw._after_shift(zip, "spark")
	ok(zip["rec"].get("overworked", false) and zip.has("job"), "on a High priority job it skips the break and gets overworked")
	var j0 := Care.need(zip["rec"], "joy")
	zip["job"]["phase"] = "work"
	hw._drain(zip, 60.0)
	ok(Care.need(zip["rec"], "joy") < j0 - 1.0, "overworked kin get glum while they work (joy %d -> %d)" % [int(j0), int(Care.need(zip["rec"], "joy"))])
	zip["nap_t"] = 5.0; zip["rec"]["needs"]["energy"] = 80.0
	hw.tick(0.1)
	ok(not zip["rec"].get("overworked", false) and float(zip.get("shift", 0.0)) == 0.0, "a nap ends the shift and the overwork")
	Work.set_prio("spark", 2)
	# ---------------------------------------------------------------- 10. the Job Board and the card
	h.open_job_board("Jobs")
	for _f in 2: await main.get_tree().process_frame
	ok(h.panel_open == "Job Board", "the Job Board opens (Jobs tab)")
	h._close_panel()
	h.open_job_board("Kin")
	for _f in 2: await main.get_tree().process_frame
	ok(h.panel_open == "Job Board", "... and its Kin tab")
	h._close_panel()
	# ---------------------------------------------------------------- 10b. auto-sort
	var sv := Save.d
	Save.d = Save.fresh()
	var al := HomeLayout.fresh()
	_deco(al, "lumber_camp", 10, 10)
	_deco(al, "quarry", 14, 10)
	Save.d["layout"] = al
	var peb := _kin("pebbit", "Rocky")
	var fresh_k := _kin("burrlet", "Moss")
	var mine := _kin("pebbit", "Own")
	var rest := _kin("pebbit", "Nap")
	Work.assign(mine, -1)
	Work.set_rest(rest, true)
	Save.d["roster"] = [peb, fresh_k, mine, rest]
	var placed := Work.autosort()
	var top_el: String = Work.list(peb)[0][0]
	var want: String = {"stone": "quarry", "timber": "lumber_camp"}.get(top_el, "")
	var peb_st := ""
	for st in HomeLayout.stations(Save.d):
		if int(st["e"]["u"]) == Work.assigned(peb): peb_st = String(st["id"])
	ok(peb_st == want, "auto-sort: Pebbit (top knack %s) lands at %s" % [top_el, want if want != "" else "no station"])
	ok(Work.assigned(mine) < 0 and Work.assigned(rest) < 0, "auto-sort leaves a kin the owner placed or rested alone")
	ok(Work.autosort().is_empty(), "auto-sort is idempotent (%d placed the first time)" % placed.size())
	Work.assign(peb, -1)
	ok(Work.autosort().is_empty() and Work.assigned(peb) < 0, "an owner's unassign sticks")
	Save.d = sv
	# ---------------------------------------------------------------- 11. shimmer odds
	var rng := RandomNumberGenerator.new(); rng.seed = 99
	var n_v := 2000000
	var wild := 0
	for _j in n_v:
		if Shiny.roll_wild(rng): wild += 1
	var sd := sqrt(n_v * Shiny.WILD)
	ok(absf(wild - n_v * Shiny.WILD) < 4.0 * sd, "wild shimmers over %d rolls: %d (expect %d, 1 in 4096)" % [n_v, wild, int(n_v * Shiny.WILD)])
	var pa := {"shimmer": true}; var pb := {"shimmer": false}
	ok(is_equal_approx(Shiny.egg_chance(pb, pb), 1.0 / 4096.0) and is_equal_approx(Shiny.egg_chance(pa, pb), 1.0 / 2048.0) and is_equal_approx(Shiny.egg_chance(pa, pa), 3.0 / 4096.0), "egg odds: 1 in 4096, 1 in 2048 with a shimmering parent, 1 in 1365 with two")
	ok(is_equal_approx(Shiny.wild_chance(0, true), 2.0 / 4096.0) and is_equal_approx(Shiny.wild_chance(2, false), 1.5 / 4096.0), "rare spawn points x2, the Hollow x1.5")
	h.queue_free()
	print("WORK DONE failures: %d" % bad)
	main.get_tree().quit()
