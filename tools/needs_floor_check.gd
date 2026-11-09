extends RefCounted
## --needs-floor-check: absence never punishes (briefs/design/GARDEN.md section 2). A Boki left with
## nothing to eat for days ends up sulky (low joy, no toys) and never sick, weaker or dead, and one
## meal plus a pet brings it round. Old saves with a long starve clock load as sulky too.
## Prints NEEDS ok/FAIL lines and "NEEDS DONE, failures: N".

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("NEEDS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _hungry(uid: String, hours_away: float) -> Dictionary:
	var r := Save.new_kin("cindle", uid)
	Care.ensure(r)
	r["needs"] = {"food": 70.0, "energy": 80.0, "joy": 70.0, "clean": 75.0}
	r["needs_t"] = Time.get_unix_time_from_system() - hours_away * 3600.0
	r.erase("starve")
	return r

func run(host: Node) -> void:
	Save.no_write = true
	var save0 := Save.d
	Save.d = Save.fresh()
	Save.d["feeders"] = []
	Save.d["items"]["kibble"] = 0
	var away := _hungry("Away", 72.0)
	var calm := _hungry("Calm", 0.0)
	Save.d["roster"] = [away]
	var ev := Econ.catch_up_all()
	ok(Care.starve_stage(away) == "sulky", "72 h away with nothing to eat: sulky (%.0f h)" % Care.starve_h(away))
	var alive: bool = Save.d["roster"].has(away) and Econ.graves().is_empty()
	ok(alive and not ev.any(func(e): return e["kind"] == "died"), "... never dead")
	var joy := Care.need(away, "joy")
	ok(Care.condition_name(away) == "Sulky" and joy <= Care.SULKY_JOY, "... shown as Sulky, joy %d" % int(joy))
	var notice: bool = ev.size() == 1 and ev[0]["kind"] == "starving" and ev[0]["stage"] == "sulky"
	ok(notice, "... one gentle notice, no other state")
	ok(Care.STARVE_INFO.keys() == ["starving", "sulky"], "... no sick, weak or refuse stage")
	ok(Work.why_not(away) != "" and Work.can_work(calm), "... a sulking Boki skips chores")
	Care.tick(away, 3600.0 * 10.0)
	var tired := Care.need(away, "energy") < 80.0
	ok(Care.starve_stage(away) == "sulky" and tired, "... ten more hours: still sulky, energy moves")
	var twin := away.duplicate(true)
	twin.erase("starve")
	ok(Care.match_mods(away) == Care.match_mods(twin), "... a sulky Boki is no weaker on a run")
	var tr0 := float(away["trust"])
	Care.starve_step(away, 3600.0 * 20.0, 3600.0 * 20.0)
	ok(float(away["trust"]) == tr0, "... trust is not eaten away by absence")
	# one visit: a meal and a pet
	var res := Care.feed(away, "kibble")
	Care.change(away, "joy", 5.0)
	var back: bool = res["ok"] and Care.starve_stage(away) == "" and Care.need(away, "joy") > Care.SULKY_JOY
	ok(back, "one feeding and a pet bring it back (joy %d)" % int(Care.need(away, "joy")))
	# an old save with a sick (or dead) Boki loads as sulky
	for h in [31.0, 40.0, 100.0]:
		var old := _hungry("Old", 0.0)
		old["starve"] = h * 3600.0
		old["needs"]["food"] = 0.0
		Save.d["roster"] = [old]
		var oev := Econ.check_starving()
		var kept: bool = Save.d["roster"].has(old) and oev.size() == 1
		ok(Care.starve_stage(old) == "sulky" and kept, "old save, %d h starving: loads as sulky, stays" % int(h))
	Save.d = save0
	print("NEEDS DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)
