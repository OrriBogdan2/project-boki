extends RefCounted
## --snack-patch-check: the garden's one snack patch (scripts/home/snack_patch.gd, GARDEN.md section 10 question 1).
## A base_mode save has exactly one patch; it yields the four lean-food snacks after its timer, picked up by walking
## over it; none of them is in the market (no Seeds, Sell or Exchange). With base_mode off it does not exist.
## Never touches the real save.

var bad := 0
var main: Node

const OLD_SAVE := "user://snack_patch_check_old.json"

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
	ok(FarmUnlocks.base_mode(), "base_mode is on in the shipped rules")
	rules["base_mode"] = false
	Save.d = _save()
	HomeLayout.ensure(Save.d)
	ok(HomeLayout.count_of(SnackPatch.ID, Save.d) == 0 and not FarmUnlocks.open(SnackPatch.ID),
			"off: no patch is granted and the Garden tab does not offer one")
	rules["base_mode"] = true
	_rules_and_save()
	_first_batch()
	_textures()
	_ridge()
	await _in_the_garden()
	_market()
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
	var l := HomeLayout.of(Save.d)
	var e := {"u": HomeLayout._next_uid(l), "id": SnackPatch.ID, "x": 40, "z": 30, "r": 0}
	(l["deco"] as Array).append(e)
	l["inv"].erase(SnackPatch.ID)
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
	var extra := SnackPatch.extra(Save.d, {"rot": 0}, late)
	var each: bool = got.size() == 6 and got[5] == extra      # the four, the season snack, a rotating extra
	for s in SnackPatch.rules()["snacks"]:
		each = each and got.has(s) and int(Save.d["crops"].get(s, 0)) == int(before.get(s, 0)) + 1
	ok(each, "after its timer it yields the four snacks, one each, the season's and a rotating extra: %s" % str(got))
	ok(SnackPatch.harvest(Save.d, late).is_empty(), "picked, it starts over")

