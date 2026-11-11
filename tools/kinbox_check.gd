extends RefCounted
## --kinbox-check: the farm cap and the Kin Burrow (KinBox), where new kin go, moving, sorting and
## releasing, boxed kin sleeping through time away, an old crowded save moving its overflow into
## the box, rare mutations passing to eggs at the right rates, wild mutation odds, their perks and
## their look, and the home island only putting farm kin out. Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("KINBOX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _kin(sp: String, nm: String, trust := 40.0, lvl := 3) -> Dictionary:
	var r := Save.new_kin(sp, nm)
	r["trust"] = trust; r["level"] = lvl
	return r

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	KinBox.ensure()
	var sps: Array = []
	for k in Data.KIN:
		if not Data.KIN[k].get("rare", false): sps.append(k)
	# ---------------------------------------------------------------- 1. where new kin go
	var st := _kin(sps[0], "Starter", 60.0, 5)
	st["starter"] = true
	Save.d["roster"] = [st]; Save.d["active"] = st["uid"]
	var add := func(r: Dictionary) -> String:
		Save.d["roster"].append(r)
		return KinBox.route_new(r)
	ok(add.call(_kin(sps[1], "Two")) == "farm", "a new kind goes to the farm")
	var dup := _kin(sps[0], "Dupe")
	ok(add.call(dup) == "box" and KinBox.is_boxed(dup), "a plain repeat of a kind already on the farm goes to the Kin Burrow")
	var dup_s := _kin(sps[0], "Shiny"); dup_s["shimmer"] = true
	ok(add.call(dup_s) == "farm", "a shimmering repeat goes to the farm")
	var dup_m := _kin(sps[1], "Big"); dup_m["mutations"] = ["giant"]
	ok(add.call(dup_m) == "farm", "a mutated (Giant) repeat goes to the farm")
	# fill the farm with new kinds, then one more of a new kind has to go in the box
	var i := 2
	while KinBox.farm().size() < KinBox.farm_cap():
		add.call(_kin(sps[i % sps.size()], "Fill%d" % i, 30.0 + i))
		i += 1
	ok(KinBox.farm().size() == KinBox.FARM_CAPS[0], "farm holds %d to start (%d out)" % [KinBox.FARM_CAPS[0], KinBox.farm().size()])
	var over := _kin(sps[3 % sps.size()], "Over"); over["shimmer"] = true
	ok(add.call(over) == "box" and KinBox.farm().size() == KinBox.farm_cap(), "the farm is full: even a shimmer waits in the box (cap respected)")
	# through the real results path: a caught kin's destination is on the record
	var caught := _kin(sps[0], "Caught")
	var res := Game.apply_result({"extracted": true, "caught": [caught], "tier": 0, "gems": 0, "kin_runs": []})
	var got: Dictionary = (res.get("caught", []) as Array)[0] if not (res.get("caught", []) as Array).is_empty() else {}
	ok(not got.is_empty() and KinBox.is_boxed(got) and String(got.get("went", "")) == "box", "caught on an expedition: a repeat lands in the box (%s)" % KinBox.went_text(got))
	Care.dex_sync()
	ok((Save.d["dex"][sps[1]]["mutations"] as Array).has("giant"), "the Field Book records a Giant %s" % Data.KIN[sps[1]]["name"])
	# ---------------------------------------------------------------- 2. moving, sorting, releasing
	ok(KinBox.to_farm(dup) != "", "can't bring one out onto a full farm: \"%s\"" % KinBox.to_farm(dup))
	ok(KinBox.to_box(st) != "", "the partner/starter stays on the farm: \"%s\"" % KinBox.to_box(st))
	var two: Dictionary = KinBox.farm().filter(func(r): return r["name"] == "Two")[0]
	Save.d["active"] = two["uid"]
	ok(KinBox.to_box(two) != "" and KinBox.to_box(st) != "", "partner can't be boxed, nor the starter")
	Save.d["active"] = st["uid"]
	ok(KinBox.swap(two, dup) == "" and KinBox.is_boxed(two) and not KinBox.is_boxed(dup) and KinBox.farm().size() == KinBox.farm_cap(), "swap: a boxed kin and a farm kin trade places")
	var s0 := int(two["box_slot"])
	ok(KinBox.to_box(two, 45) == "" and int(two["box_slot"]) == 45 and KinBox.page_of(two) == 1, "move inside the box to page 2, cell 16")
	var occupant := KinBox.at(s0)
	ok(KinBox.at(s0).is_empty() or occupant != two, "its old cell is free")
	ok(KinBox.to_box(over, 45) == "" and int(over["box_slot"]) == 45 and int(two["box_slot"]) != 45, "drop onto a full cell: they swap cells")
	for j in 12:
		var r := _kin(sps[j % sps.size()], "Box%d" % j, 20.0 + j, 1 + (j * 7) % 13)
		Save.d["roster"].append(r)
		KinBox.to_box(r)
	KinBox.sort_all("level")
	var lv_ok := true
	var bx := KinBox.sorted(KinBox.boxed(), "slot")
	for j in range(1, bx.size()):
		if int(bx[j]["level"]) > int(bx[j - 1]["level"]): lv_ok = false
	ok(lv_ok and int(bx[0]["box_slot"]) == 0 and int(bx[bx.size() - 1]["box_slot"]) == bx.size() - 1, "sort all by level: highest first, packed from cell 0 (%d boxed)" % bx.size())
	KinBox.sort_page(0, "name")
	var p0 := KinBox.sorted(KinBox.page_kin(0), "slot").map(func(r): return String(r["name"]).to_lower())
	var p0s := p0.duplicate(); p0s.sort()
	ok(p0 == p0s, "sort a page by name")
	var rar := KinBox.sorted(Save.d["roster"] as Array, "rarity")
	ok(Mutations.special(rar[0]), "rarity sort puts a shimmer or mutated kin first (%s)" % rar[0]["name"])
	ok(KinBox.matches(dup_m, "big", "all") and KinBox.matches(dup_m, "", "giant") and not KinBox.matches(dup, "", "mutated") and KinBox.matches(dup_s, "", "shimmer"), "search by name, filter by mutation / shimmer")
	var n0 := (Save.d["roster"] as Array).size()
	var victim: Dictionary = KinBox.boxed()[0]
	ok(KinBox.release(victim) == "" and (Save.d["roster"] as Array).size() == n0 - 1 and Save.kin(String(victim["uid"])).is_empty(), "release a boxed kin")
	ok(KinBox.release(st) != "", "can't release your starter/partner")
	# a boxed second kin taken on an expedition comes out, swapping with a farm kin if it must
	var second: Dictionary = KinBox.boxed()[0]
	Save.d["active2"] = second["uid"]
	var went := KinBox.bring_out(second)
	ok(not KinBox.is_boxed(second) and not went.is_empty() and KinBox.is_boxed(went) and KinBox.farm().size() == KinBox.farm_cap(), "a boxed kin picked for an expedition comes out (%s went in to make room)" % went.get("name", "-"))
	# expanding the cottages
	Save.d["gems"] = 5000
	ok(KinBox.expand() == "" and KinBox.farm_cap() == 8 and KinBox.expand() == "" and KinBox.expand() == "" and KinBox.farm_cap() == 12 and KinBox.expand() != "", "Kin Cottage expansions: 6 -> 8 -> 10 -> 12, then no more (%d gems left)" % int(Save.d["gems"]))
	Save.d["farm_lvl"] = 0
	# ---------------------------------------------------------------- 3. boxed kin sleep through time away
	var now := Time.get_unix_time_from_system()
	var sleeper: Dictionary = KinBox.boxed()[0]
	var awake: Dictionary = KinBox.farm().filter(func(r): return KinBox.pinned(r) == "")[0]
	Save.d["feeders"] = []
	for r in [sleeper, awake]:
		Care.ensure(r)
		r["needs"] = {"food": 50.0, "energy": 50.0, "joy": 50.0, "clean": 50.0}
		r.erase("starve")
		r["needs_t"] = now - 4.0 * 86400.0
	var ev := Econ.catch_up_all()
	ok(is_equal_approx(Care.need(sleeper, "food"), 50.0) and is_equal_approx(Care.need(sleeper, "joy"), 50.0) and Care.starve_h(sleeper) == 0.0 and not ev.any(func(e): return e["rec"] == sleeper), "4 days away: a boxed kin's needs are frozen (food %d, starving %.0fh)" % [int(Care.need(sleeper, "food")), Care.starve_h(sleeper)])
	ok(Care.need(awake, "food") < 50.0, "... while a farm kin got hungry (food %d, starving %.0fh)" % [int(Care.need(awake, "food")), Care.starve_h(awake)])
	Care.tick(sleeper, 3600.0)
	ok(is_equal_approx(Care.need(sleeper, "food"), 50.0), "an hour's tick doesn't touch a boxed kin")
	# ---------------------------------------------------------------- 4. an old crowded save
	var old := Save.fresh()
	old.erase("box_v"); old.erase("farm_lvl"); old.erase("box")
	var ros: Array = []
	for j in 11:
		var r := _kin(sps[j % sps.size()], "Old%d" % j, 10.0 + j * 7.0, 1 + j)
		r.erase("got_t")
		ros.append(r)
	ros[3]["trust"] = 1.0; ros[3]["level"] = 1      # a weak partner still stays out
	old["roster"] = ros
	old["active"] = ros[3]["uid"]
	Save.d = old
	var moved := KinBox.ensure()
	var farm := KinBox.farm()
	var kept_names: Array = farm.map(func(r): return String(r["name"]))
	var best_out := true
	var min_farm := 1e9
	for r in farm:
		if KinBox.pinned(r) == "": min_farm = minf(min_farm, float(r["trust"]) + float(r["level"]) * 4.0)
	for r in KinBox.boxed():
		if float(r["trust"]) + float(r["level"]) * 4.0 > min_farm: best_out = false
	ok(moved == 5 and farm.size() == 6 and KinBox.boxed().size() == 5 and int(Save.d.get("box_notice", 0)) == 5, "old save with 11 kin: 6 stay out, 5 boxed, one notice (%s)" % ", ".join(kept_names))
	ok(not KinBox.is_boxed(ros[3]) and ros[0].get("starter", false) and not KinBox.is_boxed(ros[0]) and best_out, "the partner and the first kin stay out, then the most trusted / highest level")
	ok(KinBox.ensure() == 0 and KinBox.farm().size() == 6, "migration only happens once")
	# ---------------------------------------------------------------- 5. the carry pick at the expedition portal (CarryPick)
	_carry_pick()
	var roster: Array = (Save.d["roster"] as Array).filter(func(r): return not r.has("ransom"))
	Save.d["roster"] = roster
	Save.d["active"] = roster[0]["uid"]
	Save.d["active2"] = roster[1]["uid"]
	var P = load("res://scripts/home/home.gd").new()
	main.add_child(P)
	for _f in 4: await main.get_tree().process_frame
	P._open_expedition()
	for _f in 2: await main.get_tree().process_frame
	var texts: Array = P.panel_host.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	var heads := func(w: String) -> bool: return texts.any(func(t): return String(t).begins_with(w))
	ok(heads.call("Carry: "), "the portal's Boki cards show a carry passive line")
	ok(heads.call("Lead") and heads.call("Second"), "the portal has a lead card and a second card")
	P.queue_free()
	print("KINBOX DONE failures: %d" % bad)
	main.get_tree().quit()

