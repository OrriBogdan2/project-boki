extends RefCounted
## --vet-check: the vet booth (scripts/home/vet_booth.gd). The hub template and an older hub both hold one booth by
## the market stall; the check-up reads health, likes and mood; a cure costs gems and only works on a weak or sick
## Boki; on the island you open it from within reach only. Never touches the real save.

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("VET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _save(gems: int) -> Dictionary:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Care.ensure(k)
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["gems"] = gems
	d["tutorial"] = {"hatched": true, "intro": true}
	return d


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	_hub()
	_read()
	await _on_the_island()
	print("VET DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _booths(lay: Dictionary) -> int:
	return (lay["deco"] as Array).filter(func(e): return String(e["id"]) == VetBooth.ID).size()


func _hub() -> void:
	var fresh := HubLayout.template()
	ok(_booths(fresh) == 1, "a new hub has one vet booth")
	var old := HubLayout.template()
	old["deco"] = (old["deco"] as Array).filter(func(e): return String(e["id"]) != VetBooth.ID)
	Save.d = _save(0)
	Save.d["hub_layout"] = old
	var shown := HubLayout.island()["layout"] as Dictionary
	ok(_booths(shown) == 1 and _booths(HubLayout.island()["layout"]) == 1, "an older hub gets the booth once")
	var stall: Dictionary = (shown["deco"] as Array).filter(func(e): return String(e["id"]) == "market_stall")[0]
	var booth: Dictionary = (shown["deco"] as Array).filter(func(e): return String(e["id"]) == VetBooth.ID)[0]
	var apart := HomeLayout.deco_center(stall).distance_to(HomeLayout.deco_center(booth))
	ok(apart > 2.0 and apart < 5.0, "the booth stands beside the stall, %.1f m from it" % apart)
	var cells: Array = HomeLayout.deco_cells(booth)
	var clash := (shown["deco"] as Array).any(
		func(e): return e != booth and HomeLayout.deco_cells(e).any(func(c): return cells.has(c))
	)
	ok(not clash, "the booth's tiles are clear of every other fixture")


func _read() -> void:
	var rec := Save.new_kin("zapple", "Pip")
	Care.ensure(rec)
	var well := VetBooth.read(rec)
	ok(well["health"] == "In good shape" and not well["sick"], "a fed Boki reads: %s" % well["health"])
	ok(String(well["likes"]).contains(Care.food_name(String(rec["likes"]["food"]))), "the likes line names its food")
	rec["starve"] = (Care.STARVE["weak"] + 0.5) * 3600.0
	ok(VetBooth.read(rec)["health"] == "Weak from hunger" and VetBooth.read(rec)["sick"], "weak is read as weak")
	rec["starve"] = (Care.STARVE["sick"] + 0.5) * 3600.0
	ok(VetBooth.read(rec)["health"] == "Sick from hunger", "sick is read as sick")
	var words := {}
	for joy in [95.0, 60.0, 40.0, 5.0]:
		words[VetBooth.mood(joy)] = true
	ok(words.size() == 4, "four joy levels give four mood words: %s" % str(words.keys()))


func _on_the_island() -> void:
	Save.d = _save(50)
	HomeLayout.new_fs(Save.d, 5)
	var home = await main._hb_home()
	var t0 := CheckClock.own_msec()
	while (home.building or home.panel_host == null) and CheckClock.own_msec() - t0 < 60000:
		await main.get_tree().process_frame
	home._close_panel()
	var rec: Dictionary = home.kins[0]["rec"]
	_cure(home, rec)
	rec["starve"] = (Care.STARVE["weak"] + 1.0) * 3600.0
	ok(VetBooth.find(home, Vector2.ZERO).is_empty(), "no booth on this island: nothing to open")
	var c: Vector3 = home.world.free_spot_near(HomeLayout.LANDING + Vector3(5, 0, 3), [], 1.0)
	var e := {"id": VetBooth.ID, "u": 990004, "x": int(c.x), "z": int(c.z), "r": 0}
	(HomeLayout.of(Save.d)["deco"] as Array).append(e)
	home.hb._sync_deco()
	var mid := HomeLayout.deco_center(e)
	ok(VetBooth.find(home, Vector2(mid.x, mid.z))["kind"] == "vet", "within reach it offers the check-up")
	ok(VetBooth.find(home, Vector2(mid.x + VetBooth.REACH + 0.5, mid.z)).is_empty(), "out of reach it does not")
	home.ppos = Vector3(mid.x, 0, mid.z + 1.0)  # walk up to it: home.gd's own interact scan and prompt
	home._find_interact()
	ok(home.interact.has("vet"), "walking up, the island's interact scan picks the booth (via HomeEcon)")
	ok(home._label_for(home.interact) == VetBooth.label(), "the prompt reads: %s" % home._label_for(home.interact))
	home._use(home.interact)
	var buttons: Array = home.panel_host.find_children("*", "Button", true, false)
	var cure_btn: Button = null
	for b in buttons:
		if (b as Button).text.begins_with("Cure"):
			cure_btn = b
	ok(cure_btn != null and not cure_btn.disabled, "the panel lists the sick Boki with a Cure button")
	cure_btn.pressed.emit()
	ok(not Care.ailing(rec) and int(Save.d["gems"]) == 50 - VetBooth.cure_cost(), "pressing it cures and charges")
	home.queue_free()
	await main.get_tree().process_frame


## The cure on the island's own Boki: refused when well or short of gems, charged and healed when paid.
func _cure(home: Node, rec: Dictionary) -> void:
	Save.d["gems"] = VetBooth.cure_cost() - 1
	ok(
		VetBooth.cure_why(rec) == "Nothing to cure" and not VetBooth.cure(home, rec),
		"a well Boki is not cured or charged"
	)
	rec["starve"] = (Care.STARVE["sick"] + 1.0) * 3600.0
	ok(
		not VetBooth.cure(home, rec) and Care.ailing(rec) and int(Save.d["gems"]) == VetBooth.cure_cost() - 1,
		"one gem short: refused, still sick, nothing charged"
	)
	Save.d["gems"] = VetBooth.cure_cost() + 3
	ok(
		VetBooth.cure(home, rec) and not Care.ailing(rec) and int(Save.d["gems"]) == 3,
		"paid: cured and charged %d gems" % VetBooth.cure_cost()
	)
	Save.d["gems"] = 50
