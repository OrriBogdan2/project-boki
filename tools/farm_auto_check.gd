extends RefCounted
## --farm-auto-check: farming is optional (FarmAuto, Work.JOBS). A day of Auto-farm yields crops,
## fewer than the same day farmed by hand; the offline catch-up stops at Work.AWAY_MAX (8h); the
## Auto-farm toggle survives a save round trip and a v11 save migrates with it off; Boki can be put on
## any farm job, and selling is opt-in. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("FARMAUTO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## A fresh farm: 6 plots, plenty of seeds, one hard-working Boki.
func _farm() -> Dictionary:
	var d := Save.fresh()
	Save.d = d
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["plot_cap"] = 6
	d["plots"] = []
	for i in 6: d["plots"].append({"crop": "", "stage": 0, "care": 0, "wt": 0.0})
	d["seeds"] = {"puffcorn": 200, "sunroot": 200}
	d["crops"] = {}
	Work.ensure()
	var r := Save.new_kin("puddlet", "Drip")
	r.merge({"trust": 60.0, "level": 5}, true)
	Care.ensure(r)
	for n in Care.NEEDS: r["needs"][n] = 100.0
	d["roster"] = [r]
	d["active"] = r["uid"]
	return d

func _sum(got: Dictionary) -> int:
	var n := 0
	for c in got: n += int(got[c])
	return n

func run(main: Node) -> void:
	Save.no_write = true
	var all := {"water": true, "harvest": true, "replant": true}
	# ---------------------------------------------------------------- 1. a day of Auto-farm vs by hand
	_farm()
	var hand := _sum(FarmAuto.grow(86400.0, all, 1.0))
	_farm()
	var auto := _sum(FarmAuto.grow(86400.0, all, FarmAuto.EFF))
	ok(auto > 0 and auto < hand, "a day of Auto-farm picks crops, fewer than by hand (%d < %d)" % [auto, hand])
	ok(auto >= int(floor(hand * FarmAuto.EFF)) - 1,
			"Auto-farm keeps about %d%% of hand yield (%d of %d)" % [int(FarmAuto.EFF * 100), auto, hand])
	_farm()
	ok(_sum(FarmAuto.grow(86400.0, {}, FarmAuto.EFF)) == 0, "no Boki on the jobs, nothing grows or gets picked")
	var d := _farm()
	d["crops"] = {"puffcorn": FarmAuto.KEEP + 4}
	var g0 := int(d["gems"])
	var sold: Array = FarmAuto.sell(10)
	var by_hand := 4 * FarmAuto.hand_gain("puffcorn")
	ok(int(sold[0]) == 4 and int(d["crops"]["puffcorn"]) == FarmAuto.KEEP,
			"selling only takes the surplus over %d" % FarmAuto.KEEP)
	ok(int(sold[1]) > 0 and int(sold[1]) < by_hand and int(d["gems"]) == g0 + int(sold[1]),
			"a Boki sells for less than you would by hand (%d < %d gems)" % [int(sold[1]), by_hand])
	# ---------------------------------------------------------------- 2. the offline cap
	ok(is_equal_approx(Work.AWAY_MAX, 28800.0), "offline progress counts up to 8 hours")
	d = _farm()
	FarmAuto.set_on(true)
	var t0 := 1.0e9
	Work.ensure()["seen"] = t0
	Work.catch_up(t0 + 8 * 3600.0)
	var eight := (d["crops"] as Dictionary).duplicate()
	d = _farm()
	FarmAuto.set_on(true)
	Work.ensure()["seen"] = t0
	var lines := Work.catch_up(t0 + 3 * 86400.0)
	ok(_sum(eight) > 0 and d["crops"] == eight, "three days away make what 8 hours do (%d crops)" % _sum(eight))
	ok(lines.any(func(l): return "picked by your Boki" in String(l)),
			"the 'while you were away' note says what was picked")
	d = _farm()
	Work.ensure()["seen"] = t0
	Work.catch_up(t0 + 8 * 3600.0)
	ok(_sum(d["crops"]) == 0, "with Auto-farm off and no Boki put on a job, nothing is picked while away")
	# ---------------------------------------------------------------- 3. the toggle persists
	d = _farm()
	FarmAuto.set_on(true)
	var back = JSON.parse_string(JSON.stringify(d))
	Save.d = back
	ok(FarmAuto.on(), "the Auto-farm toggle survives a save round trip")
	var old := _farm()
	old["v"] = 11
	old["work"].erase("auto")
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION and old["work"]["auto"] == false,
			"a v11 save migrates to v%d with Auto-farm off" % Save.VERSION)
	# ---------------------------------------------------------------- 4. putting Boki on jobs
	d = _farm()
	var rec: Dictionary = d["roster"][0]
	ok(Work.JOBS.size() == 8, "eight farm jobs: %s" % ", ".join(Work.JOBS.keys()))
	Work.set_pin(rec, "harvest")
	var only := Work.takes_kind(rec, "forage", "harvest") and not Work.takes_kind(rec, "tide", "water")
	ok(Work.pin(rec) == "harvest" and only, "a Boki put on Harvest harvests and nothing else")
	Work.set_pin(rec, "")
	ok(not Work.takes_kind(rec, "haul", "sell"), "selling is opt-in: a free Boki doesn't sell your crops")
	FarmAuto.set_on(true)
	var both := Work.takes_kind(rec, "haul", "sell") and Work.takes_kind(rec, "forage", "harvest")
	ok(both, "under Auto-farm a free Boki sells surplus and harvests")
	print("FARMAUTO DONE, failures: ", bad)
	main.get_tree().quit()
