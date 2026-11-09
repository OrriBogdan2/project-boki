extends RefCounted
## --snack-patch-check: the garden's one snack patch (scripts/home/snack_patch.gd, GARDEN.md section 10 question 1).
## A base_mode save has exactly one patch; it yields the four lean-food snacks after its timer, picked up by walking
## over it; none of them is in the market (no Seeds, Sell or Exchange). With base_mode off it does not exist.
## Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("SNACK %s %s" % ["ok  " if cond else "FAIL", what])
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

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	var rules: Dictionary = FarmUnlocks.rules()
	ok(not FarmUnlocks.base_mode(), "base_mode is off in the shipped rules")
	Save.d = _save()
	HomeLayout.ensure(Save.d)
	ok(HomeLayout.count_of(SnackPatch.ID, Save.d) == 0 and not FarmUnlocks.open(SnackPatch.ID),
			"off: no patch is granted and the Garden tab does not offer one")
	rules["base_mode"] = true
	_rules_and_save()
	await _in_the_garden()
	_market()
	rules["base_mode"] = false
	print("SNACK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _rules_and_save() -> void:
	var lean_types := {}
	for s in SnackPatch.rules()["snacks"]:
		lean_types[Lean.key_of(String(s))] = true
	ok(SnackPatch.rules()["snacks"].size() == 4 and lean_types.size() == 4 and not lean_types.has(""),
			"four snacks, each leaning a different element: %s" % str(lean_types.keys()))
	Save.d = _save()
	HomeLayout.ensure(Save.d)
	HomeLayout.ensure(Save.d)
	var one := HomeLayout.count_of(SnackPatch.ID, Save.d) == 1
	ok(one and FarmUnlocks.open(SnackPatch.ID), "on: a new save has exactly one patch, in storage")
	var L := HomeLayout.of(Save.d)
	var e := {"u": HomeLayout._next_uid(L), "id": SnackPatch.ID, "x": 40, "z": 30, "r": 0}
	(L["deco"] as Array).append(e)
	L["inv"].erase(SnackPatch.ID)
	e["t"] = Time.get_unix_time_from_system()
	var back: Dictionary = JSON.parse_string(JSON.stringify(Save.d))
	HomeLayout.ensure(back)
	var kept := HomeLayout.count_of(SnackPatch.ID, back) == 1 and not SnackPatch.entry(back).is_empty()
	ok(kept, "put down and saved, it is still the one patch")
	var now := Time.get_unix_time_from_system()
	var before: Dictionary = (Save.d["crops"] as Dictionary).duplicate()
	ok(SnackPatch.harvest(Save.d, now).is_empty() and Save.d["crops"] == before, "before its timer it yields nothing")
	var late: float = now + float(SnackPatch.rules()["grow_secs"]) + 1.0
	var got := SnackPatch.harvest(Save.d, late)
	var each := got.size() == 4
	for s in SnackPatch.rules()["snacks"]:
		each = each and got.has(s) and int(Save.d["crops"].get(s, 0)) == int(before.get(s, 0)) + 1
	ok(each, "after its timer it yields the four snacks, one each: %s" % str(got))
	ok(SnackPatch.harvest(Save.d, late).is_empty(), "picked, it starts over")

func _in_the_garden() -> void:
	Save.d = _save()
	HomeLayout.ensure(Save.d)
	var L := HomeLayout.of(Save.d)
	var e := {"u": HomeLayout._next_uid(L), "id": SnackPatch.ID, "x": 40, "z": 30, "r": 0,
			"t": Time.get_unix_time_from_system() - float(SnackPatch.rules()["grow_secs"]) - 1.0}
	(L["deco"] as Array).append(e)
	L["inv"].erase(SnackPatch.ID)
	var home = await main._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await main.get_tree().process_frame
	home._close_panel()
	var c := HomeLayout.deco_center(e)
	home.ppos = c + Vector3(4.0, 0, 0)
	home.hsp.tick(1.0)
	var none: bool = (Save.d["crops"] as Dictionary).get("emberberry", 0) == _save()["crops"].get("emberberry", 0)
	ok(none, "ripe, walking past does not pick it")
	home.ppos = c
	home.hsp.tick(1.0)
	var all := (SnackPatch.rules()["snacks"] as Array).all(func(s): return int(Save.d["crops"].get(s, 0)) >= 1)
	var now := Time.get_unix_time_from_system()
	ok(all and not SnackPatch.ripe(SnackPatch.entry(Save.d), now), "walking over the ripe patch picks all four")
	home.queue_free()
	await main.get_tree().process_frame

func _market() -> void:
	Save.d = _save()
	var mk := HomeMarket.new(null, Callable())
	var tabs: Array = HomeMarket.vendor_tabs()
	ok(not tabs.has("Seeds") and not tabs.has("Sell"), "on: the stall has no seed shop and no Sell tab: %s" % str(tabs))
	var listed := false
	for t in tabs:
		mk.vendor_tab = String(t)
		for sec in mk._vendor_sections():
			for g in sec[1]:
				for s in SnackPatch.rules()["snacks"]:
					listed = listed or String(g[0]).contains(String(s))
	ok(not listed, "on: none of the four snacks is on sale")
