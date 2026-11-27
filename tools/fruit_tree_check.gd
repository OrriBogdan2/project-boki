extends RefCounted
## --fruit-tree-check: fruit trees (scripts/home/fruit_tree.gd, content/rules/fruit_trees.json). A tree grows from a
## sapling over real time, drops one fruit per fruit_secs once grown (at most max_fallen), you pick the fallen fruit by
## walking up, a hungry Boki walks to it and eats it, and a saved tree comes back as it was. Never touches the save.
## With --shots-dir=<dir> (a display, not --headless) it also saves a PNG of three trees at the close farm camera.

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("FRUIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _save() -> Dictionary:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Care.ensure(k)
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	return d


## A tree entry put down at time `t0` on a fresh save's island.
func _tree(t0: float) -> Dictionary:
	Save.d = _save()
	var l := HomeLayout.ensure(Save.d)
	var e := {"u": HomeLayout._next_uid(l), "id": FruitTree.ID, "x": 40, "z": 30, "r": 0, "pt": t0}
	(l["deco"] as Array).append(e)
	return e


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_growth()
	_fruit()
	_saved()
	_look()
	await _in_the_garden()
	print("FRUIT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _growth() -> void:
	var r := FruitTree.rules()
	var grow := float(r["grow_secs"])
	ok(HomeLayout.CATALOG.has(FruitTree.ID) and HomeLayout.blocks(FruitTree.ID), "the Garden tab offers a fruit tree")
	ok(FarmUnlocks.need_of(FruitTree.ID).has("level"), "it unlocks with the farm's level")
	var e := _tree(1000.0)
	var stages := [
		FruitTree.stage(e, 1000.0), FruitTree.stage(e, 1000.0 + grow * 0.5), FruitTree.stage(e, 1000.0 + grow)
	]
	ok(stages == [0, 1, 2], "a tree is a sapling, then young, then grown: %s" % str(stages))
	ok(
		FruitTree.stage(e, 1000.0 + grow * 0.39) == 0 and FruitTree.stage(e, 1000.0 + grow * 0.4) == 1,
		"it turns young at 40% of grow_secs"
	)


func _fruit() -> void:
	var grow := float(FruitTree.rules()["grow_secs"])
	var each := float(FruitTree.rules()["fruit_secs"])
	var cap := int(FruitTree.rules()["max_fallen"])
	var e := _tree(1000.0)
	var d := Save.d
	ok(not FruitTree.settle(d, e, 1000.0 + grow * 0.9) and FruitTree.fallen(e).is_empty(), "a young tree drops nothing")
	ok(not FruitTree.settle(d, e, 1000.0 + grow + each - 1.0), "a grown tree has dropped nothing before fruit_secs")
	ok(
		FruitTree.settle(d, e, 1000.0 + grow + each) and FruitTree.fallen(e).size() == 1,
		"one fruit falls after fruit_secs"
	)
	ok(is_equal_approx(FruitTree.swell(e, 1000.0 + grow + each * 1.5), 0.5), "the next fruit is half swollen halfway")
	FruitTree.settle(d, e, 1000.0 + grow + each * 100.0)
	ok(FruitTree.fallen(e).size() == cap, "a tree left for hours keeps only %d fruit under it" % cap)
	ok(is_equal_approx(FruitTree.swell(e, 1000.0 + grow + each * 100.0), 1.0), "a full tree's fruit hangs ready")
	var food := String(FruitTree.fallen(e)[0])
	var kinds := {}
	for f in FruitTree.fallen(e):
		kinds[f] = true
	ok(
		SnackPatch.zone_snacks(d).has(food) and kinds.size() == cap,
		"the fruit are the island's snacks, a different one each drop: %s" % str(kinds.keys())
	)
	var before := int(Econ.pantry(food))
	var late := 1000.0 + grow + each * 100.0
	var got := FruitTree.pick(d, e)
	ok(
		got.size() == cap and FruitTree.fallen(e).is_empty() and Econ.pantry(food) > before,
		"picking puts the fruit in the pantry"
	)
	ok(
		not FruitTree.settle(d, e, late + each - 1.0) and FruitTree.settle(d, e, late + each),
		"after a pick the next fruit takes a full fruit_secs"
	)


func _saved() -> void:
	var e := _tree(1000.0)
	FruitTree.settle(
		Save.d, e, 1000.0 + float(FruitTree.rules()["grow_secs"]) + float(FruitTree.rules()["fruit_secs"]) * 2.0
	)
	var back: Dictionary = JSON.parse_string(JSON.stringify(Save.d))
	HomeLayout.ensure(back)
	var again: Array = FruitTree.trees(back)
	ok(
		(
			again.size() == 1
			and FruitTree.fallen(again[0]) == FruitTree.fallen(e)
			and int(again[0]["n"]) == 2
			and is_equal_approx(float(again[0]["pt"]), 1000.0)
		),
		"saved and loaded, the tree keeps its fallen fruit and its drop count"
	)


func _look() -> void:
	var grow := float(FruitTree.rules()["grow_secs"])
	var now := Time.get_unix_time_from_system()
	var young := _tree(now - grow * 0.5)
	var young_h := FruitTree.model(young).get_child_count()
	var grown := _tree(now - grow - float(FruitTree.rules()["fruit_secs"]) * 2.5)
	FruitTree.settle(Save.d, grown, now)
	ok(FruitTree.fallen(grown).size() == 2, "a tree grown 2.5 fruit_secs ago has 2 fruit down")
	ok(FruitTree.model(grown).get_child_count() == young_h + 1 + 2, "the model adds the hanging fruit and the 2 fallen")
	var s := FruitTree.sig(grown)
	grown["fall"] = []
	ok(FruitTree.sig(grown) != s, "the signature changes when the fruit is picked, so the tree is redrawn")


func _in_the_garden() -> void:
	var grow := float(FruitTree.rules()["grow_secs"])
	var now := Time.get_unix_time_from_system()
	var e := _tree(now - grow - float(FruitTree.rules()["fruit_secs"]) * 1.5)
	var l := HomeLayout.of(Save.d)
	for at in [[37, 30, 0.1], [43, 30, 0.6]]:
		(l["deco"] as Array).append(
			{"u": HomeLayout._next_uid(l), "id": FruitTree.ID, "x": at[0], "z": at[1], "r": 0, "pt": now - grow * at[2]}
		)
	l["inv"].erase(SnackPatch.ID)
	var home = await main._hb_home()
	var t0 := CheckClock.own_msec()  # the home builds its UI in frame slices: CPU work, not game time
	while home.panel_host == null and CheckClock.own_msec() - t0 < 60000:
		await main.get_tree().process_frame
	home._close_panel()
	var c := HomeLayout.deco_center(e)
	home.ppos = c + Vector3(4.0, 0, 0)
	home.hsp.tick(1.0)
	e = FruitTree.trees(Save.d)[0]  # the home may have rebuilt the layout around the entry
	ok(FruitTree.fallen(e).size() == 1, "in the garden the tree drops its fruit while you are by (1 down)")
	var k: Dictionary = home.kins[0]
	for key in ["eat", "life_eat", "nap_t", "life_spot", "life_at"]:
		k.erase(key)
	Save.d["crops"] = {}
	Save.d["items"] = {}
	k["pos"] = c + Vector3(5.0, 0, 0)
	k["rec"]["needs"]["food"] = 20.0
	var fruit := String(FruitTree.fallen(e)[0])
	k["rec"]["likes"]["hates"] = fruit
	BaseFeed.pick(home, k)
	ok(String(k.get("life_eat", {}).get("from", "")) != "fruit", "it will not walk to a fruit it hates")
	k.erase("life_eat")
	k["rec"]["likes"]["hates"] = ""
	ok(
		BaseFeed.pick(home, k) and String(k["life_eat"]["from"]) == "fruit",
		"a hungry Boki with no other food heads for the fallen fruit"
	)
	k["pos"] = c + Vector3(1.0, 0, 0)
	var food_before := Care.need(k["rec"], "food")
	BaseFeed.tick(home, k, 1.0)
	ok(
		FruitTree.fallen(e).is_empty() and Care.need(k["rec"], "food") > food_before,
		"it eats it: the fruit is gone and it is less hungry"
	)
	k["rec"]["needs"]["food"] = 20.0
	ok(
		not BaseFeed.pick(home, k) or String(k["life_eat"]["from"]) != "fruit",
		"with no fruit down it does not walk to the tree"
	)
	k.erase("life_eat")
	e["fall"] = ["kibble"]
	home.ppos = c + Vector3(1.0, 0, 0)
	home.hsp.tick(1.0)
	ok(
		FruitTree.fallen(e).is_empty() and Econ.pantry("kibble") == 1,
		"walking up to the tree picks the fruit for the pantry"
	)
	home.queue_free()
	await main.get_tree().process_frame
	await _shot()


## The three growth stages from where you stand, at the close farm camera (only with --shots-dir and a display), on a
## farm whose first-day tutorial is done.
func _shot() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	Save.d["tutorial"] = {"home": true, "hatched": true, "intro": true, "day1_done": true}
	Settings.set_v("tips", false)
	var row := [Vector2i(43, 31), Vector2i(41, 32), Vector2i(45, 32)]  # grown, sapling, young
	for i in 3:
		var t: Dictionary = FruitTree.trees(Save.d)[i]
		t["x"] = row[i].x
		t["z"] = row[i].y
		FruitTree.settle(Save.d, t, Time.get_unix_time_from_system())
	FruitTree.trees(Save.d)[0]["fall"] = ["emberberry", "sunroot", "puffcorn"]  # the grown tree with its three down
	var home = await main._hb_home()
	home.day_t = 0.45
	home._close_panel()
	home.ppos = Vector3(46.5, 0, 37.0)
	home.player.position = home.ppos
	home.cam.snap(home.ppos)
	for k in home.kins:
		k["pos"] = Vector3(50.0, 0, 38.0)
		k["goal"] = k["pos"]
		(k["node"] as Node3D).position = k["pos"]
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	for i in 90:
		await main.get_tree().process_frame
	var path := ProjectSettings.globalize_path(dir).path_join("fruit_trees_close_farm_cam.png")
	ok(main.get_viewport().get_texture().get_image().save_png(path) == OK, "saved the close-camera shot: %s" % path)
	home.queue_free()
	await main.get_tree().process_frame
