extends RefCounted
## --stat-budget-check (decision 0022): the stat cap, the 240 total, the gain bands, the expedition clamp
## (25 and 100 points give the same match_mods), loose points, and an over-cap old save. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("STATBUDGET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _rec(level: int) -> Dictionary:
	var rec := Save.new_kin("puddlet")
	rec["level"] = level
	Care.ensure(rec)
	return rec

func _train(rec: Dictionary, s: String, plays: int) -> void:
	for i in plays:
		Care.add_stat(rec, s, 1)

func _mods_equal(a: Dictionary, b: Dictionary) -> bool:
	for k in ["dmg", "hp", "speed", "cd"]:
		if not is_equal_approx(float(a[k]), float(b[k])):
			return false
	return true

func run(main: Node) -> void:
	Save.no_write = true
	ok(Care.stat_cap(_rec(1)) == 18 and Care.stat_cap(_rec(8)) == 60, "caps follow the level early")
	ok(Care.stat_cap(_rec(15)) == 100 and Care.stat_cap(_rec(100)) == 100, "the cap stops at 100, reached at level 15")
	var rec := _rec(100)
	_train(rec, "power", 50)
	ok(int(rec["stats"]["power"]) == 50, "points 1 to 50 gain in full")
	ok(Care.add_stat(rec, "power", 4) == 2, "51 to 80: a gain of 4 counts as 2")
	_train(rec, "power", 1)
	ok(StatBudget.plays_to_next(rec, "power") == 1, "after one play of half progress the next point is 1 play away")
	_train(rec, "power", 1)
	_train(rec, "power", 54)
	ok(int(rec["stats"]["power"]) == 80, "half band: 27 more points (53 to 80) take 54 plays")
	ok(StatBudget.plays_to_next(rec, "power") == 4, "81 and up: the next point is 4 plays away")
	_train(rec, "power", 3)
	ok(int(rec["stats"]["power"]) == 80, "three plays in the quarter band give nothing yet")
	_train(rec, "power", 1)
	ok(int(rec["stats"]["power"]) == 81, "the fourth play gives the point")
	_train(rec, "power", 200)
	ok(int(rec["stats"]["power"]) == 100, "a stat stops at 100")
	var t := _rec(100)
	for s in ["power", "guard", "speed"]:
		t["stats"][s] = 100
	ok(StatBudget.room(t, "focus") == 0, "300 is over: no room left for a fourth stat")
	t["stats"]["speed"] = 0
	_train(t, "focus", 300)
	ok(StatBudget.total(t) == 240 and int(t["stats"]["focus"]) == 40, "the four stop at 240 in all")
	var a := _rec(100)
	var b := _rec(100)
	a["stats"] = {"power": 25, "guard": 25, "speed": 25, "focus": 25}
	b["stats"] = {"power": 100, "guard": 100, "speed": 100, "focus": 100}
	ok(_mods_equal(Care.match_mods(a), Care.match_mods(b)), "25 and 100 points give the same match_mods")
	b["stats"]["power"] = 10
	ok(not _mods_equal(Care.match_mods(a), Care.match_mods(b)), "below 25 points still counts")
	var o := _rec(3)
	o["stats"] = {"power": 90, "guard": 90, "speed": 90, "focus": 90}
	var before: Dictionary = o["stats"].duplicate()
	ok(Care.add_stat(o, "power", 5) == 0 and o["stats"] == before, "an old save over its caps keeps all, gains none")
	o.erase("stat_frac")
	o.erase("loose")
	Care.ensure(o)
	ok(o["loose"] == 0 and o["stat_frac"] == {}, "old saves gain empty progress fields")
	var l := _rec(100)
	l["stats"]["guard"] = 85
	l["loose"] = 3
	var back := Care.add_stat(l, "guard", 1) + Care.add_stat(l, "guard", 1)
	ok(back == 3 and int(l["stats"]["guard"]) == 88, "loose points come back two a play, skipping the quarter band")
	ok(Care.add_stat(l, "guard", 1) == 0, "once the loose points are back the quarter band applies again")
	print("STATBUDGET DONE, failures: %d" % bad)
	main.get_tree().quit()
