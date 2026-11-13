extends RefCounted
## --toy-check: the Boki base's playthings (GARDEN.md section 4, content/rules/toys.json, HomeToys).
##   1. data: a ball, post, tub, warm stone and dig patch in the Base category, each with a stat Care knows
##   2. lean: Flying and Rock Boki weigh the post up, Water, Ice and Crystal the tub
##   3. off: with base_mode off (the shipped default) nothing plays
##   4. on: a placed ball is used by an idle Boki within 60 s, a second Boki joins, the stat rises
##   5. a squabble between two hot tempers, the stat cap, and the rest pose
##   6. each toy placed alone: a fitting Boki uses it within 60 s and its stat rises; a dig turns up a snack
##   7. only a ball for 3 days: it is the favourite, shown on the card, picked first, and a baby inherits it
## Never touches the real save.

## Each toy and a species whose lean it is made for (ember = Fire; bloom = Grass; swarm = Bug).
const FITTING := [["toy_ball", "zapple"], ["toy_post", "kestrike"], ["toy_tub", "rimeshrew"],
	["toy_stone", "kilnbadger"], ["toy_dig", "lilybara"], ["toy_dig", "moundvark"]]

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TOY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _new_save() -> Dictionary:
	var d := Save.fresh()
	for i in 2:
		var k := Save.new_kin("zapple", ["Pip", "Fen"][i])
		k["level"] = 5
		Care.ensure(k)
		k["traits"]["temper"] = 0.3
		d["roster"].append(k)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}      # no base tutorial (Lead)
	return d

## Everyone fed, rested and clean; joy as given, so only play can be on their minds.
func _calm(home, joy: float) -> void:
	for k in home.kins:
		for n in ["food", "energy", "clean"]: k["rec"]["needs"][n] = 80.0
		k["rec"]["needs"]["joy"] = joy

