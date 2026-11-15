extends RefCounted
## --tutorial-resume-check: quitting the combat tutorial part-way (docs/decisions/0022-tutorial-resume.md).
##   1. the save: the v11 -> v12 migration, and when Continue goes back into the tutorial
##   2. a full run remembers each finished beat in the save
##   3. quit after each beat and come back: it carries on at the next one, at the last stop, with the
##      state that beat needs (your Boki, the chest key, the foes)
##   4. the farm tutorial: save to a file and load it after each step; the same step is up, with the
##      tools given, the starter food and the house still there
## Never touches the real save.

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("TUTRES %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_save_rules()
	_remember()
	_resume_each()
	_farm_resume()
	print("TUTRES DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _tut_save(tut: Dictionary) -> void:
	Save.d = Save.fresh()
	var k := Save.new_kin("cindle", "Ash")
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = tut


# ------------------------------------------------------------------ 1. the save
func _save_rules() -> void:
	_tut_save({"hatched": true, "intro": true})
	ok(TutorialResume.pending(), "hatched and never finished: Continue goes back into the tutorial")
	Save.d["tutorial"]["tut_beat"] = "dash"
	ok(TutorialResume.pending(), "with a beat saved too")
	Save.d["tutorial"]["match"] = true
	ok(not TutorialResume.pending(), "finished or skipped (tutorial.match): Continue goes to the farm")
	_tut_save({"hatched": true, "home": true})
	ok(not TutorialResume.pending(), "a save that reached the farm never goes back")
	var played := {"v": 11, "tutorial": {"hatched": true}, "matches": 3}
	var fresh := {"v": 11, "tutorial": {"hatched": true}, "matches": 0}
	var farmed := {"v": 11, "tutorial": {"hatched": true, "ft": {"did": {"hob": true}}}}
	for d: Dictionary in [played, fresh, farmed]:
		Save.migrate(d)
	ok(
		bool(played["tutorial"].get("match", false)) and bool(farmed["tutorial"].get("match", false)),
		"v12: a save that played or reached the farm counts as finished"
	)
	var kept: bool = not fresh["tutorial"].has("match") and int(fresh["v"]) == Save.VERSION
	ok(kept, "a save that only hatched keeps its tutorial")


# ------------------------------------------------------------------ 2. a run saves its beats
func _new_match() -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	return m


func _remember() -> void:
	_tut_save({"hatched": true, "intro": true})
	var m := _new_match()
	var tu: Tutorial = m.tut
	var last := -1
	var wrong := ""
	var t := 0.0
	while t < 600.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		if tu.step != last:
			var before := String(Tutorial.steps()[last][0]) if last >= 0 else ""
			var saved := String(Save.d["tutorial"].get("tut_beat", ""))
			if before != "" and saved != before:
				wrong += " " + before
			last = tu.step
	ok(wrong == "", "each finished beat is in the save the moment it ends (wrong:%s)" % wrong)
	ok(String(Save.d["tutorial"]["tut_beat"]) == "defend", "extracting ends the course (Match sets tutorial.match)")
	m.free()


# ------------------------------------------------------------------ 3. quit after each beat, come back
func _resume_each() -> void:
	var steps := Tutorial.steps()
	var tried := 0
	for i in steps.size() - 1:
		var beat := String(steps[i][0])
		_tut_save({"hatched": true, "intro": true, "tut_beat": beat})
		var m := _new_match()
		var tu: Tutorial = m.tut
		var t := 0.0
		while tu.step <= 0 and t < 60.0:
			TutorialDrive.drive(m)
			m.step(Match.DT)
			t += Match.DT
		var want := TutorialResume.step_after(beat)
		while want < steps.size() and not tu.applies(String(steps[want][0])):
			want += 1
		var tag := "after '%s'" % beat
		ok(tu.step == want, "%s: carries on at '%s' (is '%s')" % [tag, String(steps[want][0]), tu.id()])
		var stop := tu.respawn()
		var far: bool = m.player.pos.distance_to(stop) > 6.0
		ok(not far or tu.id() in ["chest", "goexit", "key", "gkey"], "%s: back at the last stop" % tag)
		ok(m.player.kin != null, "%s: your Boki is with you" % tag)
		if tu.id() == "chest":
			ok(m.player.chest_keys > 0, "%s: the chest key is in hand" % tag)
		if tu.id() in Tutorial.FOE_STEPS:
			ok(m.mobs.any(func(x): return not x.dead), "%s: the foes are there" % tag)
		ok(String(Save.d["tutorial"]["tut_beat"]) == beat, "%s: resuming leaves the saved beat alone" % tag)
		m.free()
		tried += 1
	ok(tried == steps.size() - 1, "every beat was tried (%d)" % tried)


# ------------------------------------------------------------------ 4. the farm tutorial
func _farm_resume() -> void:
	_tut_save({"hatched": true, "intro": true})
	Save.d["roster"][0]["starter"] = true
	var lay := HomeLayout.ensure(Save.d)
	Save.d["stats"] = {"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 0, "fb_built": 0}
	ok(FarmTutorial.active(), "the farm tutorial is running on the new save")
	var file := "user://tut_resume_check.json"
	var bad_at := ""
	var ids := FarmTutorial.steps().map(func(s): return String(s["id"]))
	for id: String in ids.slice(0, ids.size() - 1):
		if id == "house":
			(lay["deco"] as Array).append({"u": HomeLayout._next_uid(lay), "id": "house", "x": 36, "z": 24, "r": 0})
		FarmTutorial.give_step_tool(id)
		if id == "feed":
			FarmTutorial.give_food()
		FarmTutorial.mark(id)
		var want := FarmTutorial.current()
		var done := FarmTutorial.done_count()
		var f := FileAccess.open(file, FileAccess.WRITE)
		f.store_string(JSON.stringify(Save.d))
		f.close()
		Save.load_from(file)
		lay = Save.d["layout"]
		var kept: bool = FarmTutorial.active() and FarmTutorial.current() == want and FarmTutorial.done_count() == done
		kept = kept and (id != "house" or not FarmHob.house_entry().is_empty())
		kept = kept and (id != "stone" or HomeGather.has_tool("pickaxe"))
		kept = kept and (id != "feed" or bool(FarmTutorial.state()["gift"]))
		if not kept:
			bad_at += " " + id
	ok(bad_at == "", "quit after each farm step and reload: the same step, tools, food and house (lost at:%s)" % bad_at)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