## A save's first batch (the starter gift) is ripe at first_grow_secs (60), the second only at grow_secs (480).
func _first_batch() -> void:
	Save.d = _save()
	HomeLayout.ensure(Save.d)
	var l := HomeLayout.of(Save.d)
	var e := {"u": HomeLayout._next_uid(l), "id": SnackPatch.ID, "x": 40, "z": 30, "r": 0, "t": 1000.0}
	(l["deco"] as Array).append(e)
	var first := float(SnackPatch.rules()["first_grow_secs"])
	var grow := float(SnackPatch.rules()["grow_secs"])
	ok(first == 60.0 and grow == 480.0 and int(Save.d["snack_picks"]) == 0,
			"a new save: first batch 60 s, later ones 480 s, none picked")
	ok(not SnackPatch.ripe(e, 1000.0 + first - 1.0) and SnackPatch.ripe(e, 1000.0 + first),
			"first batch: not ripe at 59 s, ripe at 60 s")
	ok(not SnackPatch.harvest(Save.d, 1000.0 + first).is_empty() and int(Save.d["snack_picks"]) == 1,
			"picking the first batch counts one")
	var t2: float = float(e["t"])
	ok(not SnackPatch.ripe(e, t2 + grow - 1.0) and SnackPatch.ripe(e, t2 + grow),
			"second batch: not ripe at 479 s, ripe at 480 s")
	ok(SnackPatch.ripe(e, t2 + 60.0) == false, "second batch: not ripe at 60 s")
	var old := _save()
	old.erase("snack_picks")
	var keep: Dictionary = Save.d
	Save.d = old
	ok(is_equal_approx(SnackPatch.grow_secs(), grow), "an older save with no counter keeps 480 s")
	var f := FileAccess.open(OLD_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.load_from(OLD_SAVE)
	DirAccess.remove_absolute(OLD_SAVE)
	ok(int(Save.d.get("snack_picks", 0)) >= 1 and is_equal_approx(SnackPatch.grow_secs(), grow),
			"loading an older save file (no counter) keeps 480 s, no second starter gift")
	Save.d = keep

## Every lean type picks with exactly one crunch texture, and the start garden's snacks do not all share one.
func _textures() -> void:
	var typed := {}
	for t in SnackPatch.rules()["pick_textures"]:
		for ty in SnackPatch.rules()["pick_textures"][t]:
			typed[ty] = int(typed.get(ty, 0)) + 1
	var types: Array = Content.rules("lean")["types"].keys()
	ok(types.all(func(ty): return typed.get(ty, 0) == 1) and typed.size() == types.size(),
			"every lean type is in exactly one pick texture")
	var apart := {}
	for sn in SnackPatch.rules()["snacks"]:
		apart[SnackPatch.texture(String(sn))] = true
	ok(apart.size() >= 2, "the start garden's snacks do not all crunch alike: %s" % str(apart.keys()))

## On Kitewind Ridge the patch grows the ridge's four types (Flying, Electric, Fairy, Sound), crops and foods alike.
func _ridge() -> void:
	Save.d = _save()
	HomeLayout.ensure(Save.d)["theme"] = "ridge"
	var types := {}
	for s in SnackPatch.zone_snacks(Save.d):
		types[Lean.key_of(String(s))] = true
	var ridge_types := ["flying", "electric", "fairy", "sound"]
	ok(types.size() == 4 and ridge_types.all(func(t): return types.has(t)),
			"ridge: the patch grows Flying, Electric, Fairy and Sound snacks: %s" % str(SnackPatch.zone_snacks(Save.d)))
	var l := HomeLayout.of(Save.d)
	var e := {"u": HomeLayout._next_uid(l), "id": SnackPatch.ID, "x": 40, "z": 30, "r": 0,
			"t": Time.get_unix_time_from_system() - float(SnackPatch.rules()["grow_secs"]) - 1.0}
	(l["deco"] as Array).append(e)
	var got := SnackPatch.harvest(Save.d, Time.get_unix_time_from_system())
	var each := got == SnackPatch.snacks(Save.d)      # its list, plus the season snack
	for s in got:
		each = each and Econ.pantry(String(s)) == 1
	ok(each, "ridge: a ripe patch puts one of each in the pantry: %s" % str(got))
	ok(BaseFeed.pantry({"likes": {"food": "chimebun"}}) == "chimebun" and BaseFeed.pantry({"likes": {}}) == "puffcorn",
			"ridge: a hungry Boki eats from that pantry: its favourite, else the first it does not hate")
	ok(SnackPatch.model(e).get_child_count() > 4, "ridge: the ripe patch model shows the snacks")

func _in_the_garden() -> void:
	Save.d = _save()
	HomeLayout.ensure(Save.d)
	var l := HomeLayout.of(Save.d)
	var e := {"u": HomeLayout._next_uid(l), "id": SnackPatch.ID, "x": 40, "z": 30, "r": 0,
			"t": Time.get_unix_time_from_system() - float(SnackPatch.rules()["grow_secs"]) - 1.0}
	(l["deco"] as Array).append(e)
	l["inv"].erase(SnackPatch.ID)
	var home = await main._hb_home()
	var t0 := CheckClock.own_msec()      # the home builds its UI in frame slices: CPU work, not game time
	while home.panel_host == null and CheckClock.own_msec() - t0 < 60000:
		await main.get_tree().process_frame
	home._close_panel()
	var c := HomeLayout.deco_center(e)
	home.ppos = c + Vector3(4.0, 0, 0)
	home.hsp.tick(1.0)
	var heard := GardenSfx.heard.duplicate()
	ok(int(heard.get("garden_snack_ripe", 0)) == 1, "it ripens while you are in the zone: one soft chime")
	var none: bool = (Save.d["crops"] as Dictionary).get("emberberry", 0) == _save()["crops"].get("emberberry", 0)
	ok(none, "ripe, walking past does not pick it")
	home.ppos = c
	home.hsp.tick(1.0)
	ok(int(GardenSfx.heard.get("garden_snack_ripe", 0)) == 1, "standing ripe, no second chime and none for the pick-up")
	await main.get_tree().create_timer(0.6).timeout
	var all := (SnackPatch.rules()["snacks"] as Array).all(func(s): return int(Save.d["crops"].get(s, 0)) >= 1)
	var now := Time.get_unix_time_from_system()
	ok(all and not SnackPatch.ripe(SnackPatch.entry(Save.d), now), "walking over the ripe patch picks all four")
	var want := {}
	for sn in SnackPatch.snacks(Save.d):
		want["garden_snack_" + SnackPatch.texture(String(sn))] = true
	var once := true
	for cue_name in ["crisp", "juicy", "hard", "soft"]:
		var n := int(GardenSfx.heard.get("garden_snack_" + cue_name, 0)) - int(heard.get("garden_snack_" + cue_name, 0))
		once = once and n == (1 if want.has("garden_snack_" + cue_name) else 0)
	ok(once and want.size() > 1, "the pick-up crunches once for each texture in the batch: %s" % str(want.keys()))
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