func _playing(home) -> Array:
	return home.kins.filter(func(k): return k.has("play") and k["play"]["phase"] == "play")

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	var R: Dictionary = HomeToys.rules()
	var ids: Array = FITTING.map(func(f): return f[0])
	var in_base := func(id: String) -> bool:
		return HomeLayout.CATALOG[id]["cat"] == "Base" and Care.STATS.has(String(R["toys"][id]["stat"]))
	ok(ids.all(in_base),
			"all five toys are in the Base category, each training a Care stat")
	ok(not FarmUnlocks.rules()["base_mode"], "base_mode is off in the shipped rules")
	Save.d = _new_save()
	var lay := HomeLayout.ensure(Save.d)
	_place(lay)
	var home = await main._hb_home()
	var toys: HomeToys = home.toys
	ok(toys.toys().size() == 3 and not home.hb.nodes.is_empty(), "three toys stand on the island")
	# 2. lean
	var storm := {"species": "kestrike", "traits": {}}
	var stone := {"species": "basaltoad", "traits": {}}
	var frost := {"species": "rimeshrew", "traits": {}}
	var wet := {"species": "kestrike", "lean": {"water": Evo.LEAN_FULL}, "traits": {}}
	var glass := {"species": "kestrike", "lean": {"crystal": Evo.LEAN_FULL}, "traits": {}}
	var ember := {"species": "kilnbadger", "traits": {}}
	var bug := {"species": "moundvark", "traits": {}}
	var likes_post: bool = toys.weight(storm, "toy_post") > toys.weight(storm, "toy_tub") \
			and toys.weight(stone, "toy_post") > toys.weight(stone, "toy_ball")
	ok(likes_post,
			"flying and rock leans weigh the post up")
	var likes_tub: bool = toys.weight(frost, "toy_tub") > toys.weight(frost, "toy_post") \
			and toys.weight(wet, "toy_tub") > toys.weight(wet, "toy_post") \
			and toys.weight(glass, "toy_tub") > toys.weight(glass, "toy_post")
	ok(likes_tub,
			"ice, water and crystal leans weigh the tub up (a lean on the record beats the species)")
	var likes_warm: bool = toys.weight(ember, "toy_stone") > toys.weight(ember, "toy_dig") \
			and toys.weight(ember, "toy_stone") > toys.weight(frost, "toy_stone")
	ok(likes_warm, "a Fire lean weighs the warm stone up")
	var likes_dig: bool = toys.weight(bug, "toy_dig") > toys.weight(bug, "toy_stone") \
			and toys.weight(bug, "toy_dig") > toys.weight(ember, "toy_dig")
	ok(likes_dig, "Grass and Bug leans weigh the dig patch up")
	# 3. off
	_calm(home, 30.0)
	for i in 400:
		_calm(home, 30.0)
		home._move_kin(0.05)
	ok(home.kins.all(func(k): return not k.has("play")), "base_mode off: nobody plays with the toys")
	# 4. on
	FarmUnlocks.rules()["base_mode"] = true
	home.hb.toggle()
	ok(home.hb._tabs().has("Base"), "base_mode on: the build bar has a Base tab")
	home.hb.cat = "Base"
	ok(home.hb._tab_items().size() == 5, "and it offers all five toys")
	home.hb.toggle()
	var speed0 := int(home.kins[0]["rec"]["stats"]["speed"]) + int(home.kins[1]["rec"]["stats"]["speed"])
	var first_t := -1.0
	var second_t := -1.0
	var posed := false
	for i in 4800:
		_calm(home, 40.0)
		home.day_t = 0.5
		home._move_kin(0.05)
		var now := _playing(home)
		if first_t < 0.0 and now.size() >= 1: first_t = i * 0.05
		var shared: bool = now.size() >= 2 and now[0]["play"]["u"] == now[1]["play"]["u"]
		if first_t >= 0.0 and second_t < 0.0 and shared:
			second_t = i * 0.05
		if now.size() >= 1:      # a plain body tilts, a rigged one plays the toy's clip (kact); some toys name a pose
			var pn: Node3D = now[0]["node"]
			var acting := String(pn.get_meta("kact", "")) != "" or String(pn.get_meta("pose", "")) != ""
			posed = posed or pn.get_node("Body").rotation != Vector3.ZERO or acting
		if i % 200 == 0: await main.get_tree().process_frame
		if second_t >= 0.0 and i * 0.05 > second_t + 15.0: break
	ok(first_t >= 0.0 and first_t <= 60.0, "a Boki walked to a toy and played within 60 s (%.1f s)" % first_t)
	ok(second_t >= 0.0, "then a second joined it at the same toy (%.1f s)" % second_t)
	_calm(home, 40.0)
	for i in 1200:
		_calm(home, 40.0)
		home._move_kin(0.05)
		if i % 200 == 0: await main.get_tree().process_frame
	var gained := int(home.kins[0]["rec"]["stats"]["speed"]) + int(home.kins[1]["rec"]["stats"]["speed"]) \
			+ int(home.kins[0]["rec"]["stats"]["power"]) + int(home.kins[1]["rec"]["stats"]["power"]) \
			+ int(home.kins[0]["rec"]["stats"]["focus"]) + int(home.kins[1]["rec"]["stats"]["focus"]) - speed0
	ok(gained >= 1, "play trained a stat (+%d)" % gained)
	# 5. squabble, cap, pose
	var a: Dictionary = home.kins[0]
	var b: Dictionary = home.kins[1]
	for k in [a, b]:      # awake and free: a nap, chase or errand left from the soak above would stop the play
		for busy in ["play", "bath", "chase", "job", "fetch", "eat", "called_t", "going_in", "busy"]:
			k.erase(busy)
		k["nap_t"] = 0.0
		k["hold_t"] = 0.0
		k["t"] = 30.0
		k["rec"]["traits"]["temper"] = 0.95
	var u := int(toys.toys()[0]["u"])
	var tp: Vector3 = toys.toys()[0]["pos"]
	a["play"] = {"u": u, "phase": "play", "t": 10.0, "slot": 0}
	b["play"] = {"u": u, "phase": "go", "t": 0.0, "slot": 1}
	a["pos"] = tp + Vector3(1.0, 0, 0)
	b["pos"] = toys._spot(b, toys.toys()[0])
	toys.step(b, 0.05)
	ok(not b.has("play") and a.has("play") and float(b.get("huff_t", 0.0)) > 0.0,
			"two hot tempers squabble: the newcomer huffs off, the first plays on")
	var power_toy := String(toys.toys()[1]["id"])
	var rec: Dictionary = a["rec"]
	var stat := String(R["toys"][power_toy]["stat"])
	rec["stats"][stat] = Care.stat_cap(rec)
	a["play"] = {"u": int(toys.toys()[1]["u"]), "phase": "play", "t": 0.01, "secs": 10.0, "slot": 0}
	toys.step(a, 0.05)
	ok(int(rec["stats"][stat]) == Care.stat_cap(rec) and not a.has("play"), "a trained-out stat stays at its cap")
	ok(String((a["node"] as Node3D).get_meta("pose", "")) == "" and posed,
			"the play pose is set while playing and cleared after")
	home.queue_free()
	await main.get_tree().process_frame
	for f in FITTING:
		await _alone(String(f[0]), String(f[1]))
	await _favourite()
	FarmUnlocks.rules()["base_mode"] = false
	print("TOY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A home with one `species` Boki and one `id` toy on open ground (base_mode on, the real save untouched).
func _solo_home(id: String, species: String):
	var d := Save.fresh()
	var k := Save.new_kin(species, "Solo")
	k["level"] = 5
	Care.ensure(k)
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}      # no base tutorial (Lead)
	Save.d = d
	var at := HomeLayout.LANDING
	var lay := HomeLayout.ensure(d)
	lay["deco"].append({"u": HomeLayout._next_uid(lay), "id": id, "x": int(at.x), "z": int(at.z) - 6, "r": 0})
	return await main._hb_home()

