extends RefCounted
## --feed-check: a hungry Boki, kibble bought at the market, the Feed panel lists it, feeding works
## and the "too weak to go" gate lifts. Fresh save, and a save with a trough built. Then the feeding bowl
## (base_mode, FeedBowl): three snacks dropped in, three hungry Boki (bold, greedy, timid; the first two rivals)
## all eat within 30 s in BaseLife's Eat state, one at a time, the timid one last, the rivals huff, each meal
## leans through Evo.eat, and a full Boki stays out.
## Prints FEED ok/FAIL lines and "FEED DONE, failures: N". Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FEED %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	await _case(false)
	await _case(true)
	await _bowl()
	print("FEED DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _feed_buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button and (n as Button).text == "Feed": out.append(n)
	for c in n.get_children(): out += _feed_buttons(c)
	return out

func _says_nothing(n: Node) -> bool:
	if n is Label and (n as Label).text.begins_with("Nothing to feed"): return true
	for c in n.get_children():
		if _says_nothing(c): return true
	return false

func _case(trough: bool) -> void:
	var tag := "with a trough" if trough else "fresh save"
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Care.ensure(k)
	if k["likes"]["hates"] == "kibble":
		k["likes"]["hates"] = k["likes"]["food"]     # likes come from the random uid; a kibble-hater refuses
	k["starter"] = true
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true}
	Save.d["gems"] = 500
	HomeLayout.ensure(Save.d)
	if trough: Econ.ensure()
	k["needs"]["food"] = 5.0
	k["starve"] = (Care.STARVE["refuse"] + 0.5) * 3600.0
	var home = await main._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await main.get_tree().process_frame
	Save.d["items"]["kibble"] = 0
	home._open_feed(k)
	ok(_feed_buttons(home.panel_host).is_empty() and _says_nothing(home.panel_host), "%s: no food says so" % tag)
	var ask := Exchange.best("kibble", "sell")
	var r := Exchange.post("buy", "kibble", 2, ask)
	ok(r["ok"] and int(r["filled"]) == 2 and Econ.pantry("kibble") == 2, "%s: bought 2 kibble from the market" % tag)
	home._open_feed(k)
	await main.get_tree().process_frame      # the previous panel is only queue_freed: let it go first
	var btns := _feed_buttons(home.panel_host)
	ok(btns.size() == 1 and not _says_nothing(home.panel_host), "%s: the panel offers the kibble" % tag)
	ok(home.hecon.refuse_reason() != "", "%s: too weak to go while starving" % tag)
	var food0 := Care.need(k, "food")
	if btns.size() == 1: (btns[0] as Button).pressed.emit()
	var food1 := Care.need(k, "food")
	ok(Econ.pantry("kibble") == 1 and food1 > food0, "%s: feeding eats a kibble, food %d -> %d" % [tag, food0, food1])
	ok(home.hecon.refuse_reason() == "", "%s: it can go on an expedition again" % tag)
	home.queue_free()

# ------------------------------------------------------------------ the feeding bowl
const BOWL_LIMIT := 30.0       # s of play the three hungry Boki have to eat in
const STEP := 0.05             # s a simulated frame

func _bowl_boki(sp: String, nm: String, bravery: float, food: float) -> Dictionary:
	var r := Save.new_kin(sp, nm)
	Care.ensure(r)
	for n in Care.NEEDS: r["needs"][n] = 100.0
	r["needs"]["food"] = food
	r["traits"]["bravery"] = bravery
	r["likes"] = {"food": "sweetbun", "hates": "puffcorn", "play": "pet"}      # emberberry is neither
	return r

static func _lean_sum(r: Dictionary) -> float:
	return (r.get("lean", {}) as Dictionary).values().reduce(func(a, b): return a + float(b), 0.0)

