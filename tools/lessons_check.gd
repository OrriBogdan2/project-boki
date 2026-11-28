extends RefCounted
## --lessons-check: the Lessons hall (scripts/home/lesson_hall.gd, content/rules/lessons.json). A Boki is left for
## a timed lesson (song, dance or drawing), is off the farm while it lasts, and comes out of the door with stat
## points and a new habit that KinHabit then plays. Checks the rules, the fee and the refusals, the clock, what a
## finished lesson gives, the habit poses and, in a live farm, the walk-up, the panel and the Boki leaving and
## returning. Never touches the real save.

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("LESSONS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _save() -> Dictionary:
	var d := Save.fresh()
	var lead := Save.new_kin("zapple", "Lead")
	var pupil := Save.new_kin("kilnbadger", "Ember")
	var other := Save.new_kin("burrlet", "Moss")
	for r in [lead, pupil, other]:
		Care.ensure(r)
		d["roster"].append(r)
	d["active"] = lead["uid"]
	d["gems"] = 100
	d["tutorial"] = {"hatched": true, "intro": true}
	return d


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = _save()
	var lay := HomeLayout.ensure(Save.d)
	var hall := {"u": HomeLayout._next_uid(lay), "id": LessonHall.ID, "x": 36, "z": 24, "r": 0}
	_rules_and_catalog()
	_refusals(hall)
	(lay["deco"] as Array).append(hall)
	_lesson_runs()
	_habit_poses()
	await _in_the_farm()
	print("LESSONS DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _rules_and_catalog() -> void:
	ok(LessonHall.ids().size() == 3, "three lessons: %s" % str(LessonHall.ids()))
	var good := true
	for id in LessonHall.ids():
		var l := LessonHall.lesson(id)
		good = good and Care.STATS.has(String(l["stat"])) and int(l["gain"]) > 0 and float(l["secs"]) > 0.0
		good = good and String(l["habit"]) != "" and int(l["gems"]) > 0
	ok(good, "each lesson has a real stat, a gain, a length, a habit and a fee")
	var c: Dictionary = HomeLayout.CATALOG.get(LessonHall.ID, {})
	ok(String(c.get("cat", "")) == "Buildings" and int(c.get("max", 0)) == 1, "the hall is a one-only Buildings entry")
	var farm: Dictionary = FarmUnlocks.rules()
	ok(
		farm["build"].has(LessonHall.ID) and farm["unlock"].has(LessonHall.ID),
		"it has a build cost and an unlock level"
	)


func _refusals(hall: Dictionary) -> void:
	var lead: Dictionary = Save.d["roster"][0]
	var pupil: Dictionary = Save.d["roster"][1]
	ok(LessonHall.why_not(Save.d, pupil, "song") != "", "no hall built: no lesson")
	(HomeLayout.of(Save.d)["deco"] as Array).append(hall)
	ok(LessonHall.why_not(Save.d, pupil, "song") == "", "with the hall built, a Boki can go")
	ok(LessonHall.why_not(Save.d, lead, "song") != "", "the partner stays with you")
	Save.d["gems"] = 3
	ok(
		LessonHall.why_not(Save.d, pupil, "song") != "" and not LessonHall.enrol(Save.d, pupil, "song", 0.0),
		"too few gems: refused and nothing is spent"
	)
	Save.d["gems"] = 100
	(HomeLayout.of(Save.d)["deco"] as Array).erase(hall)


func _lesson_runs() -> void:
	var pupil: Dictionary = Save.d["roster"][1]
	var other: Dictionary = Save.d["roster"][2]
	var t0 := 5000.0
	var fee := int(LessonHall.lesson("dance")["gems"])
	ok(
		LessonHall.enrol(Save.d, pupil, "dance", t0) and int(Save.d["gems"]) == 100 - fee,
		"a Boki is enrolled and the fee is paid"
	)
	ok(LessonHall.why_not(Save.d, pupil, "song") != "", "a Boki in class cannot take a second lesson")
	ok(not GardenZones.out_here().has(pupil) and GardenZones.out_here().has(other), "a Boki in class is off the farm")
	ok(LessonHall.enrol(Save.d, other, "song", t0), "a second Boki fits")
	ok(LessonHall.why_not(Save.d, Save.d["roster"][0], "song") != "", "the hall holds only two at once")
	var secs := float(LessonHall.lesson("dance")["secs"])
	var shortest := float(LessonHall.lesson("song")["secs"])
	ok(LessonHall.finished(Save.d, t0 + shortest - 1.0).is_empty(), "nothing finishes early")
	ok(
		LessonHall.finished(Save.d, t0 + shortest).size() == 1,
		"the song lesson is done at its length, the dance one is not"
	)
	ok(LessonHall.finished(Save.d, t0 + secs).has(pupil), "the dance lesson finishes after its length")
	var speed := int(pupil["stats"]["speed"])
	var line := LessonHall.graduate(pupil)
	var gained := int(pupil["stats"]["speed"]) - speed
	ok(gained > 0 and gained <= int(LessonHall.lesson("dance")["gain"]), "it gained Speed (+%d)" % gained)
	ok(not pupil.has("lesson") and pupil["habits"] == ["dance"], "it is out of class with the dance habit: %s" % line)
	ok(GardenZones.out_here().has(pupil), "it walks the farm again")
	LessonHall.enrol(Save.d, pupil, "dance", t0)
	LessonHall.graduate(pupil)
	ok(pupil["habits"] == ["dance"], "taking the same lesson again does not learn the habit twice")
	ok(String(pupil["memory"].back()["kind"]) == "lesson", "it remembers the lesson")


func _habit_poses() -> void:
	var body := Node3D.new()
	var n := Node3D.new()
	body.name = "Body"
	n.add_child(body)
	for pose in ["sing", "dance", "doodle"]:
		var k := {"rec": {}, "qt": 99.0}
		KinHabit.react(k, pose)
		KinHabit.step(k, n, false, 0.3)
		var moved: bool = not body.rotation.is_zero_approx() or not body.position.is_zero_approx()
		KinHabit.step(k, n, false, 1.0)
		var rest: bool = body.rotation.is_zero_approx() and body.position.is_zero_approx() and not k.has("q_as")
		ok(moved and rest, "the %s pose moves the body and puts it back" % pose)
	n.free()
	seed(7)
	var learned := 0
	var rounds := 200
	for i in rounds:
		var k := {"rec": {"habits": ["sing"]}, "qt": 0.0}
		KinHabit._pick_learned(k)
		learned += 1 if String(k.get("q_as", "")) == "sing" else 0
	ok(
		learned > rounds / 4 and learned < rounds * 3 / 4,
		"a taught Boki plays its habit about half the time (%d/%d)" % [learned, rounds]
	)
	var plain := {"rec": {}}
	KinHabit._pick_learned(plain)
	ok(not plain.has("q_as"), "a Boki with no lessons keeps its own habits")


func _in_the_farm() -> void:
	var pupil: Dictionary = Save.d["roster"][1]
	pupil.erase("habits")
	for r in Save.d["roster"]:
		r.erase("lesson")
	var home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.panel_host != null and home.player != null and home.hecon != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	var hall := LessonHall.entry(Save.d)
	var c := HomeLayout.deco_center(hall)
	home.ppos = c + Vector3(0, 0, 2.0)
	var it: Dictionary = home.hecon.find(Vector2(home.ppos.x, home.ppos.z), 9.0)
	ok(
		it.get("hall", {}) == hall and home._label_for(it) == "Lessons hall",
		"walk up to the hall: it is the thing to use"
	)
	it = home.hecon.find(Vector2(c.x + 12.0, c.z + 12.0), 9.0)
	ok(not it.has("hall"), "far from the hall nothing offers it")
	home._use({"kind": "place", "hall": hall})
	ok(home.panel_open == "Lessons hall", "E opens the Lessons hall panel")
	home._close_panel()
	var before: int = home.kins.size()
	home.hecon.hall._send(pupil, "song")
	ok(
		pupil.has("lesson") and home._kin_entry(pupil).is_empty() and home.kins.size() == before - 1,
		"sent to class, the Boki leaves the farm"
	)
	ok(
		home._label_for({"kind": "place", "hall": hall}) == "Lessons hall  ·  1 in class",
		"the prompt counts who is in class"
	)
	pupil["lesson"]["t"] = float(pupil["lesson"]["t"]) - float(LessonHall.lesson("song")["secs"])
	home.hecon.hall.tick(2.0)
	var back: Dictionary = home._kin_entry(pupil)
	var at: Vector3 = LessonHall.door(hall)
	ok(
		not back.is_empty() and Vector2(back["pos"].x - at.x, back["pos"].z - at.z).length() < 0.1,
		"when the lesson is over it walks out of the hall's door"
	)
	ok(pupil["habits"] == ["sing"] and not pupil.has("lesson"), "and knows the song habit")
	await _shot(home, hall, back)


## With --lessons-shot=<dir>: the hall's panel, then the finished Boki at its door from the close third-person farm
## view (you stand west of the hall: south of it a wall pulls the camera in).
func _shot(home, hall: Dictionary, back: Dictionary) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--lessons-shot="):
			dir = String(a).substr(15)
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	FarmTutorial.skip()
	FarmSpotlight.close()
	var at := LessonHall.door(hall)
	home.ppos = at + Vector3(-3.2, 0, 1.2)
	home.player.position = home.ppos
	home.cam.zoom_to = 1.0
	home.cam.zoom = 1.0
	home.cam.snap(home.ppos)
	if main.fade:
		main.fade.reveal(0.05)
	await main.get_tree().create_timer(1.5).timeout
	if home.panel_open != "":
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("lessons_hall_panel.png"))
	home._close_panel()
	await main.get_tree().create_timer(1.5).timeout
	KinHabit.react(back, "dance")
	for i in 40:
		await main.get_tree().process_frame
		home.day_t = 0.45
		if i == 12:
			KinHabit.react(back, "dance")
	print("LESSONS cam at %s, player %s, boki %s" % [home.cam.global_position, home.ppos, back["pos"]])
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("lessons_hall_close_cam.png"))
	print("LESSONS shot saved in %s" % dir)
