extends RefCounted
## --train-runs-check (the stat economy, owner ruling 11-26): garden races and drills are limited runs
## (TrainRuns: a few a day, one more of each per match, banked up to a cap); a game with no run left is a
## friendly that pays nothing; a drill pays stat bites into the bag, never raw points; kills drop the bite of
## the stat their kind stands for; toys give at most day_cap points a day. Never touches the real save.

const T0 := 1800000000.0  # a fixed moment; T0 + DAY is the next garden day
const DAY := 86400.0

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("TRAINRUNS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _rec(sp: String) -> Dictionary:
	var rec := Save.new_kin(sp)
	rec["level"] = 5
	Care.ensure(rec)
	return rec


func _charges() -> void:
	var r := TrainRuns.rules()
	var daily: Dictionary = r["daily"]
	ok(
		TrainRuns.left("race", T0) == int(daily["race"]) and TrainRuns.left("drill", T0) == int(daily["drill"]),
		"a new day starts with %d races and %d drills" % [int(daily["race"]), int(daily["drill"])]
	)
	ok(TrainRuns.line("race", T0) == "Races left today: %d" % int(daily["race"]), TrainRuns.line("race", T0))
	for i in int(daily["race"]):
		TrainRuns.spend("race", T0)
	ok(
		not TrainRuns.spend("race", T0) and TrainRuns.left("race", T0) == 0,
		"spent out: no race run left, nothing goes below 0"
	)
	var added := 0
	for i in int(r["match_max_day"]) + 2:
		added += TrainRuns.after_match(T0)
	var want := int(r["match_max_day"]) * (int(r["per_match"]["race"]) + int(r["per_match"]["drill"]))
	ok(added == want, "matches earn runs, at most %d matches a day (%d charges)" % [int(r["match_max_day"]), added])
	TrainRuns.state(T0)["race"] = int(r["bank_max"]) + 3
	var next := TrainRuns.state(T0 + DAY)
	ok(
		(
			int(next["race"]) == int(r["bank_max"]) + 3
			and int(next["drill"]) >= int(daily["drill"])
			and int(next["earned"]) == 0
		),
		"the next day keeps banked runs and tops the rest up (race %d, drill %d)" % [next["race"], next["drill"]]
	)
	TrainRuns.state(T0 + DAY)["race"] = int(r["bank_max"])
	TrainRuns.after_match(T0 + DAY)
	ok(TrainRuns.left("race", T0 + DAY) == int(r["bank_max"]), "a match never banks past %d" % int(r["bank_max"]))


## A garden game with a run pays and says how many are left; with none it pays nothing and says so.
func _prizes() -> void:
	var mine := _rec("puddlet")
	var foe := _rec("puddlet")
	Save.d["roster"] = [mine, foe]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	TrainRuns.state(T0)["race"] = 1
	var res := GardenPrizes.settle("dash", mine, foe, true, T0, rng)
	var rows := GardenPrizes.rows(res)
	ok(
		res["charged"] and not (res["items"] as Array).is_empty() and TrainRuns.left("race", T0) == 0,
		"a charged win pays a prize (%d items) and uses the run" % (res["items"] as Array).size()
	)
	ok(rows.any(func(row): return String(row[0]) == "Races left today: 0"), "the card says 'Races left today: 0'")
	var bag: Dictionary = Save.d["items"].duplicate()
	var res2 := GardenPrizes.settle("dash", mine, foe, true, T0 + 60.0, rng)
	var rows2 := GardenPrizes.rows(res2)
	ok(
		not res2["charged"] and (res2["items"] as Array).is_empty() and res2["round"] == "" and Save.d["items"] == bag,
		"with no race left a win is a friendly: no prize, no cup step"
	)
	ok(
		rows2.any(func(row): return String(row[0]).begins_with("No races left today")),
		"the card says no races are left"
	)


func _drills() -> void:
	Save.d["items"] = {}
	TrainRuns.state()["drill"] = 1
	var miss := TrainRuns.pay_drill("guard", ["miss", "miss", "miss"])
	ok(not miss["charged"] and TrainRuns.left("drill") == 1, "a drill with no mark hit uses no run")
	var b: Dictionary = TrainRuns.rules()["drill_bites"]
	var want := int(b["perfect"]) + (int(b["dojo"]) if Save.has_building("dojo") else 0)
	var pay := TrainRuns.pay_drill("guard", ["great", "great", "great"])
	ok(
		pay["id"] == "shellbark_chew" and int(Save.d["items"].get("shellbark_chew", 0)) == want,
		"a perfect Guard drill puts %d Shellbark Chew in the bag: %s" % [want, pay["text"]]
	)
	var none := TrainRuns.pay_drill("guard", ["good", "good", "good"])
	ok(
		not none["charged"] and int(Save.d["items"].get("shellbark_chew", 0)) == want,
		"with no drill left it pays nothing: %s" % none["text"]
	)
	for s in Care.STATS:
		ok(
			GardenItems.bite_for(s) != "" and GardenItems.item(GardenItems.bite_for(s))["effect"]["stat"] == s,
			"%s has its stat bite (%s)" % [s, GardenItems.bite_for(s)]
		)


## What you hunt decides the stat: each kill table drops its own bite, rarely.
func _kills() -> void:
	ok(GardenItems.kill_drop("skitter", 0.0, 0) == "zipseed", "skitters drop Zipseed (Speed)")
	ok(GardenItems.kill_drop("spitter", 0.0, 0) == "hushpearl", "spitters drop Hushpearl (Focus)")
	ok(GardenItems.kill_drop("bomber", 0.0, 0) == "thumpnut", "bombers drop Thumpnut (Power)")
	ok(GardenItems.kill_drop("sentinel", 0.0, 0) == "shellbark_chew", "sentinels drop Shellbark Chew (Guard)")
	ok(
		GardenItems.kill_drop("skitter", 0.99, 0) == "" and GardenItems.kill_drop("chest", 0.0, 0) == "",
		"most kills drop no bite; tables with no chance never do"
	)
	var any: Array = GardenItems.rules()["kill_drop"]["any"]
	ok(any.has(GardenItems.kill_drop("warden", 0.0, 5)), "a warden drops any of the four bites")
	var ch: Dictionary = GardenItems.rules()["kill_drop"]["chance"]
	var exp_n := (
		40.0 * float(ch["skitter"]) + 3.0 * float(ch["sentinel"]) + 2.0 * float(ch["brute"]) + float(ch["warden"])
	)
	ok(exp_n >= 1.0 and exp_n <= 3.0, "a match of ~40 small kills and a few guards drops about %.1f bites" % exp_n)


func _toys() -> void:
	var rec := _rec("puddlet")
	var cap := int(HomeToys.rules()["day_cap"])
	ok(HomeToys.day_room(rec, T0) == cap, "toys may give %d points a day" % cap)
	HomeToys.day_used(rec, cap, T0)
	ok(
		HomeToys.day_room(rec, T0) == 0 and HomeToys.day_room(rec, T0 + DAY) == cap,
		"spent out today, the room is back tomorrow"
	)


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_charges()
	Save.d = Save.fresh()
	_prizes()
	Save.d = Save.fresh()
	_drills()
	_kills()
	_toys()
	print("TRAINRUNS DONE, failures: %d" % bad)
	main.get_tree().quit()
