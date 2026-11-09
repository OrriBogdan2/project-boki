extends RefCounted
## --farmbuild-check: the farm building pass (docs/decisions/0004-farm-building.md).
##   1. unlocks: a new farm opens with the few things without a requirement; farm level and the three
##      milestones open the rest once Hob has drawn them up (the tutorial check covers Hob himself); older farms and anything already owned stay open; incubator cradles
##   2. build mode: locked entries show their requirement, costs are icons, a locked item can't be
##      taken, placement legality (sky, on the house, on another site), the starters go up at once
##   3. a placed building is a construction site: it pays gems + materials, drops out of the working
##      stations, is drawn scaffolded with a bar, can be moved, taken down for a full refund, undone
##   4. Boki build it: swings, progress, skill makes swings quicker, the finished building works
##   5. upgrades: tier 2 and 3 cost materials and labour, need farm level, show on the model and
##      speed the station up; a station keeps working while it is upgraded
##   6. save and load of sites and tiers (JSON round trip), and an old save with none of it
## Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FARMBUILD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _new_save() -> Dictionary:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k); d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	return d

func _put(hb: HomeBuild, cs: Array) -> bool:
	hb.cells = cs; hb._check_cells()
	return hb.place_held()

func _spot(hb: HomeBuild, p: Vector3, min_d := 0.0) -> Array:
	var id := String(hb.held["id"])
	var sz := HomeLayout.size_of(id, int(hb.held["r"]))
	for rad in range(int(min_d), 22):
		for k in 48:
			var a := float(k) / 48.0 * TAU
			var x := int(round(p.x + cos(a) * rad - sz.x * 0.5)); var z := int(round(p.z + sin(a) * rad - sz.y * 0.5))
			var cs := HomeLayout.cells_of([x, z, x + sz.x - 1, z + sz.y - 1])
			if hb.fits(hb.held, cs): return cs
	return []

func _stats(extracts := 0, bosses := 0, caught := 0, harvested := 0, hatched := 0) -> void:
	var built := int(Save.d.get("stats", {}).get("fb_built", 0))
	Save.d["stats"] = {"extracts": extracts, "bosses": bosses, "caught": caught, "harvested": harvested, "hatched": hatched, "fb_built": built}
	Save.d["extracts"] = extracts
	FarmBuilder.draw_up()      # Hob has drawn up whatever the farm has earned

func _entry(lay: Dictionary, id: String) -> Dictionary:
	for e in lay["deco"]:
		if String(e["id"]) == id: return e
	return {}

func _mats(wood: int, stone: int, fibre: int, coals: int) -> void:
	Save.d["mats"] = {"wood": wood, "stone": stone, "fibre": fibre}
	Save.d["items"]["coals"] = coals

