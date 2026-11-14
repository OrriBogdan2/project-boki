extends RefCounted
## --home-build-check, moved out of main.gd (AGENTS.md section 2); registered in tools/check_registry.gd.

var main: Node

## Headless check for build mode at home: the island is bigger, things place, turn, move and go into
## storage, bad spots are refused (overlaps, the void, cutting off a door), the layout survives a save
## and reload, an old save without a layout migrates, kin walk round a fence, and expanding adds land.
func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var bad := [0]
	var ok := func(cond: bool, what: String) -> void:
		print("HOMEBUILD %s %s" % ["ok  " if cond else "FAIL", what])
		if not cond: bad[0] += 1
	var t0 := HomeLayout.main_tiles(0)
	var t1 := HomeLayout.main_tiles(1)
	ok.call(t0 >= 900, "the main island has %d open tiles (the old one had about 480)" % t0)
	ok.call(t1 > t0 + 100, "one expansion step grows it to %d tiles (+%d)" % [t1, t1 - t0])
	# a save with a few kin and buildings
	Save.d = Save.fresh()
	var pk := Save.new_kin("zapple", "Pip"); Save.d["roster"].append(pk); Save.d["active"] = pk["uid"]
	for sp in ["cindle", "puddlet"]: Save.d["roster"].append(Save.new_kin(sp))
	Save.d["tutorial"]["home"] = true; Save.d["tutorial"]["day1_done"] = true
	Save.d["gems"] = 5000; Save.d["scrap"] = 100
	Save.d["buildings"].append_array(["workshop", "board", "ransom"])
	Econ.ensure()
	var home = await _hb_home()
	var hb: HomeBuild = home.hb
	ok.call(hb != null and (HomeLayout.of(Save.d)["deco"] as Array).size() == HomeLayout.STOCK.size(), "a new save's layout starts with the farm's lamps and flower beds as decorations")
	hb.toggle()
	ok.call(hb.active and is_instance_valid(hb.bar), "build mode opens with its catalog bar")
	var spot := func(item: Dictionary, sz := Vector2i(1, 1)) -> Vector2i:
		for z in range(34, 46):
			for x in range(52, 62):
				var cs := HomeLayout.cells_of([x, z, x + sz.x - 1, z + sz.y - 1])
				if hb.fits(item, cs): return Vector2i(x, z)
		return Vector2i(-1, -1)
	var put := func(cs: Array) -> bool:
		hb.cells = cs; hb._check_cells()
		return hb.place_held()
	# place
	var g0 := int(Save.d["gems"])
	var n0 := (HomeLayout.of(Save.d)["deco"] as Array).size()
	hb.take("lantern")
	var lt: Vector2i = spot.call(hb.held)
	ok.call(lt.x >= 0 and put.call([lt]), "a lantern goes down on open meadow at %s" % str(lt))
	ok.call((HomeLayout.of(Save.d)["deco"] as Array).size() == n0 + 1 and int(Save.d["gems"]) == g0 - 15, "it's in the layout and cost 15 gems")
	# refused spots
	hb.take("kin_statue")
	ok.call(not put.call([lt]), "nothing goes on top of the lantern (%s)" % hb.why)
	ok.call(not put.call([Vector2i(1, 1)]), "nothing goes in the sky (%s)" % hb.why)
	ok.call(not put.call([Vector2i(38, 26)]), "nothing goes on the house (%s)" % hb.why)
	# turn
	hb.take("bench")
	hb.rotate_held()
	var bt: Vector2i = spot.call(hb.held, Vector2i(1, 2))
	ok.call(bt.x >= 0 and put.call(HomeLayout.cells_of([bt.x, bt.y, bt.x, bt.y + 1])), "a bench turned a quarter fits a 1x2 footprint")
	var last: Dictionary = (HomeLayout.of(Save.d)["deco"] as Array)[-1]
	ok.call(String(last["id"]) == "bench" and int(last["r"]) == 1 and Vector2i(HomeLayout.size_of("bench", 1)) == Vector2i(1, 2), "the bench is saved turned (r=%d)" % int(last["r"]))
	ok.call(home.world.is_block(bt.x + 0.5, bt.y + 1.5), "the bench blocks walking")
	hb._drop_held()
	# move a building
	var old_rc := HomeLayout.rect_of("workshop", Save.d)
	hb.take_building("workshop")
	hb.rotate_held()
	var ws: Vector2i = spot.call(hb.held, HomeLayout.turned(HomeLayout.base_size("workshop"), int(hb.held["r"])))
	var nrc := HomeLayout.rect_at("workshop", ws.x, ws.y, int(hb.held["r"]))
	ok.call(ws.x >= 0 and put.call(HomeLayout.cells_of(nrc)), "the Workshop picks up, turns and drops at %s" % str(ws))
	ok.call(HomeLayout.rect_of("workshop", Save.d) == nrc and home.world.is_block(nrc[0] + 0.5, nrc[1] + 0.5) and not home.world.is_block(old_rc[0] + 0.5, old_rc[1] + 0.5), "its footprint moved in the world (old lot open again)")
	ok.call(home.lots["workshop"]["door"].distance_to(HomeLayout.door_at("workshop", ws.x, ws.y, 1)) < 0.01 and int(HomeLayout.place_of("workshop", Save.d)["r"]) == 1, "its door turned with it")
	# a ring of fence round its door would shut it in
	var door: Vector3 = home.lots["workshop"]["door"]
	var ring: Array = []
	for z in range(int(door.z) - 2, int(door.z) + 3):
		for x in range(int(door.x) - 2, int(door.x) + 3):
			if absi(x - int(door.x)) == 2 or absi(z - int(door.z)) == 2: ring.append(Vector2i(x, z))
	ok.call(not hb.keeps_paths([], ring), "a fence ring round the Workshop door is refused: it would cut the door off")
	# store and undo
	hb.pick_up_at(lt)
	ok.call(hb.held.get("id", "") == "lantern" and int(hb.held.get("from", -1)) > 0, "clicking the lantern picks it up")
	hb.store_held()
	var lay: Dictionary = HomeLayout.of(Save.d)
	ok.call(int(lay["inv"].get("lantern", 0)) == 1 and not lay["deco"].any(func(e): return String(e["id"]) == "lantern"), "X puts it in storage")
	hb.undo_last()
	lay = HomeLayout.of(Save.d)
	ok.call(lay["deco"].any(func(e): return String(e["id"]) == "lantern") and int(lay["inv"].get("lantern", 0)) == 0, "undo brings it back")
	# paint a path and a pond
	hb.take("path_stone")
	var pt: Vector2i = spot.call({"kind": "deco", "id": "flowers", "from": -1})
	hb.drag = {"from": pt, "tiles": {pt: true, pt + Vector2i(1, 0): true}, "last": pt}
	hb.cells = (hb.drag["tiles"] as Dictionary).keys(); hb._check_cells()
	ok.call(hb.place_held() and String(lay["paths"].get(HomeLayout.key(pt.x, pt.y), "")) == "path_stone" and home.world.paint.has(home.world.idx(pt.x, pt.y)), "a stone path paints two tiles")
	hb.take("water")
	var wt: Vector2i = spot.call({"kind": "deco", "id": "bush", "from": -1})
	hb.drag = {"from": wt, "tiles": {wt: true}, "last": wt}
	hb.cells = [wt]; hb._check_cells()
	ok.call(hb.place_held() and home.water.depth(wt.x + 0.5, wt.y + 0.5) > 0 and not home.world.is_block(wt.x + 0.5, wt.y + 0.5), "a pond tile goes down (water you can wade into, but nothing can be built on it)")
	# kin walk round a fence
	var fx := 56; var fz := 41
	var line: Array = []
	for z in range(fz - 4, fz + 5): line.append(Vector2i(fx, z))
	hb.take("fence")
	hb.drag = {"from": line[0], "tiles": {}, "last": line[0]}
	hb.cells = line; hb._check_cells()
	var placed := hb.place_held()
	hb._drop_held()
	ok.call(placed and home.world.is_block(fx + 0.5, fz + 0.5), "a 9-tile fence line goes down (%s)" % hb.why)
	var kd: Dictionary = home.kins[0]
	for o in home.kins:
		if o != kd: o["busy"] = true
	kd.erase("indoors"); (kd["node"] as Node3D).visible = true
	kd["pos"] = Vector3(fx - 2.5, 0, fz + 0.5); kd["goal"] = Vector3(fx + 3.5, 0, fz + 0.5); kd["t"] = 999.0
	for nk in Care.NEEDS: kd["rec"]["needs"][nk] = 100.0
	var through := false; var reached := false
	for i in 500:
		kd["t"] = 999.0; kd["goal"] = Vector3(fx + 3.5, 0, fz + 0.5)
		home._move_kin(0.05)
		var kp: Vector3 = kd["pos"]
		if int(floor(kp.x)) == fx and absi(int(floor(kp.z)) - fz) <= 4: through = true
		if Vector2(kp.x - fx - 3.5, kp.z - fz - 0.5).length() < 0.6: reached = true; break
	ok.call(reached and not through, "a kin walks round the fence to the far side (reached=%s through=%s)" % [reached, through])
	for o in home.kins: o["busy"] = false
	# buying a feeder goes straight into placing it, and it waits in storage until it's down
	Save.d["feeder_inv"]["basket"] = 1
	home.hecon.start_carry("basket")
	ok.call(hb.active and hb.held.get("kind", "") == "feeder", "buying a feeder opens build mode holding it")
	var nf0 := Econ.feeders().size()
	var fpt := Vector2i(-1, -1)
	for z in range(36, 46):
		for x in range(50, 62):
			if fpt.x < 0 and hb.feeder_fits(Vector2i(x, z), ""): fpt = Vector2i(x, z)
	hb.cells = [fpt]; hb._check_cells()
	ok.call(fpt.x >= 0 and hb.place_held() and Econ.feeders().size() == nf0 + 1 and int(Save.d["feeder_inv"].get("basket", 0)) == 0, "it sets down on a green spot (%s) and leaves storage" % str(fpt))
	hb.pick_up_at(fpt)
	ok.call(hb.held.get("kind", "") == "feeder" and String(hb.held.get("from", "")) != "", "a feeder that's out can be picked up again")
	hb._drop_held()
	# save and reload
	var ws_at: Vector3 = home.lots["workshop"]["at"]
	var deco_n := (HomeLayout.of(Save.d)["deco"] as Array).size()
	var js := JSON.stringify(Save.d)
	home.queue_free()
	await main.get_tree().process_frame
	Save.d = JSON.parse_string(js)
	var home2 = await _hb_home()
	ok.call(home2.lots["workshop"]["at"].distance_to(ws_at) < 0.01 and (HomeLayout.of(Save.d)["deco"] as Array).size() == deco_n and home2.hb.nodes.size() > 0 and home2.world.is_block(fx + 0.5, fz + 0.5), "after a save and reload the Workshop, %d decorations and the fence are where they were" % deco_n)
	ok.call(home2.water.depth(wt.x + 0.5, wt.y + 0.5) > 0 and home2.world.paint.has(home2.world.idx(pt.x, pt.y)), "the pond tile and the path come back too")
	# expanding
	var gl := int(HomeLayout.of(Save.d)["grow"])
	ok.call(home2.hb.expand() and int(HomeLayout.of(Save.d)["grow"]) == gl + 1, "Expand pays and grows the island a step (now %d)" % (gl + 1))
	home2.queue_free()
	await main.get_tree().process_frame
	var home3 = await _hb_home()
	var n3 := 0
	for i in home3.world.kind.size():
		if home3.world.island[i] == 0 and home3.world.kind[i] != World.T_VOID: n3 += 1
	ok.call(n3 > t0 + 100, "the grown island has %d tiles of land" % n3)
	home3.queue_free()
	await main.get_tree().process_frame
	# an old save: no layout, the greenhouse on the Orchard Isle, and a feeder on the old orchard
	var od := Save.fresh()
	var ok2 := Save.new_kin("puddlet", "Drip"); od["roster"].append(ok2); od["active"] = ok2["uid"]
	od["tutorial"] = {"home": true, "day1_done": true}
	od["buildings"] = ["workshop", "greenhouse", "board", "ransom"]
	od["bridges"] = ["orchard"]
	od["feeders"] = [{"id": "f1", "kind": "trough", "x": 61.0, "z": 39.5, "food": [], "auto": true}, {"id": "f2", "kind": "trough", "x": 40.4, "z": 29.4, "food": [], "auto": true}]
	od["feeder_given"] = true
	od.erase("layout")
	Save.d = JSON.parse_string(JSON.stringify(od))
	Econ.ensure()
	var home4 = await _hb_home()
	var f1: Dictionary = Econ.feeders()[0]
	ok.call(typeof(Save.d.get("layout")) == TYPE_DICTIONARY and (Save.d["layout"]["deco"] as Array).size() == HomeLayout.STOCK.size(), "an old save gets a layout (the farm's lamps and flower beds)")
	ok.call(home4.world.island_id(home4.lots["greenhouse"]["at"].x, home4.lots["greenhouse"]["at"].z) == "orchard" and home4.world.is_block(home4.lots["greenhouse"]["at"].x, home4.lots["greenhouse"]["at"].z), "its greenhouse stands on the (moved) Orchard Isle")
	ok.call(not home4.world.is_void(float(f1["x"]), float(f1["z"])), "a feeder left out where there's no land now is moved to open ground (%.1f, %.1f)" % [float(f1["x"]), float(f1["z"])])
	ok.call(home4.lots["workshop"]["at"].distance_to(HomeLayout.rect_center(Data.BUILDINGS["workshop"]["rect"])) < 0.01, "its Workshop stays on its old lot")
	# moving at home: dash, glide, falling off
	var mv: Node = home4
	mv.ppos = Vector3(38.0, 0, 34.5); mv.py = 0.0; mv.pvy = 0.0
	var x0: float = mv.ppos.x
	mv.dash.charges = 2.0
	mv.start_dash(Vector2(1, 0), 23.0, 0.15)
	for i in 6: mv._move_player(0.05)
	ok.call(mv.ppos.x - x0 > 2.0, "a dash at home carries you %.1fm" % (mv.ppos.x - x0))
	mv.py = 1.2; mv.pvy = 0.0; mv.gliding = true
	var y0: float = mv.py
	Input.action_press("jump")
	mv._move_player(0.5)
	Input.action_release("jump")
	ok.call(mv.gliding and y0 - mv.py < 1.5 and y0 - mv.py > 0.3, "gliding sinks slowly (%.2fm in half a second)" % (y0 - mv.py))
	mv.gliding = false
	var safe: Vector3 = mv.safe_at
	mv.ppos = Vector3(2.0, 0, 2.0); mv.py = -0.5; mv.pvy = -5.0
	# (no glider: the jump pressed above still reads as pressed in a headless run, which opens one, and
	# an open glider now lifts you back to the lip over the abyss instead of sinking. A panel open
	# means no keys)
	mv.panel_open = "test"
	for i in 60:
		mv.gliding = false
		mv._move_player(0.05)
	mv.panel_open = ""
	ok.call(mv.ppos.distance_to(safe) < 0.01 and mv.py >= -0.01, "falling off the island puts you back where you last stood")
	Save.d["classes"] = ClassUnlock.legacy()      # an old save: every Hunter open (the locks: --hunter-unlock-check)
	# dashing at home: the match's charges and recharge for each class, then the long dash
	var cls0 := String(Save.d.get("cls", "medium"))
	mv.ppos = Vector3(38.0, 0, 34.5); mv.py = mv._ground_h(38.0, 34.5); mv.pvy = 0.0; mv.gliding = false
	for ck in ["light", "medium", "heavy"]:
		Save.d["cls"] = ck
		var dg: Dictionary = mv._dodge()
		var want := int(Content.class_dodge(ck).charges) if Content.class_dodge(ck) else int(Data.CLASSES[ck]["dashes"])
		mv.ppos = Vector3(38.0, 0, 34.5); mv.py = mv._ground_h(38.0, 34.5); mv.pvy = 0.0; mv.dash_t = 0.0; mv.dash.ex_cd = 0.0
		mv.dash.charges = 9.0; mv._move_player(0.0001)     # topped up to the class's count
		var shorts := 0
		var longs := 0
		for k in want + 2:
			mv.dash_t = 0.0; mv.ppos = Vector3(38.0, 0, 34.5); mv.py = mv._ground_h(38.0, 34.5); mv.pvy = 0.0
			var had: float = mv.dash.charges
			if mv.try_dash(Vector2(1, 0), false):
				if had >= 1.0: shorts += 1
				else: longs += 1
		var regen := float(dg["cd"])
		mv.dash_t = 0.0
		var waited := 0.0
		while mv.dash.charges < 1.0 and waited < 40.0:
			mv.ppos = Vector3(38.0, 0, 34.5); mv.py = mv._ground_h(38.0, 34.5); mv.pvy = 0.0; mv.dash_t = 0.0
			mv._move_player(0.05); waited += 0.05
		mv.dash_t = 0.0
		var again: bool = mv.try_dash(Vector2(1, 0), false)
		ok.call(shorts == want and longs == 1 and absf(waited - regen) < 0.2 and again and absf(float(dg["ex_cd"]) - float(Data.CLASSES[ck]["ex_cd"])) < 0.01,
			"%s dashes at home as in a match: %d short (%d), then the long one (%d), %.1fs to recharge (dodge cooldown %.1fs), then again (%s)" % [ck, shorts, want, longs, waited, regen, again])
	Save.d["cls"] = cls0
	mv.dash_t = 0.0
	home4.queue_free()
	await main.get_tree().process_frame
	# procedural homes: two seeds, two different islands, both usable; the first look round
	var sigs: Array = []
	for sd in [1234567, 7654321]:
		Save.d = Save.fresh()
		var nk := Save.new_kin("zapple", "Pip"); Save.d["roster"].append(nk); Save.d["active"] = nk["uid"]
		Save.d["tutorial"] = {"home": true, "day1_done": true}
		Save.d["layout"] = HomeLayout.fresh()
		Save.d["layout"]["seed"] = sd; Save.d["layout"]["made"] = false
		HomeLayout.ensure(Save.d)
		Econ.ensure()
		var hp = await _hb_home()
		var vr: Dictionary = hp.hb.validate()
		ok.call(vr["ok"], "seed %d: %d open tiles, all %d reachable, %d places missed, %d wild tiles" % [sd, vr["open"], vr["reached"], (vr["missing"] as Array).size(), hp.hb.wild_t.size()])
		var sg := ""
		for i in hp.world.kind.size(): sg += str(hp.world.kind[i])
		sigs.append(sg)
		ok.call(hp.hb.needs_making(), "a new home asks where things go first")
		var sug: Dictionary = hp.hb.make if not hp.hb.make.is_empty() else hp.hb.suggest()
		hp.hb.use_suggested()
		var ws2: Dictionary = HomeLayout.place_of("workshop", Save.d)
		ok.call(not hp.hb.needs_making() and not (sug.get("workshop", []) as Array).is_empty() and int(ws2["x"]) == int(sug["workshop"][0]["x"]) and hp.hb.validate()["ok"], "Use suggested layout puts the Workshop lot at %s and the feeder by the pot, still all reachable (%s)" % [str(ws2), str(hp.hb.validate())])
		hp.queue_free()
		await main.get_tree().process_frame
	ok.call(sigs[0] != sigs[1], "the two seeds made different islands")
	print("HOMEBUILD done, failures: %d" % bad[0])
	main.get_tree().quit(1 if bad[0] > 0 else 0)

func _hb_home():
	var H = load("res://scripts/home/home.gd")
	var hm = H.new()
	main.add_child(hm)
	main.current = hm
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	while hm.building:      # a farm built under a still-covered fade comes in slices: wait for all of it
		await main.get_tree().process_frame
	return hm
