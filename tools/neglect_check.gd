extends RefCounted
## --neglect-check: no natural death. 60 days with nothing to eat never kills a Boki (it ends up sick,
## and recovers with food), neglect catch-up and the live tick are both capped, and a Boki that already
## died of neglect is revived weak by the load-time pass (Econ.revive_neglected), once. A Boki lost
## another way stays in its grave. Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("NEGLECT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	ok(not Care.natural_death(), "content/rules/neglect.json: natural_death is false")
	_offline()
	_tick()
	_revive()
	print("NEGLECT DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

func _starved_kin(nm: String) -> Dictionary:
	var r := Save.new_kin("zapple", nm)
	Care.ensure(r)
	r["needs"] = {"food": 0.0, "energy": 50.0, "joy": 50.0, "clean": 50.0}
	r.erase("starve")
	return r

## 60 days away, in four-week-capped steps like real launches, and then one long stretch in one go.
func _offline() -> void:
	var r := _starved_kin("Pip")
	Save.d["roster"] = [r]
	Save.d["feeders"] = []
	for week in 9:
		r["needs_t"] = Time.get_unix_time_from_system() - 14.0 * 86400.0
		Econ.catch_up_all()
	ok(Save.d["roster"].has(r) and Econ.graves().is_empty(), "60 days offline, nothing to eat: alive, no grave")
	var capped := float(r["starve"]) <= Care.starve_cap_s()
	ok(Care.starve_stage(r) == "sick" and capped, "...sick, the clock held at the cap (%.0f h)" % Care.starve_h(r))
	Care.fed(r)
	r["needs"]["food"] = 80.0
	Care.starve_step(r, 3.0 * 3600.0)
	var h := Care.starve_h(r)
	ok(h < Care.STARVE["sick"], "...and a meal and a rest bring it back down (%.1f h)" % h)

func _tick() -> void:
	var r := _starved_kin("Wren")
	Save.d["roster"] = [r]
	Care.tick(r, 60.0 * 86400.0)
	var deaths := Econ.check_starving().filter(func(e): return e["kind"] == "died")
	ok(Care.starve_stage(r) == "sick" and deaths.is_empty(), "60 days in one live tick: sick, not dead")

func _revive() -> void:
	var old := Save.new_kin("zapple", "Biscuit")
	old["level"] = 7
	old["starve"] = 80.0 * 3600.0
	Save.d["roster"] = []
	Save.d["active"] = ""
	Save.d["graves"] = []
	Econ.kin_dies(old, "starved")
	var gone := Save.new_kin("zapple", "Taken")
	Econ.kin_dies(gone, "lost")
	var bare := {"uid": "x1", "name": "Bare", "species": "zapple", "level": 3, "cause": "starved"}
	Save.d["graves"].append(bare)
	Econ.ensure()
	var names: Array = Save.d["roster"].map(func(r): return String(r["name"]))
	var back := "Biscuit" in names and "Bare" in names and ("Taken" not in names)
	ok(back, "dead-by-neglect revive, the other loss stays (roster %s)" % str(names))
	var left := Econ.graves()
	ok(left.size() == 1 and String(left[0]["name"]) == "Taken", "...the neglect graves are gone")
	var b: Dictionary = Save.kin(String(old["uid"]))
	var weak := int(b.get("level", 0)) == 7 and Care.starve_stage(b) == "weak" and Care.need(b, "food") > 0.0
	ok(weak, "...weak, level kept (stage %s)" % Care.starve_stage(b))
	var told: bool = Save.d["neglect_back"] == ["Biscuit", "Bare"] and Save.d["active"] != ""
	ok(told, "...announced once, an active Boki set")
	var n := (Save.d["roster"] as Array).size()
	Econ.ensure()
	var same: bool = (Save.d["roster"] as Array).size() == n and Save.d["neglect_back"].size() == 2
	ok(same, "running it again changes nothing (idempotent)")
	Care.fed(b)
	b["needs"]["food"] = 70.0
	Care.starve_step(b, 2.0 * 3600.0)
	ok(Care.starve_stage(b) == "", "a weak Boki recovers with a meal and a little time")