func _sim(home, hw: HomeWork, secs: float, until: Callable = Callable()) -> void:
	for i in int(secs / 0.05):
		for k in home.kins:
			for n in Care.NEEDS: k["rec"]["needs"][n] = maxf(float(k["rec"]["needs"][n]), 70.0)
		home.day_t = 0.5
		home._move_kin(0.05)
		hw.tick(0.05)
		if until.is_valid() and until.call(): return
		if i % 100 == 0: await main.get_tree().process_frame

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--farmbuild-shots="):
			await load("res://tools/farmbuild_shots.gd").new().run(m, a.substr(18))
			return
	Save.no_write = true
	# ---------------------------------------------------------------- 1. unlocks
	Save.d = _new_save()
	var L: Dictionary = HomeLayout.ensure(Save.d)
	_stats()
	ok(HomeLayout.fs(Save.d) and int(L.get("fb", 0)) == 1 and FarmUnlocks.gated(),
			"a new farm is a farm-start island with the building pass on")
	ok(FarmUnlocks.level() == 1 and FarmUnlocks.open("house") and FarmUnlocks.open("crop_patch") and FarmUnlocks.open("cook_pot"),
			"farm level 1: the house, crop patch and cooking pot are open")
	var closed := 0
	for id in FarmUnlocks.rules()["unlock"]:
		if not FarmUnlocks.open(String(id)): closed += 1
	ok(closed == (FarmUnlocks.rules()["unlock"] as Dictionary).size(),
			"every other building, station and decoration in the table starts locked (%d)" % closed)
	ok(FarmUnlocks.lock_text("lumber_camp") == "Farm level 2" and FarmUnlocks.lock_text("armory").begins_with("Make it out"),
			"a locked item says what opens it: '%s' / '%s'" % [FarmUnlocks.lock_text("lumber_camp"), FarmUnlocks.lock_text("armory")])
	ok(FarmUnlocks.open("fence") and FarmUnlocks.open("path_dirt"), "the plain fence and dirt path are not gated")
	var lv_prev := 1
	var rising := true
	for hv in [0, 30, 70, 130, 200, 300]:
		_stats(0, 0, 0, hv)
		if FarmUnlocks.level() < lv_prev: rising = false
		lv_prev = FarmUnlocks.level()
	_stats(0, 0, 0, 24)         # 6 points
	ok(rising and FarmUnlocks.level() == 2 and FarmUnlocks.open("lumber_camp") and not FarmUnlocks.open("hearth_oven"),
			"farm level follows play (24 harvests make level 2 and open the Lumber Camp, not the Oven)")
	_stats(1, 0, 0, 0)
	ok(FarmUnlocks.open("armory") and not FarmUnlocks.open("shrine") and not FarmUnlocks.open("kin_statue"),
			"the first extraction opens the Armory")
	_stats(1, 1, 0, 0)
	ok(FarmUnlocks.open("shrine") and FarmUnlocks.open("fountain"),
			"the first boss opens the Soul Shrine and the fountain")
	_stats(1, 0, 3, 0)
	ok(FarmUnlocks.open("kin_statue") and FarmUnlocks.open("blossom_tree"),
			"three scanned Boki open the Boki statue and the blossom tree")
	_stats(10, 3, 6, 100, 3)
	ok(FarmUnlocks.level() == FarmUnlocks.max_level() and FarmUnlocks.open("cold_store") and FarmUnlocks.progress()[1] == 0,
			"plenty of play reaches the top level (%d) and opens it all" % FarmUnlocks.level())
	_stats()
	ok(FarmUnlocks.cradle_lock(6) != "" and FarmUnlocks.cradle_lock(8) != "",
			"the 6th and 8th incubator cradles are locked at level 1 ('%s')" % FarmUnlocks.cradle_lock(6))
	Save.d["gems"] = 5000
	Incubator.ensure()
	ok(Incubator.expand() == FarmUnlocks.cradle_lock(6) and Incubator.slots() == Incubator.SLOTS,
			"buying a cradle is refused with the reason, no gems spent")
	_stats(10, 3, 6, 100, 3)
	var why_cr := Incubator.expand()
	ok(why_cr == "" and Incubator.slots() == Incubator.SLOTS + 1,
			"at a high enough farm level the cradle can be bought ('%s')" % why_cr)
	if Save.d.has("incubator"): Save.d["incubator"]["slots"] = Incubator.SLOTS
	_stats()
	# an old farm and owned items
	var legacy := Save.fresh()
	legacy["layout"] = HomeLayout.fresh()
	var keep := Save.d
	Save.d = legacy
	ok(not FarmUnlocks.gated() and FarmUnlocks.open("cold_store") and FarmUnlocks.cradle_lock(8) == "" and not FarmSites.uses_site("lumber_camp"),
			"an older farm (no building pass) keeps everything open and builds at once")
	Save.d = keep
	var qe := {"u": HomeLayout._next_uid(L), "id": "quarry", "x": 40, "z": 40, "r": 0}
	(L["deco"] as Array).append(qe)
	ok(FarmUnlocks.open("quarry") and not FarmUnlocks.open("lumber_camp"),
			"something you already own stays open even if its level is not reached")
	(L["deco"] as Array).erase(qe)
	# ---------------------------------------------------------------- 2. build mode
	Save.d = _new_save()
	Save.d["gems"] = 600
	var rk := Save.new_kin("wisplet", "Wisp"); rk["level"] = 5
	var ash := Save.new_kin("cindle", "Ash"); ash["level"] = 5
	for r in [rk, ash]:
		Care.ensure(r)
		for nd in Care.NEEDS: r["needs"][nd] = 100.0
	_stats()
	_mats(0, 0, 0, 0)
	var home = await main._hb_home()
	var hb: HomeBuild = home.hb
	var hw: HomeWork = home.hw
	home._close_panel()
	L = HomeLayout.of(Save.d)
	hb.toggle()
	hb.cat = "Work"; hb._build_bar()
	var items: Array = hb._tab_items()
	ok(items.size() == 1 and String(items[0]["name"]).begins_with("Ranch Pen"),
			"the Work tab shows only the Ranch Pen on a new farm: the locked stations are hidden, not greyed (%d)" % items.size())
	ok(not FarmBuilder.tab_shown(hb, "Lights") and FarmBuilder.tab_shown(hb, "Work") and FarmBuilder.tab_shown(hb, "Buildings"),
			"a tab with nothing to build now is hidden (Lights), the others stay")
	hb.take("lumber_camp")
	ok(hb.held.is_empty(), "a locked item can't be picked up")
	hb.cat = "Buildings"; hb._build_bar()
	var bi: Array = hb._tab_items()
	var house_it: Dictionary = {}
	for it in bi:
		if String(it["name"]).begins_with("House"): house_it = it
	var hc_cost: Dictionary = house_it.get("cost", {})
	var priced: bool = int(hc_cost.get("gems", 0)) == 0 and int(hc_cost.get("wood", 0)) >= 10 \
			and int(hc_cost.get("stone", 0)) >= 6 and int(hc_cost.get("labour", 0)) >= 8
	ok(bi.size() >= 3 and priced and bi.all(func(it): return not it.get("lock", false)),
			"the Buildings tab shows the house for wood, stone and swings of work, and nothing locked")
	var chips := 0
	for ch in hb.bar.find_children("*", "Control", true, false):
		if ch is FarmIcon: chips += 1
	ok(chips >= 1, "the cost icons are on the bar (%d)" % chips)
	# the starters go up at once
	var land := HomeLayout.LANDING
	_mats(10, 6, 0, 0)      # the house costs wood and stone, spent as it goes up
	hb.take("house")
	var hc := _spot(hb, land + Vector3(0, 0, -8))
	ok(_put(hb, hc) and FarmSites.is_site(_entry(L, "house")) and HomeLayout.fixtures(Save.d, "house").is_empty(),
			"the house goes up as a free construction site, not the farm's house yet")
	while FarmSites.has_site(_entry(L, "house")): FarmSites.add_swing(_entry(L, "house"))
	hb.apply(false)
	home._sync_fixtures()
	ok(not HomeLayout.fixtures(Save.d, "house").is_empty() and home.spots["house"].x > 0.0,
			"and once built it is the farm's house")
	hb.take("crop_patch")
	var pc := _spot(hb, home.spots["house"] + Vector3(7, 0, 2))
	ok(_put(hb, pc) and home.plots.size() == 4, "so does the crop patch")
	hb.take("cook_pot")
	ok(_put(hb, _spot(hb, home.spots["house"] + Vector3(4, 0, 3))), "and the cooking pot")
	# the rest of the crew arrives once there is a house to gather round (they would have nowhere to stand before)
	hb.toggle()
	for r in [rk, ash]: Save.d["roster"].append(r)
	home.queue_free()
	await main.get_tree().process_frame
	home = await main._hb_home()
	hb = home.hb
	hw = home.hw
	home._close_panel()
	L = HomeLayout.of(Save.d)
	hb.toggle()
	# unlock the Lumber Camp by level, then try to buy it with nothing
	_stats(0, 0, 0, 24)
	hb.take("lumber_camp")
	ok(hb.held.get("id", "") == "lumber_camp", "open, and free to mark out even with no wood")
	hb._drop_held()
	_mats(10, 10, 10, 2)
	var g0 := int(Save.d["gems"])
	hb.take("lumber_camp")
	ok(hb.held.get("id", "") == "lumber_camp", "with the materials it can")
	# placement legality
	ok(not _put(hb, [Vector2i(1, 1), Vector2i(2, 1)]) and hb.why != "", "placing in the sky is refused: %s" % hb.why)
	var he := _entry(L, "house")
	ok(not _put(hb, HomeLayout.cells_of([int(he["x"]), int(he["z"]), int(he["x"]) + 1, int(he["z"])])) and hb.why != "",
			"placing on the house is refused: %s" % hb.why)
	ok(int(Save.d["gems"]) == g0 and Work.mat("wood") == 10, "refused placements cost nothing")
	var cc := _spot(hb, home.spots["house"] + Vector3(-6, 0, 4))
	hb.cells = cc; hb._check_cells(); hb._draw_cells()
	var outline := FarmBuildUi.count(hb.ghost_cells, "outline") == 4 and FarmBuildUi.count(hb.ghost_cells, "grid") >= 4
	ok(hb.ghost_ok and outline, "a good spot is accepted and shows the footprint outline and the snapping grid")
	hb.cells = [Vector2i(1, 1)]; hb._check_cells(); hb._draw_cells()
	ok(not hb.ghost_ok and hb.why != "" and FarmBuildUi.count(hb.ghost_cells, "note") == 0,
			"a bad spot gives its reason at the cursor ('%s'), not as a second label" % hb.why)
	hb.cells = cc; hb._check_cells()
	ok(hb.place_held(), "placed")
	var camp := _entry(L, "lumber_camp")
	var cost := FarmSites.build_cost("lumber_camp")
	ok(FarmSites.is_site(camp) and int(camp["site"]["need"]) == int(cost["labour"]) and int(camp["site"]["got"]) == 0,
			"it is a construction site needing %d swings of Boki work" % int(camp["site"]["need"]))
	ok(int(Save.d["gems"]) == g0 and Work.mat("wood") == 10 and Work.mat("stone") == 10,
			"marking it out is free (it will take %s as it goes up)" % FarmSites.cost_text(cost))
	ok(HomeLayout.stations(Save.d).is_empty() and not hw.has_station("lumber_camp"),
			"a site is not a working station yet")
	var cn: Node3D = hb.nodes.get(int(camp["u"]))
	ok(is_instance_valid(cn) and cn.get_node_or_null("Bar") is Sprite3D and cn.get_node_or_null("Rise") != null and cn.get_node_or_null("Logs") == null,
			"it is drawn as scaffolding with a progress bar")
	ok(home.world.is_block(cc[0].x + 0.5, cc[0].y + 0.5), "its footprint blocks the ground")
	# a second one on top of the first
	_mats(10, 10, 10, 2)
	hb.take("lumber_camp")
	ok(not _put(hb, cc) and hb.why != "", "nothing goes on top of a site: %s" % hb.why)
	hb._drop_held()
	# move it
	hb.pick_up_at(cc[0])
	ok(hb.held.get("from", -1) == int(camp["u"]), "clicking a site picks it up to move")
	var cc2 := _spot(hb, home.spots["house"] + Vector3(-6, 0, -4))
	ok(_put(hb, cc2) and FarmSites.is_site(_entry(L, "lumber_camp")) and int(_entry(L, "lumber_camp")["u"]) == int(camp["u"]) and Work.mat("wood") == 10,
			"moved: still the same site, nothing paid twice")
	# take it down: full refund, nothing in storage
	FarmSites.add_swing(_entry(L, "lumber_camp"))      # the first swing pays the first quarter
	var paid: Dictionary = (_entry(L, "lumber_camp")["site"]["paid"] as Dictionary).duplicate()
	ok(not paid.is_empty() and Work.mat("wood") < 10, "the first swing spent the first quarter (%s)" % FarmSites.cost_text(paid))
	hb.pick_up_at(cc2[0])
	var w_before := Work.mat("wood")
	var gm_before := int(Save.d["gems"])
	hb.store_held()
	var back: bool = Work.mat("wood") == w_before + int(paid.get("wood", 0)) and int(Save.d["gems"]) == gm_before + int(paid.get("gems", 0))
	ok(_entry(L, "lumber_camp").is_empty() and back and int(L["inv"].get("lumber_camp", 0)) == 0,
			"taking a site down gives back what it had spent and puts nothing in storage")
	# undo restores everything, fibre and coals included (the Market stall opens at farm level 3)
	_stats(0, 0, 0, 64)
	_mats(10, 10, 10, 2)
	hb.take("storage_chest")
	var st_cost := FarmSites.build_cost("storage_chest")
	var stc := _spot(hb, home.spots["house"] + Vector3(-6, 0, 4))
	var f0 := Work.mat("fibre"); var gg := int(Save.d["gems"])
	ok(_put(hb, stc) and Work.mat("fibre") == f0, "the storage chest site is free to mark out (it will take %s)" % FarmSites.cost_text(st_cost))
	hb.undo_last()
	L = HomeLayout.of(Save.d)      # (undo puts the saved layout back)
	ok(Work.mat("fibre") == f0 and int(Save.d["gems"]) == gg and _entry(L, "storage_chest").is_empty(), "undo takes the site back and returns gems, wood and fibre")
	hb.toggle()
	# ---------------------------------------------------------------- 4. Boki build it
	_stats(0, 0, 0, 40)          # farm level 2 (10 points)
	_mats(30, 30, 30, 6)
	Save.d["gems"] = 500
	hb.toggle()
	hb.take("lumber_camp")
	var cc3 := _spot(hb, home.spots["house"] + Vector3(-5, 0, 5))
	ok(_put(hb, cc3), "a Lumber Camp site goes down at level 2+")
	hb.toggle()
	camp = _entry(L, "lumber_camp")
	var cu := int(camp["u"])
	var need_camp := int(camp["site"]["need"])
	hw.scan_t = 0.0
	hw.scan()
	ok(hw.jobs.any(func(j): return String(j["kind"]) == "build" and int(j["u"]) == cu),
			"the farm has a build job for it")
	ok(hw.jobs.filter(func(j): return String(j["kind"]) == "build").size() == 2,
			"two Boki at most work one site at once")
	var lv_seen := {}
	var ping := func() -> bool:
		for k in home.kins:
			if k.has("job") and String(k["job"]["kind"]) == "build" and String(k["job"]["phase"]) == "work":
				lv_seen[String(k["rec"]["name"])] = [int(k["job"]["lv"]), float(k["job"]["dur"])]
		return not FarmSites.is_site(_entry(L, "lumber_camp"))
	var gm := [-1]      # (a lambda sees a copy of plain numbers: keep the count in an array)
	await _sim(home, hw, 300.0, func() -> bool:
		var e := _entry(L, "lumber_camp")
		if FarmSites.is_site(e) and int(e["site"]["got"]) >= 1 and int(gm[0]) < 0:
			gm[0] = int(e["site"]["got"])
			print("FARMBUILD  first swing landed: %d of %d, bar %.0f%%" % [int(gm[0]), need_camp, FarmSites.progress(e) * 100.0])
		return ping.call())
	ok(int(gm[0]) >= 1,
			"Boki walked over and landed swings (progress %d of %d seen mid-build)" % [int(gm[0]), need_camp])
	camp = _entry(L, "lumber_camp")
	ok(not camp.is_empty() and not FarmSites.has_site(camp) and FarmSites.tier(camp) == 1,
			"the last swing finishes it: it is a tier 1 Lumber Camp")
	ok(Progress.stat("fb_built") == 2 and hw.has_station("lumber_camp"),
			"it counts toward farm level and is a working station now")
	await main.get_tree().process_frame
	cn = hb.nodes.get(cu)
	ok(is_instance_valid(cn) and cn.get_node_or_null("Bar") == null and cn.get_node_or_null("Logs") != null,
			"the scaffold is gone and the camp's model stands")
	print("FARMBUILD  swing lv/duration by builder: %s" % str(lv_seen))
	var lvs: Array = lv_seen.values()
	var sorted_ok := true
	for a in lvs:
		for b in lvs:
			if int(a[0]) > int(b[0]) and float(a[1]) >= float(b[1]) - 0.001: sorted_ok = false
	ok(lvs.size() >= 1 and sorted_ok, "a higher building skill makes a swing quicker (%d builders seen)" % lvs.size())
	var bj := {"kind": "build", "el": "craft", "u": cu}
	ok(Work.level(rk, "craft") == 2 and Work.level(Save.d["roster"][0], "craft") == 0 and FarmSites.level(Save.d["roster"][0], bj) == 1 and FarmSites.level(rk, bj) == 2 and Work.speed(2) > Work.speed(1),
			
		"a Boki with no Craft knack still builds at skill 1; a Craft 2 Boki builds at 2, which is quicker (x%.2f)" % (Work.speed(2) / Work.speed(1)))
	# a site whose builders are not allowed (Craft Off on the Job Board): nobody builds it
	Work.set_prio("craft", 0)
	var j_off := {"kind": "build", "el": "craft", "u": cu}
	ok(not FarmSites.takes(rk, j_off), "Craft set to Off on the Job Board stops the building")
	Work.set_prio("craft", 2)
	# ---------------------------------------------------------------- 5. upgrades
	_stats(0, 0, 0, 24)          # farm level 2: tier 2 needs 3
	_mats(40, 40, 40, 6)
	hb.toggle()
	hb.cat = "Upgrades"; hb._build_bar()
	var up_items: Array = hb._tab_items()
	var up_camp: Dictionary = {}
	for it in up_items:
		if String(it["name"]).begins_with("Lumber Camp"): up_camp = it
	ok(not up_camp.is_empty() and up_camp.get("off", false) and String(up_camp["note"]).contains("farm level 3"),
			"the Upgrades tab lists the camp, locked until farm level 3 ('%s')" % String(up_camp.get("note", "")))
	ok(not hb.upgrade(cu) and FarmSites.tier(camp) == 1 and not FarmSites.has_site(camp),
			"upgrading too early is refused")
	_stats(0, 0, 0, 70)          # farm level 3 (17.5 points)
	var w1 := Work.mat("wood"); var g1 := int(Save.d["gems"])
	var ucost := FarmSites.upgrade_cost("lumber_camp", 2)
	ok(hb.upgrade(cu) and FarmSites.is_upgrading(camp) and Work.mat("wood") == w1 and int(Save.d["gems"]) == g1,
			"tier 2 starts an upgrade site that will take %s as it goes" % FarmSites.cost_text(ucost))
	ok(hw.has_station("lumber_camp"), "the camp keeps working while it is being upgraded")
	ok(not hb.upgrade(cu), "it can't be upgraded again while the work is going on")
	hb.toggle()
	hw.scan_t = 0.0
	hw.scan()
	await _sim(home, hw, 400.0, func() -> bool: return not FarmSites.has_site(_entry(L, "lumber_camp")))
	camp = _entry(L, "lumber_camp")
	ok(FarmSites.tier(camp) == 2 and not FarmSites.has_site(camp), "Boki finished it: tier 2")
	await main.get_tree().process_frame
	cn = hb.nodes.get(cu)
	ok(is_instance_valid(cn) and cn.get_node_or_null("Tier") != null and cn.get_node_or_null("Tier").find_children("*", "OmniLight3D", true, false).is_empty(),
			"tier 2 shows on the model (plinth and pennant)")
	ok(is_equal_approx(FarmSites.tier_speed(camp), 1.25) and is_equal_approx(FarmSites.speed({"u": cu, "kind": "log"}), 1.25),
			"a tier 2 station works 25% faster")
	_stats(2, 1, 3, 130, 3)      # farm level 5
	_mats(40, 40, 40, 6)
	hb.toggle()
	ok(hb.upgrade(cu) and FarmSites.is_upgrading(camp), "tier 3 starts once the farm is level 5")
	hb.toggle()
	hw.scan_t = 0.0
	hw.scan()
	await _sim(home, hw, 500.0, func() -> bool: return not FarmSites.has_site(_entry(L, "lumber_camp")))
	camp = _entry(L, "lumber_camp")
	await main.get_tree().process_frame
	cn = hb.nodes.get(cu)
	ok(FarmSites.tier(camp) == 3 and is_instance_valid(cn) and not cn.get_node("Tier").find_children("*", "OmniLight3D", true, false).is_empty() and is_equal_approx(FarmSites.tier_speed(camp), 1.5),
			"tier 3: gold trim and corner lanterns, 50% faster")
	ok(FarmSites.upgrade_cost("lumber_camp", 4).is_empty() and not hb.upgrade(cu), "there is no tier 4")
	hb.toggle()
	hb.pick_up_at(HomeLayout.deco_cells(camp)[0])
	hb.store_held()
	ok(not _entry(L, "lumber_camp").is_empty() and int(L["inv"].get("lumber_camp", 0)) == 0,
			"a tier 3 building can't be put in storage (it would lose its upgrades)")
	hb._drop_held()
	hb.toggle()
	# ---------------------------------------------------------------- 6. save and load
	_stats(0, 0, 0, 70)
	_mats(30, 30, 30, 6)
	hb.toggle()
	hb.take("storage_chest")
	var sc := _spot(hb, home.spots["house"] + Vector3(5, 0, 6))
	ok(_put(hb, sc), "a Storage Chest site goes down")
	hb.toggle()
	var chest := _entry(L, "storage_chest")
	FarmSites.add_swing(chest)
	var need := int(chest["site"]["need"])
	var js := JSON.stringify(Save.d)
	home.queue_free()
	await main.get_tree().process_frame
	Save.d = JSON.parse_string(js)
	var home2 = await main._hb_home()
	var L2: Dictionary = HomeLayout.of(Save.d)
	var chest2 := _entry(L2, "storage_chest")
	var camp2 := _entry(L2, "lumber_camp")
	ok(FarmSites.is_site(chest2) and int(chest2["site"]["got"]) == 1 and int(chest2["site"]["need"]) == need and typeof(chest2["site"]["got"]) == TYPE_INT,
			"after a save and load the site is where it was with its progress (1 of %d)" % need)
	ok(FarmSites.tier(camp2) == 3 and typeof(camp2["t"]) == TYPE_INT and int(L2.get("fb", 0)) == 1,
			"the tier 3 camp and the building-pass flag come back")
	var n2: Node3D = home2.hb.nodes.get(int(chest2["u"]))
	ok(is_instance_valid(n2) and n2.get_node_or_null("Bar") != null and is_instance_valid(home2.hb.nodes.get(int(camp2["u"]))) and home2.hb.nodes[int(camp2["u"])].get_node_or_null("Tier") != null,
			"both come back drawn: scaffold with its bar, and the tier 3 look")
	# a finished build carries on
	home2.hw.scan_t = 0.0
	home2.hw.scan()
	await _sim(home2, home2.hw, 500.0, func() -> bool: return not FarmSites.has_site(_entry(L2, "storage_chest")))
	chest2 = _entry(L2, "storage_chest")
	ok(not FarmSites.has_site(chest2) and home2.hw.has_station("storage_chest") and Progress.stat("fb_built") >= 2,
			"the loaded site gets finished by Boki")
	var js2 := JSON.stringify(Save.d)
	home2.queue_free()
	await main.get_tree().process_frame
	Save.d = JSON.parse_string(js2)
	var home3 = await main._hb_home()
	ok(not FarmSites.has_site(_entry(HomeLayout.of(Save.d), "storage_chest")) and home3.hw.has_station("storage_chest") and FarmSites.tier(_entry(HomeLayout.of(Save.d), "lumber_camp")) == 3,
			"and the finished build is saved as a building")
	home3.queue_free()
	await main.get_tree().process_frame
	# an old save: a layout with a station and none of the new fields
	var od := Save.fresh()
	var ok2 := Save.new_kin("puddlet", "Drip"); od["roster"].append(ok2); od["active"] = ok2["uid"]
	od["tutorial"] = {"home": true, "day1_done": true}
	od["feeder_given"] = true
	od.erase("layout")
	Save.d = JSON.parse_string(JSON.stringify(od))
	var ol := HomeLayout.ensure(Save.d)
	(ol["deco"] as Array).append({"u": HomeLayout._next_uid(ol), "id": "workbench", "x": 50, "z": 40, "r": 0})
	Save.d = JSON.parse_string(JSON.stringify(Save.d))
	var home4 = await main._hb_home()
	var wb := _entry(HomeLayout.of(Save.d), "workbench")
	ok(not FarmUnlocks.gated() and not wb.is_empty() and not FarmSites.has_site(wb) and FarmSites.tier(wb) == 1 and home4.hw.has_station("workbench") and FarmUnlocks.open("cold_store"),
			"an old save keeps its workbench as a plain tier 1 station and everything open")
	var old_cost: Dictionary = home4.hb._site_cost("kiln")
	ok(old_cost.is_empty(), "and its new buildings still go up at once")
	home4.queue_free()
	await main.get_tree().process_frame
	print("FARMBUILD DONE, failures: %d" % bad)
	main.get_tree().quit()
