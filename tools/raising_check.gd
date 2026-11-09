extends RefCounted
## --raising-check: one Boki raised at home, never taken on an expedition, through farm days. Care
## builds trust once a farm day per kind (Care.care_day, content/rules/care.json care_day_s), so a
## stay-at-home Boki keeps growing closer; repeating the same care in one day adds no trust and no
## duplicate memory; old saves drop the once-per-expedition stamps. Never touches the real save.

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

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_old_save_stamps()
	var rec := _new_save()
	var home = await main._hb_home()
	var k: Dictionary = home._kin_entry(rec)
	ok(not k.is_empty(), "the Boki is out on the farm")
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
	# a week of farm days with the usual care and no expeditions: it grows Close
	for day in 7:
		_next_day(rec)
		home._pet_kin(k)
		Care.care_day(rec, "talked")
		if Care.care_day(rec, "played"):
			Save.remember(rec, "played", "played fetch with you on the farm", 1.5)
	ok(int(Save.d["matches"]) == 0 and Care.bond_index(rec) >= 2,
		"a week of farm days of care, no expedition: %s (trust %.0f)" % [Care.bond(rec)[1], float(rec["trust"])])
	home.queue_free()
	print("RAISING DONE, failures: %d" % bad)
	main.get_tree().quit()
