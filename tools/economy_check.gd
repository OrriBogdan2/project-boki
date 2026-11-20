extends RefCounted
## --economy-check, moved out of main.gd (AGENTS.md section 2); registered in tools/check_registry.gd.

var main: Node

## Headless check for loot and kin keeping: a full backpack asks to swap, smart loot takes the best
## first, extracting fills the armory, feeders feed hungry kin (also while you're away), starving
## runs its course to a grave, and the Soul Shrine brings a kin back changed. Never touches the save.
func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var bad := [0]
	var ok := func(cond: bool, what: String) -> void:
		print("ECON %s %s" % ["ok  " if cond else "FAIL", what])
		if not cond: bad[0] += 1
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var P: Hunter = m.player
	var Q: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var at := P.pos + Vector3(0.6, 0, 0)
	# 1. a full backpack asks what to drop
	P.pack_cap = 2
	P.pack = [Loot.valuable("old_coin"), Loot.gear("vest", 1)]
	m.spawn_val(Loot.valuable("kin_idol"), at)
	var wp: Dictionary = m.wpicks[m.wpicks.size() - 1]
	Pack.take_ground(m, P, wp)
	ok.call(m.hud.swap_open() and P.pack.size() == 2 and m.wpicks.has(wp), "full backpack opens the swap window (pack %d/%d)" % [P.pack.size(), P.pack_cap])
	Pack.swap(m, P, 0, wp)      # you pick the coin to leave behind
	var ids: Array = P.pack.map(func(it): return String(it.get("id", it.get("wid", ""))))
	ok.call(ids.has("kin_idol") and not ids.has("old_coin") and m.wpicks.any(func(w): return String(w.get("val", "")) == "old_coin"), "swap drops the coin on the ground and packs the idol: %s" % str(ids))
	m.hud.close_swap()
	# better armor on the ground goes on, and the old piece goes in the pack
	P.pack_cap = 4
	P.gear[2] = {"id": "vest", "rar": 1}
	m.spawn_gear("bastion_plate", 3, at, "", false)
	Pack.take_ground(m, P, m.wpicks[m.wpicks.size() - 1])
	ok.call(String(P.gear[2]["id"]) == "bastion_plate" and P.pack.any(func(it): return String(it.get("id", "")) == "vest"), "better armor goes on, the old piece into the pack: %s" % str(P.gear[2]))
	P.welem = "fire"
	var ex := {}
	Loot.rider(P, ex, 10.0)
	ok.call(float(ex.get("burn", 0.0)) >= 5.0, "fire rider burns (%s)" % str(ex))
	P.welem = "storm"; P.el_n = 3
	var ex2 := {}
	Loot.rider(P, ex2, 10.0)
	ok.call(ex2.has("fx_hit"), "storm rider arcs on the 4th attack")
	P.welem = "fire"
	# 2. smart loot: gear on you first, then the pack, best first, never worse for better
	var gid: String = Gear.ALL.keys()[0]
	var b := {"owner": Q, "team": Q.team, "pos": P.pos, "gems": 10, "seeds": {"tidebloom": 2}, "caught": [], "belt": [], "soul_until": 0.0,
		"prog": {}, "node": null, "empty": false, "gear": [{"id": gid, "rar": 4}, {"id": "gale_mantle", "rar": 4}],
		"pack": [Loot.valuable("old_coin"), Loot.valuable("crown_shard"), Loot.gear("vest", 1), Loot.gear("windstep_boots", 2), Loot.valuable("sky_pearl")]}
	P.pack = [Loot.valuable("kin_idol")]
	P.pack_cap = 3
	P.gear = Gear.empty_slots(); P.refresh_gear()
	var g0 := P.gems
	var got := Life.smart_loot(m, P, b)
	var pv: Array = P.pack.map(func(it): return Loot.value(it))
	var left: Array = Pack._box_things(b).map(func(c): return Loot.value(c["it"]))
	var minp: int = pv.min() if not pv.is_empty() else 0
	var maxl: int = left.max() if not left.is_empty() else 0
	print("ECON  smart loot took %d: weapon=%s gear=%s pack=%s values=%s left in box=%s" % [got, P.wpn["name"], str(P.gear), str(P.pack.map(func(it): return Loot.name_of(it))), str(pv), str(left)])
	ok.call(String(P.gear[2].get("id", "")) == "gale_mantle" and not (P.gear[Gear.slot_of(gid)] as Dictionary).is_empty(), "smart loot: the best gear goes on (armor %s)" % str(P.gear[2]))
	ok.call(P.pack.size() == 3 and minp >= maxl, "smart loot: pack holds the most valuable (min %d >= best left %d)" % [minp, maxl])
	ok.call(P.gems == g0 + 10 and int(P.seeds.get("tidebloom", 0)) >= 2, "smart loot: gems and seeds taken too")
	# 3. extracting brings it all home to the armory; the loadout goes out and comes back
	Save.d["roster"] = [Save.new_kin("cindle", "Pip")]
	Save.d["active"] = Save.d["roster"][0]["uid"]
	var haul := Pack.haul(P)
	# armor salvages on arrival
	var n_arm := haul.filter(func(it): return String(it["t"]) != "val" and not Equal.salvages(it)).size()
	var out := Game.apply_result({"extracted": true, "haul": haul, "tier": 0, "gems": 5, "kin_runs": []})
	ok.call(Econ.armory().size() == n_arm and int(Save.d["valuables"].get("crown_shard", 0)) == 1, "extract: %d pieces of gear in the armory, treasure in the vault %s" % [Econ.armory().size(), str(Save.d["valuables"])])
	ok.call((out.get("haul", []) as Array).size() == haul.size(), "results list what came home (%d)" % (out.get("haul", []) as Array).size())
	ok.call(int((out.get("mats", {}) as Dictionary).get("wood", 0)) > 0 and Work.mat("wood") > 0, "extract: the haul also gives farm materials %s" % str(out.get("mats", {})))
	var best_w: Dictionary = Econ.armory().filter(func(it): return Equal.may_bring(it, 2))[0]
	Econ.set_loadout(Econ.gear_slot(best_w), String(best_w["uid"]))
	var kit := Equal.take_loadout(2)
	ok.call(kit.size() == 1 and Econ.find(String(best_w["uid"])).is_empty() and (Save.d["raid_out"] as Array).size() == 1, "loadout leaves the armory for the expedition")
	Game.apply_result({"extracted": true, "haul": kit, "tier": 0, "kin_runs": []})
	ok.call(not Econ.find(String(best_w["uid"])).is_empty() and not Econ.loadout(Econ.gear_slot(best_w)).is_empty(), "extracting brings the loadout gear back, still picked")
	Equal.take_loadout(2)
	Game.apply_result({"extracted": false, "why": "knocked out", "lost_items": [best_w], "tier": 0, "kin_runs": []})
	ok.call(Econ.find(String(best_w["uid"])).is_empty() and Econ.loadout(Econ.gear_slot(best_w)).is_empty(), "dying loses the loadout gear")
	# armor salvages on arrival now; make sure two pieces are left
	if Econ.armory().size() < 2: Save.d["armory"].append(Loot.gear("skylark_boots", 2))
	var sold := Econ.sell(String(Econ.armory()[0]["uid"]))
	var scrap := Econ.salvage(String(Econ.armory()[0]["uid"]))
	ok.call(sold > 0 and scrap > 0, "sell (%d gems) and salvage (%d scrap)" % [sold, scrap])
	m.queue_free()
	# 4. feeders: a hungry kin eats, and a filled feeder keeps kin fed while you're away
	var rec: Dictionary = Save.d["roster"][0]
	Care.ensure(rec)
	rec["likes"]["hates"] = "puffcorn"
	rec["needs"]["food"] = 20.0
	var f: Dictionary = Econ.feeders()[0]
	f["food"] = ["kibble", "kibble", "kibble"]
	var res := Econ.serve(f, rec)
	ok.call(not res.is_empty() and Care.need(rec, "food") > 45.0 and Econ.fill(f) == 2, "feeder feeds a hungry kin: food %d, %d meals left" % [int(Care.need(rec, "food")), Econ.fill(f)])
	var now := Time.get_unix_time_from_system()
	f["kind"] = "hopper"; f["food"] = []; f["auto"] = true
	Save.d["items"]["kibble"] = 14
	rec["needs"]["food"] = 70.0; rec["needs_t"] = now - 3.0 * 86400.0; rec.erase("starve")
	var ev := Econ.catch_up_all()
	ok.call(ev.is_empty() and Care.starve_h(rec) == 0.0 and Care.need(rec, "food") > 0.0, "3 days away with an auto hopper and kibble: fed (food %d, %d kibble left)" % [int(Care.need(rec, "food")), Econ.pantry("kibble")])
	# 5. starving, with nothing to eat: the timeline
	Save.d["feeders"] = []
	Save.d["items"]["kibble"] = 0
	var line: Array = []
	var died := false
	for days in [0.5, 1.0, 2.0, 4.0, 14.0]:
		var r2: Dictionary = rec.duplicate(true)
		r2["uid"] = "starve%d" % int(days * 10)
		r2["needs"] = {"food": 70.0, "energy": 80.0, "joy": 70.0, "clean": 75.0}
		r2.erase("starve")
		r2["needs_t"] = now - days * 86400.0
		Save.d["roster"] = [r2]
		var ev2 := Econ.catch_up_all()
		var st := Care.starve_stage(r2) if not ev2.any(func(e): return e["kind"] == "died") else "dead"
		died = died or st == "dead"
		line.append("%.1fd: %s (food %d, %.0fh starving, trust %d)" % [days, st if st != "" else "fine", int(Care.need(r2, "food")), Care.starve_h(r2), int(r2["trust"])])
	print("ECON  starving timeline: " + "  |  ".join(line))
	var sick: Dictionary = Save.d["roster"][0]
	var stage := Care.starve_stage(sick)
	ok.call(not died and stage == "sick",
		"natural_death off: 14 days unfed is sick at worst, never dead (%s)" % stage)
	for meal in 12:
		Care.feed(sick, "kibble")
		Care.feed(sick, "kibble")
		Care.tick(sick, 1200.0)
	ok.call(Care.starve_stage(sick) in ["", "weak", "refuse"],
		"four hours of regular meals bring it back from sick (%s, %.0fh)"
		% [Care.starve_stage(sick), Care.starve_h(sick)])
	Econ.kin_dies(sick, "starved")      # graves still come from old saves and other losses
	ok.call(Econ.graves().size() >= 1 and String(Econ.graves()[0]["cause"]) == "starved" and String(Econ.graves()[0]["name"]) == "Pip", "a grave with its name (%d graves, %d memories)" % [Econ.graves().size(), (Econ.graves()[0]["mem"] as Array).size() if Econ.graves().size() > 0 else 0])
	# 6. the Soul Shrine brings one back, changed
	var g: Dictionary = Econ.graves()[Econ.graves().size() - 1]
	ok.call(Econ.keep_soul(g) != "", "no shrine yet: can't keep a soul")
	Save.d["buildings"].append("shrine")
	Save.d["valuables"]["soul_ember"] = 1
	Save.d["gems"] = 500
	ok.call(Econ.keep_soul(g) == "" and g["soul"], "soul kept in the shrine")
	var before: Dictionary = (g["rec"] as Dictionary).duplicate(true)
	before["level"] = 6
	g["rec"]["level"] = 6; g["level"] = 6
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var back := Econ.revive(g, rng)
	var tdiff := 0.0
	for t in before["traits"]: tdiff += absf(float(before["traits"][t]) - float(back["traits"].get(t, 0.0)))
	print("ECON  revived %s %s: level %d -> %d, trust %d -> %d, traits moved %.2f, memories %d -> %d, ghost=%s, likes %s -> %s" % [back["name"], back["title"], int(before["level"]), int(back["level"]), int(before["trust"]), int(back["trust"]), tdiff, (before["memory"] as Array).size(), (back["memory"] as Array).size(), back.get("ghost", false), str(before.get("likes", {}).get("food", "")), str(back["likes"]["food"])])
	ok.call(not back.is_empty() and back["ghost"] and String(back["title"]) != "" and int(back["level"]) == 4 and tdiff > 0.05 and Save.d["roster"].has(back) and not Econ.graves().has(g) and Econ.embers() == 0, "revived kin comes back changed")
	# an old save (from before the armory and feeders) loads and gets them filled in
	var old := Save.fresh()
	for k in ["armory", "raid_out", "loadout", "valuables", "feeders", "graves", "arm_lvl", "scrap", "feeder_inv",
			"feeder_given"]:
		old.erase(k)
	var orec := Save.new_kin("zapple", "Oldie")
	orec.erase("starve")
	old["roster"] = [orec]
	Save.d = old
	Econ.ensure()
	Care.catch_up(orec)
	ok.call(Econ.armory().is_empty() and Econ.feeders().size() == 1 and Econ.graves().is_empty()
			and Econ.pack_cap() == Equal.base_pack() and Care.starve_stage(orec) == ""
			and Equal.take_loadout(0).is_empty(),
			"an old save loads: a first trough, empty armory, %d-slot backpack" % Econ.pack_cap())
	print("ECON DONE failures: %d" % bad[0])
	main.get_tree().quit()
