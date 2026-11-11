extends RefCounted
## --raising-check: one Boki raised at home, never taken on an expedition, through farm days. Care
## builds trust once a farm day per kind (Care.care_day, content/rules/care.json care_day_s), so a
## stay-at-home Boki keeps growing closer; repeating the same care in one day adds no trust and no
## duplicate memory; old saves drop the once-per-expedition stamps. Fetch trains Speed. Meals lean
## its colour on the spot (Evo.eat, Evo.lean) and the last few meals decide it. A new bond rank
## plays its moment once (KinBondMoment); the rank a Boki arrives with doesn't. Home after an hour
## away, it runs over to say hello (KinWelcome); after a minute it doesn't. Never touches the real
## save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("RAISING %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _new_save() -> Dictionary:
	var d := Save.fresh()
	var first := Save.new_kin("cindle", "Ember")
	first["starter"] = true
	d["roster"].append(first)
	d["active"] = first["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	Save.d = d
	HomeLayout.ensure(d)
	return first

## Moves every care stamp back a whole farm day, as if one had passed.
func _next_day(rec: Dictionary) -> void:
	var day := float(Content.rules("care")["care_day_s"])
	for kind in rec.get("care_day", {}):
		rec["care_day"][kind] = float(rec["care_day"][kind]) - day - 1.0

func _memories(rec: Dictionary, kind: String) -> int:
	return (rec["memory"] as Array).filter(func(e): return e["kind"] == kind).size()

func _old_save_stamps() -> void:
	var rec := Save.new_kin("puddlet")
	for old in ["pet_m", "played", "fed_m", "trained_m", "talked"]:
		rec[old] = 3
	Care.ensure(rec)
	ok(not rec.has("pet_m") and not rec.has("played") and not rec.has("talked"),
		"an old save's once-per-expedition stamps are dropped on load")

## Play is practice: a game of fetch trains Speed while it has the energy, not when it's worn out.
func _fetch_trains(home, k: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	rec["needs"]["energy"] = 80.0
	var sp0 := int(rec["stats"]["speed"])
	home._play_with_kin(k)
	for i in 600:
		if not k.has("fetch"): break
		home._move_kin(0.05)
	ok(not k.has("fetch") and int(rec["stats"]["speed"]) == sp0 + 1,
		"a finished game of fetch trains Speed (%d -> %d)" % [sp0, int(rec["stats"]["speed"])])
	rec["needs"]["energy"] = Care.PLAY_TRAIN_ENERGY - 5.0
	home._play_with_kin(k)
	for i in 600:
		if not k.has("fetch"): break
		home._move_kin(0.05)
	ok(not k.has("fetch") and int(rec["stats"]["speed"]) == sp0 + 1,
		"a worn-out Boki plays but doesn't learn (%d)" % int(rec["stats"]["speed"]))

func _body_col(k: Dictionary) -> Color:
	var mats: Array = (k["node"] as Node3D).get_meta("mats", [])
	return (mats[0] as ShaderMaterial).get_shader_parameter("albedo")

## Food is the quick lever: two Emberberries show on the model at once, and a run of another food
## turns it the other way.
func _meals_lean(home, k: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	rec["likes"]["hates"] = "puffcorn"
	Save.d["crops"]["emberberry"] = 2
	var c0 := _body_col(k)
	var fierce: Color = Evo.AFF["fierce"]["tint"]
	var aff0 := float(rec["aff"]["fierce"])
	for meal in 2:
		rec["needs"]["food"] = 30.0
		home._care_feed(rec, "emberberry")
		await main.get_tree().create_timer(1.6).timeout
	var c1 := _body_col(k)
	var ln := Evo.lean(rec)
	ok(String(ln[0]) == "fierce" and float(rec["aff"]["fierce"]) == aff0 + 2.0 * Evo.FOOD_AFF,
		"two Emberberries lean it Fierce (%.0f%%) and still grow the affinity" % (100.0 * float(ln[1])))
	var d0 := Vector3(c0.r - fierce.r, c0.g - fierce.g, c0.b - fierce.b).length()
	var d1 := Vector3(c1.r - fierce.r, c1.g - fierce.g, c1.b - fierce.b).length()
	ok(d1 < d0 - 0.02, "and the model on the farm turns toward the Fierce colour at once (%.3f -> %.3f)" % [d0, d1])
	for meal in 4:
		Evo.eat(rec, "tidebloom")
	ok(String(Evo.lean(rec)[0]) == "swift" and float(rec["lean"]["fierce"]) < 2.0 * Evo.FOOD_AFF,
		"four Tideblooms later the last meals decide: it leans %s" % String(Evo.lean(rec)[0]))
	ok(Evo.eat(rec, "kibble") == "" and String(Evo.lean(Save.new_kin("cindle"))[0]) == "",
		"plain food leaves the lean alone, and a new Boki has none")

## Home after an hour away: it notices you, runs over and says hello. A minute away: nothing.
func _welcome(home, k: Dictionary) -> void:
	k["pos"] = home.ppos + Vector3(7.0, 0, 0)
	(k["node"] as Node3D).position = k["pos"]
	await main.get_tree().create_timer(KinWelcome.START_S + 0.2).timeout
	var noticed: bool = k.has("called_t") and k.has("welcome")
	for i in 200:
		if not k.has("called_t"): break
		home._move_kin(0.05)
	var dist := Vector2(k["pos"].x - home.ppos.x, k["pos"].z - home.ppos.z).length()
	var said: bool = k.has("say") and (k["say"] as Label3D).visible
	ok(noticed and dist < 2.1 and said, "home after an hour away it runs over and says hello (%.1f m)" % dist)
	KinWelcome.start(home, 60.0)
	await main.get_tree().create_timer(KinWelcome.START_S + 0.2).timeout
	ok(not k.has("called_t"), "back from a minute in a menu: no rush")

## The expedition panel's line: good care reads as a bonus, a run-down Boki as a cost.
func _care_line(rec: Dictionary) -> void:
	var kept: Dictionary = (rec["needs"] as Dictionary).duplicate()
	rec["needs"] = {"food": 95.0, "energy": 95.0, "joy": 95.0, "clean": 95.0}
	var good := Care.care_line(rec)
	rec["needs"] = {"food": 10.0, "energy": 10.0, "joy": 10.0, "clean": 10.0}
	var poor := Care.care_line(rec)
	rec["needs"] = kept
	ok(good.contains("+10% health") and poor.contains("-18% damage"),
		"the expedition panel says what raising does: \"%s\" / \"%s\"" % [good, poor])

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_old_save_stamps()
	var rec := _new_save()
	rec["needs_t"] = Time.get_unix_time_from_system() - 3600.0
	var home = await main._hb_home()
	var k: Dictionary = home._kin_entry(rec)
	ok(not k.is_empty(), "the Boki is out on the farm")
	await _welcome(home, k)
	KinBondMoment.tick(home)
	ok(home.panel_open == "" and int(rec.get("bond_seen", -1)) == Care.bond_index(rec),
		"the rank it arrives with is where it starts: no moment (%s)" % Care.bond(rec)[1])
	var t0 := float(rec["trust"])
	home._pet_kin(k)
	var t1 := float(rec["trust"])
	ok(t1 > t0, "petting builds trust (%.1f -> %.1f)" % [t0, t1])
	k["pet_ok"] = 0.0
	home._pet_kin(k)
	ok(is_equal_approx(float(rec["trust"]), t1),
		"petting again the same farm day adds no trust (%.1f)" % float(rec["trust"]))
	var pets := _memories(rec, "petted")
	_next_day(rec)
	home._pet_kin(k)
	var pets2 := _memories(rec, "petted")
	ok(float(rec["trust"]) > t1,
		"the next farm day petting builds trust again, no expedition needed (%.1f)" % float(rec["trust"]))
	ok(pets == 1 and pets2 == 1, "the same care before the next expedition is one memory (%d, %d)" % [pets, pets2])
	_fetch_trains(home, k)
	_care_line(rec)
	await _meals_lean(home, k)
	# a week of farm days with the usual care and no expeditions: it grows Close
	for day in 7:
		_next_day(rec)
		home._pet_kin(k)
		Care.care_day(rec, "talked")
		if Care.care_day(rec, "played"):
			Save.remember(rec, "played", "played fetch with you on the farm", 1.5)
	ok(int(Save.d["matches"]) == 0 and Care.bond_index(rec) >= 2,
		"a week of farm days of care, no expedition: %s (trust %.0f)" % [Care.bond(rec)[1], float(rec["trust"])])
	KinBondMoment.tick(home)
	ok(home.panel_open == "Ember is now Close" and int(rec["bond_seen"]) == 2,
		"reaching Close plays its moment: \"%s\"" % home.panel_open)
	home._close_panel()
	KinBondMoment.tick(home)
	ok(home.panel_open == "", "and only once")
	home.queue_free()
	print("RAISING DONE, failures: %d" % bad)
	main.get_tree().quit()
