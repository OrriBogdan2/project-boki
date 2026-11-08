extends RefCounted
## --farm-start-check: a new save's farm start. A brand new save gets a farm-start island (nearly
## empty, gems for a house and the essentials, the first trough in storage); you place the house,
## crop patch and pot yourself (a ghost that tints green or red, turning, one house only); every
## seed gives its own island with about the same room; chopping and mining with tools from the
## market (wood and stone, things grow back, cliffs stay); wood and stone paying for buildings;
## assigned Boki working stations in session and while you're away (capped); crouching on the
## farm; and old saves keeping the farm they had. Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FARMSTART %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _home():
	return await main._hb_home()

func _free(hm) -> void:
	hm.queue_free()
	await main.get_tree().process_frame

## A brand new save as the hatch leaves it: one Boki, the home tutorial not seen yet.
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

## The nearest spot to p where the held item fits ([] if none).
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

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	var t0 := Time.get_ticks_msec()
	# ---------------------------------------------------------------- 1. a new save starts nearly empty
	Save.d = _new_save()
	var home = await _home()
	var hb: HomeBuild = home.hb
	var L: Dictionary = HomeLayout.of(Save.d)
	ok(HomeLayout.fs(Save.d) and int(L["seed"]) > 0 and float(L.get("sk", 0.0)) > 0.0, "a brand new save gets a farm-start island of its own (seed %d, scale %.3f)" % [int(L["seed"]), float(L.get("sk", 0.0))])
	var only_stall := (L["deco"] as Array).size() == 1 and String(L["deco"][0]["id"]) == "market_stall"
	ok(only_stall and home.plots.is_empty() and home.spots["house"].x < -100.0 and home.spots["pot"].x < -100.0,
		"no house, plots, pot or decorations yet: the island starts empty but for its market stall")
	var lots_out := 0
	for b in Data.BUILDINGS:
		if String(Data.BUILDINGS[b]["isle"]) == "main" and HomeLayout.placed(b, Save.d): lots_out += 1
	ok(lots_out == 0 and Econ.feeders().is_empty() and int(Save.d["feeder_inv"].get("trough", 0)) == 1, "no building lots on the meadow, and the first trough waits in storage to be set down")
	var ess := int(HomeLayout.CATALOG["house"]["gems"]) + int(HomeLayout.CATALOG["crop_patch"]["gems"]) + int(HomeLayout.CATALOG["cook_pot"]["gems"])
	ok(int(Save.d["gems"]) == HomeLayout.FS_GEMS and ess <= HomeLayout.FS_GEMS and HomeLayout.FS_GEMS - ess < 90,
		"%d gems to start: a house, a crop patch and a pot cost %d, with a little to spare" % [int(Save.d["gems"]), ess])
	var w: World = home.world
	var ground := 0; var placed_n := 0
	for i in w.kind.size():
		if w.island[i] == 0 and w.kind[i] == World.T_GROUND: ground += 1
		if w.island[i] == 0 and hb.occ.has(i) and String(hb.occ[i]) != "w": placed_n += 1
	var kinds := {}
	for i in hb.wild_t: kinds[hb.wild_t[i]] = int(kinds.get(hb.wild_t[i], 0)) + 1
	var stall_tiles := HomeLayout.size_of("market_stall", 0).x * HomeLayout.size_of("market_stall", 0).y
	ok(placed_n == stall_tiles and ground > 900, "%d tiles of open meadow and only the stall on it (wild: %s)" % [ground, str(kinds)])
	var wd0 := World.new()
	HomeLayout.make_world(wd0, 0, int(L["seed"]), float(L["sk"]))
	var raw := HomeLayout.wild_fs(wd0, int(L["seed"]), float(L["sk"]), {})
	var rk := {}
	for i in raw: rk[raw[i]] = int(rk.get(raw[i], 0)) + 1
	var pk: Array = HomeLayout.fs_plan(int(L["seed"]), float(L["sk"])).map(func(f): return "%s:%d" % [f["kind"], (f["tiles"] as Array).size()])
	print("FARMSTART  plan %s, generated %s, standing %s" % [str(pk), str(rk), str(kinds)])
	wd0.free()
	var v := hb.validate()
	ok(bool(v["ok"]) and int(v["reached"]) == int(v["open"]), "every bit of open ground can be walked to from the landing (%d of %d), nothing the island needs is cut off" % [int(v["reached"]), int(v["open"])])
	# ---------------------------------------------------------------- 2. placing: ghost, tint, turning, one house
	hb.toggle()
	hb.cat = "Buildings"; hb._build_bar()
	var items: Array = hb._tab_items()
	ok(items.any(func(it): return String(it["name"]).begins_with("House")) and items.any(func(it): return String(it["name"]).begins_with("Crop patch")), "build mode's Buildings tab offers the house and the essentials")
	Work.add_mat("wood", 3)      # the house costs a little wood
	hb.take("house")
	ok(hb.held.get("id", "") == "house" and is_instance_valid(hb.ghost), "taking the house holds a ghost of it")
	var land := HomeLayout.LANDING
	hb.cells = HomeLayout.cells_of([int(land.x) - 2, int(land.z) - 1, int(land.x) + 2, int(land.z) + 1]); hb._check_cells(); hb._draw_cells()
	var red := false
	for mi in hb.ghost_cells.get_children():
		if mi is MeshInstance3D and ((mi as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.r > 0.9: red = true
	ok(not hb.ghost_ok and red and hb.why != "", "on the landing by the portal it tints red: %s" % hb.why)
	hb.rotate_held()
	ok(int(hb.held["r"]) == 1 and HomeLayout.size_of("house", 1) == Vector2i(3, 5), "R turns it a quarter (5x3 becomes 3x5)")
	hb.rotate_held(); hb.rotate_held(); hb.rotate_held()
	var hc := _spot(hb, land + Vector3(0, 0, -8))
	hb.cells = hc; hb._check_cells(); hb._draw_cells()
	var green := hc.size() == 15 and hb.ghost_ok
	for mi in hb.ghost_cells.get_children():
		if mi is MeshInstance3D and ((mi as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.g < 0.9: green = false
	ok(green, "on open meadow it tints green")
	var g0 := int(Save.d["gems"])
	ok(hb.place_held() and int(Save.d["gems"]) == g0 and FarmSites.is_site(HomeLayout.of(Save.d)["deco"][-1]),
		"the house goes down where you chose as a free construction site")
	var house_site: Dictionary = HomeLayout.of(Save.d)["deco"][-1]
	var house_cost := FarmSites.build_cost("house")
	Work.add_mat("wood", int(house_cost["wood"]))
	Work.add_mat("stone", int(house_cost["stone"]))
	for i in 100:
		if not FarmSites.has_site(house_site):
			break
		FarmSites.add_swing(house_site)
	Save.d["mats"] = {}
	hb.apply(false)
	home._sync_fixtures()
	ok(home.spots["house"].x > 0.0 and home.spots["house"].distance_to(HomeLayout.rect_center([hc[0].x, hc[0].y, hc[14].x, hc[14].y])) < 0.6 and is_instance_valid(home.house_node), "the farm knows where its house is now (%s)" % str(home.spots["house"]))
	var dp: Vector3 = home._house_door()
	ok(not w.is_block(dp.x, dp.z) and not w.is_void(dp.x, dp.z), "its door step is open ground (%s)" % str(dp))
	hb.take("house")
	ok(hb.held.is_empty(), "a second house is refused")
	hb.take("crop_patch")
	var pc := _spot(hb, home.spots["house"] + Vector3(7, 0, 2))
	ok(pc.size() == 20 and _put(hb, pc) and home.plots.size() == 4, "a crop patch goes down and its four plots are out (%d)" % home.plots.size())
	hb.take("cook_pot")
	var pp := _spot(hb, home.spots["house"] + Vector3(4, 0, 3))
	ok(_put(hb, pp) and home.spots["pot"].x > 0.0, "the cooking pot goes down beside it")
	var v2 := hb.validate()
	ok(bool(v2["ok"]), "the house door, the plots, the pot and the portal can all be walked to (%d places missed; %d of %d open reached)" % [(v2["missing"] as Array).size(), int(v2["reached"]), int(v2["open"])])
	var house_gems := int(HomeLayout.CATALOG["house"]["gems"])
	ok(int(Save.d["gems"]) == HomeLayout.FS_GEMS - ess + house_gems, "%d gems left after the patch and the pot (the house is free)" % int(Save.d["gems"]))
	# the house can be picked up and moved again
	var he: Dictionary = HomeLayout.fixtures(Save.d, "house")[0]
	hb.pick_up_at(Vector2i(int(he["x"]) + 1, int(he["z"]) + 1))
	ok(hb.held.get("id", "") == "house" and int(hb.held.get("from", -1)) == int(he["u"]), "clicking the house picks it up to move")
	hb._drop_held()
	# ---------------------------------------------------------------- 3. wood and stone pay for buildings
	Save.d["gems"] = 2000
	Save.d["mats"] = {"wood": 0, "stone": 0}
	# (the building pass's unlocks and construction sites have their own check, --farmbuild-check; this one covers the
	# instant, ungated placement older farms keep, so the pass is switched off for the rest of it)
	L.erase("fb")
	hb.take("nesting_nook")
	ok(hb.held.is_empty(), "the Nesting Nook needs wood: with none, it can't be picked up")
	Save.d["mats"] = {"wood": 20, "stone": 20}
	hb.take("nesting_nook")
	var nc := _spot(hb, home.spots["house"] + Vector3(-7, 0, 3))
	ok(_put(hb, nc) and Work.mat("wood") == 12 and home.NEST_AT.x > 0.0, "with wood it goes down and takes its 8 wood (Nook at %s)" % str(home.NEST_AT))
	hb.toggle()
	# ---------------------------------------------------------------- 4. chopping and mining
	var hg: HomeGather = home.hg
	home._close_panel()      # the welcome
	ok(HomeGather.has_tool("axe") and HomeGather.has_tool("pickaxe")
			and HomeGather.shop_goods().all(func(g): return int(g[3]) < 0 and String(g[6]) == "yours"),
			"a new farm starts with the axe and the pickaxe, and the market lists them as yours, not for sale")
	Save.d["tools"] = []      # (from here: a save from before, with no tools)
	Save.d["mats"] = {"wood": 0, "stone": 0}
	var ti: int = hg.nearest_wild(home.spots["house"], "tree")
	ok(ti >= 0, "there are wild trees to chop")
	var st: Vector3 = hg.beside(ti, home.spots["house"])
	if st == Vector3.INF:
		for i in hb.wild_t:
			if hb.wild_t[i] == "tree" and hg.beside(i, home.spots["house"]) != Vector3.INF: ti = i; st = hg.beside(i, home.spots["house"]); break
	# (a boulder standing next to the chosen tree is the nearer thing from some spots, on some random seeds:
	# take a tree whose spot resolves to the tree itself)
	if hg.find(Vector2(st.x, st.z)).get("i", -1) != ti:
		for i in hb.wild_t:
			var bs: Vector3 = hg.beside(i, home.spots["house"])
			if hb.wild_t[i] == "tree" and bs != Vector3.INF and hg.find(Vector2(bs.x, bs.z)).get("i", -1) == i:
				ti = i; st = bs; break
	home.ppos = st; home.player.position = st
	var it: Dictionary = hg.find(Vector2(st.x, st.z))
	ok(not it.is_empty() and it["kind"] == "wild" and hg.label(it).begins_with("Needs an axe"), "next to a tree the prompt says you need an axe (%s)" % (hg.label(it) if not it.is_empty() else "nothing"))
	hg.use(it)
	ok(not hg.busy(), "without one, nothing happens")
	var goods: Array = HomeGather.shop_goods()
	ok(goods.size() == 2 and int(goods[0][3]) > 0, "the market sells an axe (%d gems) and a pickaxe (%d gems)" % [int(goods[0][3]), int(goods[1][3])])
	(goods[0][5] as Callable).call()
	(goods[1][5] as Callable).call()
	ok(HomeGather.has_tool("axe") and HomeGather.has_tool("pickaxe"), "bought, they're yours")
	it = hg.find(Vector2(st.x, st.z))
	ok(hg.label(it) == "Chop the tree", "now the prompt says: %s" % hg.label(it))
	hg.use(it)
	home.tw.test_hold = true
	for i in 120:
		if not hg.busy(): break
		hg.tick(0.05)
	home.tw.test_hold = false
	ok(not hb.wild_t.has(ti) and Work.mat("wood") >= 3, "holding the key, three hits and it's down: %d wood" % Work.mat("wood"))
	var key := HomeLayout.key(ti % w.w, ti / w.w)
	var rg: Dictionary = HomeLayout.of(Save.d)["regrow"]
	ok(rg.has(key) and float(rg[key]["t"]) - Time.get_unix_time_from_system() > 600.0, "it grows back in %.0f minutes" % ((float(rg.get(key, {}).get("t", 0)) - Time.get_unix_time_from_system()) / 60.0))
	var ri := -1
	var rs := Vector3.INF
	for i in hb.wild_t:
		if hb.wild_t[i] != "rock": continue
		var b0: Vector3 = hg.beside(i, home.spots["house"])
		if b0 != Vector3.INF and (ri < 0 or b0.distance_to(home.spots["house"]) < rs.distance_to(home.spots["house"])): ri = i; rs = b0
	if ri >= 0:
		home.ppos = rs; home.player.position = rs
		hg.use(hg.find(Vector2(rs.x, rs.z)))
		home.tw.test_hold = true
		for i in 120:
			if not hg.busy(): break
			hg.tick(0.05)
		home.tw.test_hold = false
	ok(ri >= 0 and Work.mat("stone") >= 3, "a pickaxe mines a boulder for %d stone" % Work.mat("stone"))
	home.ppos = HomeLayout.LANDING; home.player.position = home.ppos
	for k in home.kins: k["pos"] = HomeLayout.LANDING
	var n_back: int = hb.regrow_due(Time.get_unix_time_from_system() + 4000.0)
	ok(n_back >= 1 and hb.wild_t.has(ti) and w.is_block(ti % w.w + 0.5, ti / w.w + 0.5), "later, the tree grows back where it stood (%d came back)" % n_back)
	# the Training Grounds isle is gone: no island of its own, and the Esc menu opens the training area instead
	ok(home.world.island_id(40.0, 56.0) != "training", "the farm has no Training Grounds isle")
	var was: Node = main.get("current")
	main.set("current", home)
	Overlay.open_pause("home")
	await main.get_tree().process_frame
	var btns: Array = Overlay.host.find_children("*", "Button", true, false)
	ok(btns.any(func(b): return (b as Button).text.contains("Training area")), "the farm's Esc menu has Training area")
	Overlay.close()
	main.set("current", was)
	var cl := -1
	for i in hb.wild_t:
		if hb.wild_t[i] == "cliff": cl = i; break
	if cl >= 0:
		ok(not hb.clear_wild(Vector2i(cl % w.w, cl / w.w)) and w.level[cl] > 0, "cliffs can't be chopped or mined (raised rock, level %d)" % w.level[cl])
	else:
		print("FARMSTART  (this island has no cliff)")
	# ---------------------------------------------------------------- 5. Boki at work stations
	var rocky := Save.new_kin("pebbit", "Rocky"); rocky["level"] = 5
	var moss := Save.new_kin("burrlet", "Moss"); moss["level"] = 5
	var ash := Save.new_kin("cindle", "Ash"); ash["level"] = 5
	for r in [rocky, moss, ash]:
		Care.ensure(r)
		for nd in Care.NEEDS: r["needs"][nd] = 100.0
		Save.d["roster"].append(r)
	await _free(home)
	home = await _home()
	hb = home.hb; hg = home.hg; w = home.world
	var hw: HomeWork = home.hw
	var tree2: int = hg.nearest_wild(home.spots["house"], "tree")
	var camp: Dictionary = hg.demo_place("lumber_camp", Vector3(tree2 % w.w + 0.5, 0, tree2 / w.w + 0.5), 0, 2.0)
	var garden: Dictionary = hg.demo_place("seed_garden", home.spots["house"] + Vector3(-4, 0, 6), 0)
	var kiln: Dictionary = hg.demo_place("kiln", home.spots["house"] + Vector3(4, 0, 6), 0)
	ok(not camp.is_empty() and not garden.is_empty() and not kiln.is_empty(), "a Lumber Camp by the trees, a Seed Garden and a Kiln go down")
	ok(Work.assign_why(rocky, "lumber_camp") == "" and Work.assign_why(moss, "lumber_camp") != "" and Work.assign_why(moss, "seed_garden") == "" and Work.assign_why(ash, "kiln") == "",
		"only Boki with the knack can be assigned (Rocky: Timber, Moss: Bloom, Ash: Ember)")
	Work.assign(rocky, int(camp["u"])); Work.assign(moss, int(garden["u"]))
	hw.scan()
	var kr: Dictionary = home._kin_entry(rocky)
	print("FARMSTART  Rocky is on island %d, the camp on %d" % [w.island_of(kr["pos"].x, kr["pos"].z), w.island_of(HomeLayout.deco_center(camp).x, HomeLayout.deco_center(camp).z)])
	var ka: Dictionary = home._kin_entry(ash)
	var jr: Dictionary = hw.best_job(kr)
	ok(not jr.is_empty() and int(jr.get("u", -1)) == int(camp["u"]), "Rocky, assigned to the camp, takes its job (%s)" % String(jr.get("kind", "none")))
	ok(hw.best_job(ka).is_empty() or String(hw.best_job(ka).get("kind", "")) != "fire", "nobody unassigned fires the Kiln")
	# a few minutes of the farm at work
	Save.d["mats"] = {"wood": 0, "stone": 0}
	var seeds0 := 0
	for sd in Save.d["seeds"]: seeds0 += int(Save.d["seeds"][sd])
	for k in home.kins: k["t"] = 0.0
	for i in 2400:
		home._process(0.05)
	var seeds1 := 0
	for sd in Save.d["seeds"]: seeds1 += int(Save.d["seeds"][sd])
	var piles := 0
	for p in Work.ensure()["piles"]: piles += int(p.get("n", 0))
	ok(Work.mat("wood") + piles > 0, "in two minutes at home Rocky made %d wood (%d on piles)" % [Work.mat("wood") + piles, piles])
	ok(seeds1 > seeds0, "and Moss raised a seedling at the Seed Garden (%d seeds, was %d)" % [seeds1, seeds0])
	# away on an expedition: assigned Boki keep working, capped
	Work.assign(ash, int(kiln["u"]))
	Save.d["mats"] = {"wood": 30, "stone": 0}
	var coals0 := int(Save.d["items"].get("coals", 0))
	var now := Time.get_unix_time_from_system()
	Work.ensure()["seen"] = now - 3600.0
	var lines := Work.catch_up(now)
	ok(lines.size() == 3, "an hour away: %s" % " | ".join(lines))
	ok(Work.mat("wood") >= 30 - 12 and int(Save.d["items"].get("coals", 0)) > coals0 and int(Save.d["items"].get("coals", 0)) - coals0 <= int(Work.ASSIGN["kiln"]["cap"]), "the Kiln burned wood into %d Ember Coals" % (int(Save.d["items"].get("coals", 0)) - coals0))
	Save.d["mats"] = {"wood": 0, "stone": 0}
	Work.assign(ash, -1)
	Work.ensure()["seen"] = now - 86400.0 * 3
	Work.catch_up(now)
	ok(Work.mat("wood") == int(Work.ASSIGN["lumber_camp"]["cap"]), "three days away still only fills the cap (%d wood)" % Work.mat("wood"))
	ok(Work.catch_up(now + 5.0).is_empty(), "coming straight back isn't time away")
	KinBox.ensure()
	rocky["boxed"] = true
	Save.d["mats"] = {"wood": 0, "stone": 0}
	Work.ensure()["seen"] = now - 3600.0
	Work.catch_up(now)
	ok(Work.mat("wood") == 0, "a Boki asleep in the Burrow makes nothing")
	rocky.erase("boxed")
	# the station's panel
	hw.open_station(camp)
	ok(home.panel_open != "", "walking up to the Lumber Camp opens its panel (who's assigned)")
	home._close_panel()
	# ---------------------------------------------------------------- 6. crouching on the farm
	home.ppos = HomeLayout.LANDING + Vector3(-6, 0, -3); home.py = 0.0; home.pvy = 0.0
	home.set_meta("crouch_test", true)
	Input.action_press("right")
	var x0: float = home.ppos.x
	for i in 20: home._move_player(0.05)
	var vc: float = home.ppos.x - x0
	var ck: float = home.p_crouch_k
	home.remove_meta("crouch_test")
	var x1: float = home.ppos.x
	for i in 20: home._move_player(0.05)
	var vs: float = home.ppos.x - x1
	Input.action_release("right")
	ok(vc > 0.5 and vc < vs * 0.75 and ck > 0.5, "crouching works on the farm: %.2f m/s crouched (pose %.2f) against %.2f standing" % [vc, ck, vs])
	# ---------------------------------------------------------------- 7. a farm-start save keeps it all
	var js := JSON.stringify(Save.d)
	await _free(home)
	Save.d = JSON.parse_string(js)
	home = await _home()
	ok(home.fs and home.spots["house"].x > 0.0 and home.plots.size() == 4 and home.NEST_AT.x > 0.0 and Work.crew(int(camp["u"])).size() == 1,
		"saved and loaded: the house, the plots, the Nook and Rocky's job are all still there (fs %s, house %s, plots %d, nook %s, crew %d)" % [home.fs, str(home.spots["house"]), home.plots.size(), str(home.NEST_AT), Work.crew(int(camp["u"])).size()])
	await _free(home)
	# ---------------------------------------------------------------- 8. distinct islands, the same room
	var sizes: Array = []
	var sigs: Array = []
	var feats: Array = []
	var usable: Array = []
	for sd in [11, 222, 3333, 44444, 555555]:
		var sk := HomeLayout.fs_scale(sd)
		var wd := World.new()
		HomeLayout.make_world(wd, 0, sd, sk)
		var n := 0
		var sig := {}
		for i in wd.kind.size():
			if wd.island[i] == 0 and wd.kind[i] == World.T_GROUND: n += 1; sig[i] = true
		var wt := HomeLayout.wild_fs(wd, sd, sk, {})
		var perm := 0
		for i in wt:
			if wt[i] in ["water", "cliff"]: perm += 1
		sizes.append(n)
		usable.append(n - perm)
		sigs.append(sig)
		var fk: Array = HomeLayout.fs_plan(sd, sk).map(func(f): return String(f["kind"]))
		fk.sort()
		feats.append(",".join(fk))
		wd.free()
	var lo: int = sizes.min(); var hi: int = sizes.max()
	ok(float(hi - lo) / float(HomeLayout.FS_LAND) < 0.08, "five seeds, about the same land: %s (target %d)" % [str(sizes), HomeLayout.FS_LAND])
	ok(float(int(usable.max()) - int(usable.min())) / float(HomeLayout.FS_LAND) < 0.1, "and about the same usable room once ponds and cliffs are out: %s" % str(usable))
	var min_diff := 1.0
	for a in sigs.size():
		for b in range(a + 1, sigs.size()):
			var diff := 0
			for i in sigs[a]:
				if not sigs[b].has(i): diff += 1
			min_diff = minf(min_diff, float(diff) / float(sigs[a].size()))
	ok(min_diff > 0.08, "each island's outline is its own (at least %d%% of tiles differ between any two)" % int(min_diff * 100))
	var uniq := {}
	for f in feats: uniq[f] = true
	ok(uniq.size() >= 3, "and its features differ: %s" % " / ".join(feats))
	# ---------------------------------------------------------------- 8b. bridges to the isles (feelfix)
	# on every seed each isle's bridge spans the real gap: it starts on the isle's edge and ends on the
	# main island's edge, both ends at ground level, all of it open sky in between, and its sign
	# (where you build it) stands on open main-island ground within reach of the bridge's foot
	var bseeds := 0; var bbad: Array = []
	for n in 50:
		var sd := 1000 + n * 7919
		var sk := HomeLayout.fs_scale(sd)
		var wd := World.new()
		HomeLayout.make_world(wd, 0, sd, sk)
		var wt := HomeLayout.wild_fs(wd, sd, sk, {})
		var seed_ok := true
		for k in Data.ISLES:
			var sp: Dictionary = HomeLayout.isle_bridge(wd, k)
			var rc: Array = sp["rect"]
			var why := ""
			if rc == Data.ISLES[k]["bridge"] and not (sp["sign"] as Vector2).is_equal_approx(Data.ISLES[k]["sign"]): why = "odd"
			var horiz: bool = rc[2] - rc[0] > rc[3] - rc[1]
			var tiles: Array = wd.bridge_tiles(rc)
			# (a ragged edge can leave a tile of either island's land in the strip: fine at ground level)
			for z in range(rc[1], rc[3] + 1):
				for x in range(rc[0], rc[2] + 1):
					if wd.kind[wd.idx(x, z)] != World.T_VOID and (not wd.island_id(x + 0.5, z + 0.5) in ["main", k] or absf(wd.ground_at(x + 0.5, z + 0.5)) > 0.3):
						why = "something else in the way at %d,%d" % [x, z]
			if tiles.size() < 2: why = "no sky to span"
			var ends := {}
			for b in range(rc[1] if horiz else rc[0], (rc[3] if horiz else rc[2]) + 1):
				for a in [(rc[0] if horiz else rc[1]) - 1, (rc[2] if horiz else rc[3]) + 1]:
					var x: int = a if horiz else b; var z: int = b if horiz else a
					var i := wd.idx(x, z)
					if wd.kind[i] == World.T_VOID: why = "an end hangs over the sky at %d,%d" % [x, z]
					elif absf(wd.ground_at(x + 0.5, z + 0.5)) > 0.3: why = "an end is off ground level (%.2f) at %d,%d" % [wd.ground_at(x + 0.5, z + 0.5), x, z]
					elif wt.get(i, "") in ["water", "cliff"]: why = "an end lands in %s" % wt[i]
					else: ends[wd.island_id(x + 0.5, z + 0.5)] = true
			if not (ends.has("main") and ends.has(k)): why = "doesn't join main and %s: %s" % [k, str(ends.keys())]
			var sg: Vector2 = sp["sign"]
			var si := wd.idx(int(floor(sg.x)), int(floor(sg.y)))
			if wd.island[si] != 0 or wd.kind[si] != World.T_GROUND or wt.get(si, "") in ["water", "cliff"]: why = "the sign isn't on open main ground (%s, island %d, kind %d, wild %s)" % [str(sg), wd.island[si], wd.kind[si], wt.get(si, "")]
			# the bridge's main-side foot: within reach of the sign
			var foot := Vector2.INF
			for b in range(rc[1] if horiz else rc[0], (rc[3] if horiz else rc[2]) + 1):
				for a in [(rc[0] if horiz else rc[1]) - 1, (rc[2] if horiz else rc[3]) + 1]:
					var x: int = a if horiz else b; var z: int = b if horiz else a
					if wd.island_id(x + 0.5, z + 0.5) == "main": foot = Vector2(x + 0.5, z + 0.5)
			if foot == Vector2.INF or foot.distance_to(sg) > 2.3: why = "the sign is %.1f from the bridge's foot" % (foot.distance_to(sg) if foot != Vector2.INF else 99.0)
			if why != "":
				seed_ok = false
				if bbad.size() < 6: bbad.append("seed %d %s: %s" % [sd, k, why])
		if seed_ok: bseeds += 1
		wd.free()
	ok(bseeds == 50, "50 seeds: every isle's bridge spans the gap edge to edge at ground level with its sign in reach (%d of 50) %s" % [bseeds, "; ".join(bbad)])
	# ---------------------------------------------------------------- 9. old saves keep their farm
	var od := Save.fresh()
	var ok2 := Save.new_kin("puddlet", "Drip"); od["roster"].append(ok2); od["active"] = ok2["uid"]
	od["tutorial"] = {"home": true, "day1_done": true}
	od["matches"] = 12
	od["gems"] = 77
	od.erase("layout")
	Save.d = JSON.parse_string(JSON.stringify(od))
	home = await _home()
	ok(not home.fs and int(Save.d["gems"]) == 77 and home.spots["house"].distance_to(Vector3(38, 0, 26.5)) < 0.01 and home.plots.size() == 4 and (Save.d["layout"]["deco"] as Array).size() == HomeLayout.STOCK.size(),
		"an old save without a layout keeps the classic farm (house, four plots, the lamps and flower beds) and its gems")
	await _free(home)
	var pd := Save.fresh()
	pd["roster"].append(Save.new_kin("cindle", "Ember")); pd["active"] = pd["roster"][0]["uid"]
	pd["tutorial"] = {"home": true, "day1_done": true}
	var pl := HomeLayout.fresh(); pl.erase("fs"); pl.erase("regrow"); pl["seed"] = 12345; pl["made"] = true
	pd["layout"] = pl
	Save.d = JSON.parse_string(JSON.stringify(pd))
	home = await _home()
	print("FARMSTART  procedural wild: %d raw" % HomeLayout.wild(home.world, 12345, {}).size())
	ok(not home.fs and home.spots["house"].x > 0.0 and home.hb.wild_t.size() > 0 and int(Save.d["layout"]["fs"]) == 0, "a procedural home from before keeps its fixed farm and its wild (%d wild tiles)" % home.hb.wild_t.size())
	await _free(home)
	print("FARMSTART DONE, failures: %d (%.1f s)" % [bad, (Time.get_ticks_msec() - t0) / 1000.0])
	main.get_tree().quit()