func _bowl() -> void:
	var rules: Dictionary = Content.rules("farm_build")
	ok(not FarmUnlocks.open(FeedBowl.ID), "bowl: hidden outside base mode")
	rules["base_mode"] = true
	ok(FarmUnlocks.open(FeedBowl.ID), "bowl: in base mode it can be built")
	Save.d = Save.fresh()
	var bold := _bowl_boki("cindle", "Bold", 0.9, 20.0)
	var greedy := _bowl_boki("pebbit", "Greedy", 0.6, 5.0)
	var shy := _bowl_boki("puddlet", "Shy", 0.1, 10.0)
	var full := _bowl_boki("zapple", "Full", 0.9, 100.0)
	bold["bonds"] = {greedy["uid"]: -0.8}
	greedy["bonds"] = {bold["uid"]: -0.8}
	var roster := [bold, greedy, shy, full]
	full["starter"] = true
	Save.d["roster"] = roster
	Save.d["active"] = full["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d["crops"]["emberberry"] = 5
	HomeLayout.ensure(Save.d)
	var home = await main._hb_home()
	home.day_t = 0.45
	home.ppos = Vector3(-500, 0, -500)       # you are away: nobody clings to you
	var c: Vector3 = home.world.random_ground(0)
	var bowl := {"id": FeedBowl.ID, "u": 990002, "x": int(c.x), "z": int(c.z), "r": 0}
	Save.d["layout"]["deco"].append(bowl)
	home.hb._sync_deco()
	c = FeedBowl.at(bowl)
	var spots := {"Bold": Vector3(-2.5, 0, 0.5), "Greedy": Vector3(5.5, 0, 0.5), "Shy": Vector3(0.5, 0, -3.0),
		"Full": Vector3(2.0, 0, 3.0)}
	var ks := {}
	for k in home.kins:
		for key in ["indoors", "leap", "exiting", "going_in", "called_t", "busy", "eat", "nap_go", "job"]: k.erase(key)
		k["nap_t"] = 0.0
		k["t"] = 3.0
		k["pos"] = home.world.free_spot_near(c + spots[k["rec"]["name"]], [], 0.6)
		(k["node"] as Node3D).position = k["pos"]
		ks[k["rec"]["name"]] = k
	ok(ks.size() == 4 and home.hb.nodes.has(990002), "bowl: home puts the bowl and four Boki out")
	for _i in 20: home._move_kin(STEP)
	ok(home.kins.all(func(k): return FeedBowl.phase(k) == ""), "bowl: nobody heads for an empty bowl")
	for _i in 3: FeedBowl.drop(home, bowl)
	ok(FeedBowl.snacks(bowl).size() == 3 and Econ.pantry("emberberry") == 2 and not FeedBowl.drop(home, bowl),
		"bowl: three snacks come out of the pantry and the bowl takes no more")
	var food0 := {}
	var lean0 := {}
	for nm in ks:
		food0[nm] = Care.need(ks[nm]["rec"], "food")
		lean0[nm] = _lean_sum(ks[nm]["rec"])
	var ate := {}
	var seen := {}
	var peak := 0
	var t := 0.0
	var outside_eat := 0      # frames a Boki was at the bowl without BaseLife being in Eat
	while t < BOWL_LIMIT + 5.0 and ate.size() < 3:
		home.day_t = 0.45
		home._move_kin(STEP)
		t += STEP
		var eaters := 0
		for nm in ks:
			var k: Dictionary = ks[nm]
			var ph := FeedBowl.phase(k)
			if ph == "": continue
			seen["%s:%s" % [nm, ph]] = true
			if ph == "eat": eaters += 1
			if not (k["life"] as Fsm).is_in(BaseLife.S.EAT): outside_eat += 1
		for nm in ks:
			if not ate.has(nm) and nm != "Full" and Care.need(ks[nm]["rec"], "food") > float(food0[nm]) + 10.0:
				ate[nm] = snappedf(t, 0.05)
		peak = maxi(peak, eaters)
		if int(t / STEP) % 100 == 0: await main.get_tree().process_frame
	print("FEED  bowl: ate at %s, phases seen %s" % [str(ate), ", ".join(seen.keys())])
	var in_time: bool = ate.values().all(func(s): return s <= BOWL_LIMIT)
	ok(ate.size() == 3 and in_time, "bowl: all three hungry Boki eat within %d s" % int(BOWL_LIMIT))
	ok(ate.size() == 3 and ate["Shy"] > ate["Bold"] and ate["Shy"] > ate["Greedy"], "bowl: the timid one eats last")
	ok(peak == 1, "bowl: one at the bowl at a time")
	ok(outside_eat == 0, "bowl: every visit is BaseLife's Eat state (one machine)")
	ok(seen.has("Bold:huff") or seen.has("Greedy:huff"), "bowl: the rivals huff at the bowl")
	var calm: bool = not seen.has("Shy:huff") and not seen.keys().any(func(s): return s.begins_with("Full:"))
	var empty: bool = FeedBowl.snacks(bowl).is_empty()
	ok(calm and empty, "bowl: the timid one picks no fight, the full one stays out, bowl empty")
	var leaned := ks.keys().filter(func(nm): return _lean_sum(ks[nm]["rec"]) > float(lean0[nm]))
	var who := ", ".join(leaned)
	ok(leaned.size() == 3 and not leaned.has("Full"), "bowl: each Boki that ate leans (Evo.eat) (%s)" % who)
	ok(home.kins.all(func(k): return FeedBowl.phase(k) == ""), "bowl: everyone is done at the bowl")
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
