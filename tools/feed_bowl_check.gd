extends RefCounted
## --feed-bowl-check: the feeding bowl. It is a base-mode item (off the build menu with farm_build.json base_mode off);
## a snack dropped in it calls the hungry Boki nearby; with a bowl and 3 hungry Boki (a bold one, a
## greedy middle one and a timid one, the first two rivals) all eat within 30 s, the timid one last,
## the rivals huff at each other at the bowl, each gets the food's lean (Evo) like hand feeding, and a
## full Boki stays out of it. Never touches the real save.

const LIMIT := 30.0                    # seconds of play the three have to eat in
const STEP := 0.05

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FEEDBOWL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _boki(sp: String, nm: String, bravery: float, food: float) -> Dictionary:
	var r := Save.new_kin(sp, nm)
	r["trust"] = 60.0
	r["level"] = 5
	Care.ensure(r)
	for n in Care.NEEDS: r["needs"][n] = 100.0
	r["needs"]["food"] = food
	r["traits"]["bravery"] = bravery
	r["likes"] = {"food": "sweetbun", "hates": "puffcorn", "play": "pet"}      # emberberry is neither
	return r

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	# ---------------------------------------------------------------- 1. base mode gates it
	Save.d = Save.fresh()
	var base_item: bool = HomeLayout.CATALOG["feed_bowl"].get("base", false)
	FarmUnlocks.rules()["base_mode"] = false
	ok(base_item and not FarmUnlocks.open("feed_bowl"), "the bowl is a base item: hidden outside base mode")
	FarmUnlocks.rules()["base_mode"] = true
	ok(FarmUnlocks.open("feed_bowl"), "in base mode it can be built")
	# ---------------------------------------------------------------- 2. a bowl, three hungry Boki and a full one
	Econ.ensure()
	Save.d["feeders"] = []
	Save.d["feeder_inv"] = {}
	var bold := _boki("cindle", "Bold", 0.9, 20.0)
	var greedy := _boki("pebbit", "Greedy", 0.6, 5.0)
	var shy := _boki("puddlet", "Shy", 0.1, 10.0)
	var full := _boki("zapple", "Full", 0.9, 100.0)
	bold["bonds"] = {greedy["uid"]: -0.8}
	greedy["bonds"] = {bold["uid"]: -0.8}
	var roster := [bold, greedy, shy, full]
	Save.d["roster"] = roster
	Save.d["active"] = full["uid"]
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	Save.d["crops"]["emberberry"] = 5
	var lay := HomeLayout.ensure(Save.d)
	lay["made"] = true
	var bowl := {"u": HomeLayout._next_uid(lay), "id": "feed_bowl", "x": 47, "z": 34, "r": 0}
	lay["deco"].append(bowl)
	var H = load("res://scripts/home/home.gd").new()
	main.add_child(H)
	for _f in 4: await main.get_tree().process_frame
	H.day_t = 0.5
	var spots := {bold: Vector3(45.0, 0, 34.5), greedy: Vector3(53.5, 0, 34.5),
		shy: Vector3(47.5, 0, 31.0), full: Vector3(49.0, 0, 37.0)}
	for k in H.kins:
		for key in ["indoors", "leap", "exiting", "going_in", "called_t", "busy", "eat", "nap_go", "job"]: k.erase(key)
		k["nap_t"] = 0.0
		k["t"] = 3.0
		k["goal"] = Vector3.INF
		(k["node"] as Node3D).visible = true
		k["pos"] = H.world.free_spot_near(spots[k["rec"]], [], 0.6)
		(k["node"] as Node3D).position = k["pos"]
	var ks := {}
	for k in H.kins: ks[k["rec"]["name"]] = k
	ok(ks.size() == 4 and H.hb.nodes.has(int(bowl["u"])), "home puts the bowl and four Boki out")
	for _i in 20: H._move_kin(STEP)
	ok(H.kins.all(func(k): return not k.has("bowl")), "nobody heads for an empty bowl")
	var lean0 := {}
	for r in roster: lean0[r["name"]] = float(r["aff"]["fierce"]) if r.has("aff") else 0.0
	for _i in 3:
		FeedBowl.drop(H, bowl)
	var pantry := int(Save.d["crops"]["emberberry"])
	ok(FeedBowl.snacks(bowl).size() == 3 and pantry == 2 and not FeedBowl.drop(H, bowl),
		"three snacks come out of the pantry and the bowl takes no more")
	# ---------------------------------------------------------------- 3. they eat
	var food0 := {}
	for nm in ks: food0[nm] = Care.need(ks[nm]["rec"], "food")
	var ate := {}
	var seen := {}
	var t := 0.0
	var peak_eaters := 0
	while t < LIMIT + 5.0 and ate.size() < 3:
		H.day_t = 0.5
		H._move_kin(STEP)
		t += STEP
		var eaters := 0
		for nm in ks:
			var k: Dictionary = ks[nm]
			if FeedBowl.state(k) == FeedBowl.S.EAT: eaters += 1
			if k.has("bowl"): seen["%s:%d" % [nm, FeedBowl.state(k)]] = true
			if not ate.has(nm) and nm != "Full" and Care.need(k["rec"], "food") > float(food0[nm]) + 10.0: ate[nm] = t
		peak_eaters = maxi(peak_eaters, eaters)
		if int(t / STEP) % 100 == 0: await main.get_tree().process_frame
	print("FEEDBOWL  ate at %s, states seen %s" % [str(ate), ", ".join(seen.keys())])
	var in_time: bool = ate.values().all(func(s): return s <= LIMIT)
	ok(ate.size() == 3 and in_time, "all three hungry Boki eat within %d s (%s)" % [int(LIMIT), str(ate)])
	var shy_last: bool = ate.size() == 3 and ate["Shy"] > ate["Bold"] and ate["Shy"] > ate["Greedy"]
	ok(shy_last, "the timid one eats last")
	ok(peak_eaters == 1, "one at the bowl at a time")
	var huff := FeedBowl.S.HUFF
	ok(seen.has("Bold:%d" % huff) or seen.has("Greedy:%d" % huff), "the rivals huff at the bowl")
	var calm: bool = not seen.has("Shy:%d" % huff) and not ks["Full"].has("bowl")
	ok(calm and FeedBowl.snacks(bowl).is_empty(), "the timid one picks no fight, the full one stays out, bowl empty")
	var leaned := roster.filter(func(r): return float(r["aff"]["fierce"]) >= lean0[r["name"]] + Evo.FOOD_AFF - 0.01)
	var names := leaned.map(func(r): return r["name"])
	var lean_text := "each Boki that ate leans Fierce by %d, like hand feeding" % int(Evo.FOOD_AFF)
	ok(names.size() == 3 and not names.has("Full"), "%s (%s)" % [lean_text, ", ".join(names)])
	ok(H.kins.all(func(k): return not k.has("bowl")), "everyone is back to roaming")
	H.queue_free()
	await main.get_tree().process_frame
	print("FEEDBOWL %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)