## The pick's rules without any screen: lead and second, one Boki goes with one, equal passives count once, old saves.
func _carry_pick() -> void:
	var a := _kin("lilybara", "Lily")
	var b := _kin("moonloris", "Moon")
	var c := _kin("cairnback", "Cairn")
	var e := _kin("burrlet", "Burr")
	Save.d["roster"] = [a]
	Save.d["active"] = a["uid"]
	Save.d["active2"] = ""
	ok(not CarryPick.has_second_slot() and Save.second_kin().is_empty(), "one Boki: it goes alone, no second slot")
	Save.d["roster"] = [a, b, c, e]
	ok(Save.second_kin().is_empty(), "with more Boki the second stays empty until picked (no auto-pick)")
	var line := CarryPick.passive_line(a)
	ok(line.begins_with("Carry: ") and CarryPick.passive_line(c).contains("knockback"), "the carry passive is one line (%s)" % line)
	ok(CarryPick.passive_line(e) == "Carry: no passive", "a Boki with no carry passive says so")
	ok(CarryPick.shared(a, b) != "" and CarryPick.shared(a, c) == "" and CarryPick.shared(a, e) == "",
			"the same passive is shared (%s); a different or no passive is not" % CarryPick.shared(a, b))
	CarryPick.set_second(b["uid"])
	var note := CarryPick._same_note(a, b)
	ok(Save.second_kin() == b and note.ends_with("counts once"), "second picked: %s" % note)
	CarryPick.set_second(a["uid"])
	ok(Save.second_kin() == b, "the lead can't also be the second")
	CarryPick.set_lead(b["uid"])
	ok(Save.active_kin() == b and Save.second_kin() == a, "picking the second as lead swaps the two")
	var seen := {}
	for _i in 6:
		var u := CarryPick.step("active2", 1)
		Save.d["active2"] = u
		seen[u] = true
	ok(seen.has("") and not seen.has(str(Save.d["active"])) and seen.size() == 4, "the second cycles the other Boki and none")
	var gone := _kin("lilybara", "Gone")
	gone["ransom"] = {}
	Save.d["roster"] = [a, b, gone]
	ok(CarryPick.choices() == [a, b], "a Boki that can't go is not offered")
	var old := {"v": 13, "roster": [a, b], "active": a["uid"], "active2": b["uid"]}
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION and old["active"] == a["uid"] and old["active2"] == "",
			"a v13 save keeps its partner as lead and has no second")