## A Boki given only a ball, one play a day for 3 days: the ball is its favourite from the third day on
## (not before), it picks the ball first, the Boki card shows it, and a baby inherits it.
func _favourite() -> void:
	var home = await _solo_home("toy_ball", "zapple")
	var rec: Dictionary = home.kins[0]["rec"]
	ok(FavToy.of(rec) == "" and not rec.has("toy_time"), "a new Boki has no favourite toy and no play record")
	var seen := []
	for day in 3:
		var n0 := int(rec.get("toy_n", 0))
		for i in 2400:
			_calm(home, 40.0)
			home.day_t = 0.5
			home._move_kin(0.05)
			if i % 200 == 0: await main.get_tree().process_frame
			if int(rec.get("toy_n", 0)) > n0: break
		seen.append(FavToy.of(rec))
	ok(int(rec.get("toy_n", 0)) == 3 and float(rec["toy_time"].get("toy_ball", 0.0)) >= 24.0,
			"three days of play are logged against the ball (%s s)" % rec.get("toy_time", {}).get("toy_ball", 0))
	ok(seen == ["", "", "toy_ball"], "crowned after the third play, not before (%s)" % [seen])
	var toys: HomeToys = home.toys
	var plain := rec.duplicate(true)
	plain["habit"].erase("toy")
	var boost := float(HomeToys.rules()["fav_weight"])
	ok(is_equal_approx(toys.weight(rec, "toy_ball"), toys.weight(plain, "toy_ball") * boost),
			"it weighs its favourite up by fav_weight")
	var row := VBoxContainer.new()
	AboutView.looks(rec, row)
	ok(row.get_child_count() > 0 and _has_icon(row, "toy_ball"), "the Boki card shows the ball with its icon")
	row.free()
	var mate := Save.new_kin("zapple", "Mate")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var baby := Care.breed(rec, mate, rng)
	ok(FavToy.of(baby) == "toy_ball" and baby["toy_time"].has("toy_ball"), "a baby bred from it inherits the ball")
	var other := Care.breed(mate, Save.new_kin("zapple", "Mate2"), rng)
	ok(FavToy.of(other) == "", "and a baby of two Boki with no favourite has none")
	var old := rec.duplicate(true)
	for key in ["toy_time", "toy_n"]: old.erase(key)
	old["habit"].erase("toy")
	Care.ensure(old)
	ok(FavToy.of(old) == "", "an older record without play keys loads with no favourite")
	FavToy.log_play(old, "toy_post", 30.0)
	FavToy.log_play(old, "toy_ball", 5.0)
	FavToy.log_play(old, "toy_ball", 5.0)
	ok(FavToy.of(old) == "toy_post", "the most-used toy wins, not the most-visited")
	home.queue_free()
	await main.get_tree().process_frame

func _has_icon(n: Node, icon: String) -> bool:
	if n is UI.IconDot and (n as UI.IconDot).id == icon: return true
	return n.get_children().any(func(c): return _has_icon(c, icon))

## One toy and one fitting Boki alone on the island: it plays within 60 s and gains the toy's stat; a dig
## (its snack chance forced to 1) turns up a kibble.
func _alone(id: String, species: String) -> void:
	var R: Dictionary = HomeToys.rules()
	var stat := String(R["toys"][id]["stat"])
	var home = await _solo_home(id, species)
	var snack: float = float(R["toys"][id].get("snack", 0.0))
	if snack > 0.0:
		R["toys"][id]["snack"] = 1.0
	var rec: Dictionary = home.kins[0]["rec"]
	var stat0 := int(rec["stats"][stat])
	var kibble0 := int(Save.d["items"].get("kibble", 0))
	var played := -1.0
	var end := 0.0
	for i in 2400:
		_calm(home, 40.0)
		home.day_t = 0.5
		home._move_kin(0.05)
		if played < 0.0 and not _playing(home).is_empty():
			played = i * 0.05
		if i % 200 == 0: await main.get_tree().process_frame
		var found: bool = snack == 0.0 or int(Save.d["items"].get("kibble", 0)) > kibble0
		if int(rec["stats"][stat]) > stat0 and found:
			end = i * 0.05
			break
	ok(played >= 0.0 and played <= 60.0, "%s: a %s Boki used it within 60 s (%.1f s)" % [id, species, played])
	ok(end > 0.0, "%s: the play trained %s%s" % [id, stat, " and the dig turned up a snack" if snack > 0.0 else ""])
	R["toys"][id]["snack"] = snack
	home.queue_free()
	await main.get_tree().process_frame

## The three toys on open ground near the landing, three tiles apart.
func _place(lay: Dictionary) -> void:
	var at := HomeLayout.LANDING
	var i := 0
	for id in ["toy_ball", "toy_post", "toy_tub"]:
		var e := {"u": HomeLayout._next_uid(lay), "id": id, "x": int(at.x) + 3 * i - 3, "z": int(at.z) - 6, "r": 0}
		lay["deco"].append(e)
		i += 1
