extends RefCounted
## --food-journal-check: a food's effect shows "?" until any Boki is fed it once (FoodJournal), then
## for every Boki; kept in the save; an old save loads with the foods already fed known.
## Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("FOODJOURNAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var a := Save.new_kin("zapple", "Pip")
	var b := Save.new_kin("zapple", "Bo")
	Save.d["roster"] = [a, b]
	var fresh_q := true
	for f in Care.FOODS.keys() + Data.CROPS.keys():
		if FoodJournal.line(f) != "Effect: ?": fresh_q = false
	ok(fresh_q, "a fresh save shows ? for every food")
	for rec in [a, b]:
		rec["needs"]["food"] = 20.0
	var food := "tonicbrew" if a["likes"]["hates"] != "tonicbrew" else "kibble"
	var res := Care.feed(a, food)
	ok(res["ok"] and res["learned"], "the first feed reveals it")
	ok(FoodJournal.line(food) == "Effect: " + String(Care.FOODS[food]["desc"]), "the line now reads the real effect")
	ok(FoodJournal.known(food) and not FoodJournal.known("sweetbun"), "only the fed food is revealed")
	ok(not Care.feed(b, food)["learned"], "a second Boki learns nothing new: it was already known for every Boki")
	var hated := String(b["likes"]["hates"])
	Care.feed(b, hated)
	ok(not FoodJournal.known(hated), "a food a Boki refuses stays a ?")
	var crop := String(Data.CROPS.keys()[0])
	var line_before := FoodJournal.line(crop)
	FoodJournal.learn(crop)
	var revealed := FoodJournal.line(crop) == "Effect: " + FoodJournal.effect(crop)
	ok(line_before == "Effect: ?" and revealed, "a crop reveals the same way")
	# the save keeps it
	var back: Dictionary = JSON.parse_string(JSON.stringify(Save.d))
	ok((back["foods_fed"] as Array).has(food) and (back["foods_fed"] as Array).has(crop), "it is in the save file")
	# an old save, no journal field: foods already fed count as known
	var old := Save.fresh()
	old.erase("foods_fed")
	var oldrec := Save.new_kin("zapple", "Old")
	oldrec["known"] = ["food"]
	oldrec["memory"] = [{"m": 1, "kind": "fed", "text": "was fed %s by you" % Care.food_name("sweetbun").to_lower()}]
	old["roster"] = [oldrec]
	FoodJournal.migrate(old)
	var got: Array = old["foods_fed"]
	var loved_known := got.has(String(oldrec["likes"]["food"])) and got.has("sweetbun")
	ok(loved_known, "an old save: a found-out favourite and a remembered meal count as known")
	var path := "user://food_journal_old.json"
	old.erase("foods_fed")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.load_from(path)
	DirAccess.remove_absolute(path)
	ok((Save.d["foods_fed"] as Array).has("sweetbun"), "loading that old save file keeps the fed food known")
	var kept := {"foods_fed": ["kibble"], "roster": [oldrec]}
	FoodJournal.migrate(kept)
	ok((kept["foods_fed"] as Array) == ["kibble"], "a save that has the field is left alone")
	Save.d = Save.fresh()
	print("FOOD JOURNAL CHECK DONE, failures: ", bad)
	m.get_tree().quit()
