extends RefCounted
## --toy-check: the Boki base's playthings (GARDEN.md section 4, content/rules/toys.json, HomeToys).
##   1. data: a ball, a climbing post and a splash tub in the Base category, each with a stat Care knows
##   2. lean: Flying and Rock Boki weigh the post up, Water and Ice the tub
##   3. off: with base_mode off (the shipped default) nothing plays
##   4. on: a placed ball is used by an idle Boki within 60 s, a second Boki joins, the stat rises
##   5. a squabble between two hot tempers, the stat cap, and the rest pose
## Never touches the real save.

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
	d["tutorial"] = {"hatched": true, "intro": true}
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
	var ids: Array = ["toy_ball", "toy_post", "toy_tub"]
	var in_base := func(id: String) -> bool:
		return HomeLayout.CATALOG[id]["cat"] == "Base" and Care.STATS.has(String(R["toys"][id]["stat"]))
	ok(ids.all(in_base),
			"the ball, post and tub are in the Base category, each training a Care stat")
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
	var wet := {"species": "kestrike", "lean": {"water": 1.0}, "traits": {}}
	var likes_post: bool = toys.weight(storm, "toy_post") > toys.weight(storm, "toy_tub") \
			and toys.weight(stone, "toy_post") > toys.weight(stone, "toy_ball")
	ok(likes_post,
			"flying and rock leans weigh the post up")
	var likes_tub: bool = toys.weight(frost, "toy_tub") > toys.weight(frost, "toy_post") \
			and toys.weight(wet, "toy_tub") > toys.weight(wet, "toy_post")
	ok(likes_tub,
			"ice and water leans weigh the tub up (a lean on the record beats the species)")
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
	ok(home.hb._tab_items().size() == 3, "and it offers the ball, post and tub")
	home.hb.toggle()
	var speed0 := int(home.kins[0]["rec"]["stats"]["speed"]) + int(home.kins[1]["rec"]["stats"]["speed"])
	var first_t := -1.0
	var second_t := -1.0
	var ball_posed := false
	for i in 4800:
		_calm(home, 40.0)
		home.day_t = 0.5
		home._move_kin(0.05)
		var now := _playing(home)
		if first_t < 0.0 and now.size() >= 1: first_t = i * 0.05
		var shared: bool = now.size() >= 2 and now[0]["play"]["u"] == now[1]["play"]["u"]
		if first_t >= 0.0 and second_t < 0.0 and shared:
			second_t = i * 0.05
		ball_posed = ball_posed or (now.size() >= 1 and String(now[0]["node"].get_meta("pose", "")) != "")
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
	for k in [a, b]:
		k.erase("play")
		k["t"] = 30.0
		k["rec"]["traits"]["temper"] = 0.95
	var u := int(toys.toys()[0]["u"])
	var tp: Vector3 = toys.toys()[0]["pos"]
	a["play"] = {"u": u, "phase": "play", "t": 10.0, "slot": 0}
	b["play"] = {"u": u, "phase": "go", "t": 0.0, "slot": 1}
	a["pos"] = tp + Vector3(1.0, 0, 0)
	b["pos"] = toys._spot(b, toys.toys()[0])
	toys.step(b, 0.05)
	ok(not b.has("play") and a.has("play") and float(b["huff_t"]) > 0.0,
			"two hot tempers squabble: the newcomer huffs off, the first plays on")
	var power_toy := String(toys.toys()[1]["id"])
	var rec: Dictionary = a["rec"]
	var stat := String(R["toys"][power_toy]["stat"])
	rec["stats"][stat] = Care.stat_cap(rec)
	a["play"] = {"u": int(toys.toys()[1]["u"]), "phase": "play", "t": 0.01, "slot": 0}
	toys.step(a, 0.05)
	ok(int(rec["stats"][stat]) == Care.stat_cap(rec) and not a.has("play"), "a trained-out stat stays at its cap")
	ok(String((a["node"] as Node3D).get_meta("pose", "")) == "" and ball_posed,
			"the play pose is set while playing and cleared after")
	FarmUnlocks.rules()["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("TOY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The three toys on open ground near the landing, three tiles apart.
func _place(lay: Dictionary) -> void:
	var at := HomeLayout.LANDING
	var i := 0
	for id in ["toy_ball", "toy_post", "toy_tub"]:
		var e := {"u": HomeLayout._next_uid(lay), "id": id, "x": int(at.x) + 3 * i - 3, "z": int(at.z) - 6, "r": 0}
		lay["deco"].append(e)
		i += 1
