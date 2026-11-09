extends RefCounted
## --tut-funnel-check: the tutorial funnel (TutFunnel). Per step of the match and farm tutorials it keeps the
## time entered and finished, idle seconds, hints, and skip or quit; it survives a relaunch, rides on the rate
## card's answer inside the server's size limit, and tools/tut_funnel.py prints it as a table.
## Uses a scratch feedback file and a fake poster; never touches the save or the network.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TUTFUNNEL %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Feedback.path = "user://feedback_funnel_check.json"
	DirAccess.remove_absolute(Feedback.path)
	TutFunnel.reset()
	_numbers()
	_farm()
	_match()
	_delivery()
	DirAccess.remove_absolute(Feedback.path)
	print("TUTFUNNEL DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Idle only counts after TutFunnel.IDLE_AFTER of quiet; a hint, a skip and a step left open are told apart.
func _numbers() -> void:
	TutFunnel.enter("match", "a")
	TutFunnel.tick("match", 3.0, true)
	for i in 8:
		TutFunnel.tick("match", 1.0, false)
	TutFunnel.hint("match")
	TutFunnel.leave("match", "a")
	TutFunnel.enter("match", "b")
	TutFunnel.tick("match", 2.0, true)
	TutFunnel.skip("match")
	TutFunnel.enter("match", "c")
	TutFunnel.tick("match", 1.0, true)
	var p: Dictionary = TutFunnel.payload()["match"]
	ok(p["a"] == [0, 11, 4, 1, "done"], "a done step: entered 0, finished 11 s, 4 s idle, 1 hint (%s)" % str(p["a"]))
	ok(p["b"] == [11, 13, 0, 0, "skip"], "a skipped step ends as skip (%s)" % str(p["b"]))
	ok(p["c"] == [13, -1, 0, 0, ""], "a step never ended stays open: the quit (%s)" % str(p["c"]))
	TutFunnel.enter("farm", "x", "plant")
	TutFunnel.enter("farm", "x", "plant")
	TutFunnel.enter("farm", "x", "water")
	ok(TutFunnel.payload()["farm"]["x"][TutFunnel.HINTS] == 1, "a later hint stage on the same step is one hint")
	TutFunnel.save()
	TutFunnel.reset()
	ok(TutFunnel.payload()["match"]["a"] == [0, 11, 4, 1, "done"] and TutFunnel.payload()["match"]["c"][4] == "",
			"the numbers come back after a relaunch")
	TutFunnel.tick("match", 2.0, true)
	TutFunnel.enter("match", "d")
	ok(TutFunnel.payload()["match"]["d"][TutFunnel.IN] == 15, "and the clock carries on from where it was")
	TutFunnel.reset()
	DirAccess.remove_absolute(Feedback.path)

## The farm tutorial reports through its own marks: a step found already done, a skip.
func _farm() -> void:
	Save.d = Save.fresh()
	TutFunnel.enter("farm", "axe")
	TutFunnel.tick("farm", 4.0, true)
	FarmTutorial.mark("axe")
	FarmTutorial.mark("chop")
	TutFunnel.enter("farm", "stone")
	TutFunnel.tick("farm", 3.0, true)
	FarmTutorial.skip()
	var f: Dictionary = TutFunnel.payload()["farm"]
	ok(f["axe"] == [0, 4, 0, 0, "done"], "farm: a finished step (%s)" % str(f["axe"]))
	ok(f["chop"][TutFunnel.IN] == 4 and f["chop"][TutFunnel.OUT] == 4 and f["chop"][TutFunnel.END] == "done",
			"farm: a step found already done is entered and finished at once")
	ok(f["stone"] == [4, 7, 0, 0, "skip"], "farm: skipping ends the step it was on as skip (%s)" % str(f["stone"]))
	TutFunnel.reset()
	DirAccess.remove_absolute(Feedback.path)

## A full scripted run of the match tutorial: every step that applies has an entry, in order, all done.
func _match() -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	var t := 0.0
	while t < 600.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
	var steps: Dictionary = TutFunnel.payload().get("match", {})
	var all_done := not steps.is_empty() and steps.values().all(func(r): return r[TutFunnel.END] == "done")
	ok(m.player.extracted and all_done, "match: the course ran and every step is done (%d steps)" % steps.size())
	var order := true
	var last := -1
	for sid in steps:
		var r: Array = steps[sid]
		order = order and r[TutFunnel.IN] >= last and r[TutFunnel.OUT] >= r[TutFunnel.IN]
		last = r[TutFunnel.OUT]
	ok(order, "match: steps are entered and finished in order on one clock")
	var want := Tutorial.steps().filter(func(s): return m.tut.applies(String(s[0]))).size()
	ok(steps.size() == want, "match: one entry per step this kit has (%d of %d)" % [steps.size(), want])
	m.queue_free()

## The numbers ride on the rate card's answer inside the server's limit; the folder tool reads them back.
func _delivery() -> void:
	var sent: Array = []
	Feedback.poster = func(body: Dictionary, done: Callable) -> void:
		sent.append(body)
		done.call(true)
	var host := Control.new()
	main.add_child(host)
	Feedback.submit(host, {"combat": 7, "boki": 9, "onboarding": 4, "look": 10}, "")
	var b: Dictionary = sent[0]
	ok(b.has("funnel") and b["funnel"].has("match"), "the answer carries the funnel")
	ok(JSON.stringify(b).length() < 4096, "and fits the server's 4 KB limit (%d bytes)" % JSON.stringify(b).length())
	ok(b.keys().all(func(k): return k in ["version", "player", "scores", "note", "minutes_played", "funnel"]),
			"nothing else is added to what the card already sent")
	var dir := ProjectSettings.globalize_path("user://funnel_check_dir")
	DirAccess.make_dir_recursive_absolute(dir)
	var quitter: Dictionary = b.duplicate(true)
	var last_id: String = quitter["funnel"]["match"].keys()[-1]
	quitter["funnel"]["match"][last_id][TutFunnel.OUT] = -1
	quitter["funnel"]["match"][last_id][TutFunnel.END] = ""
	var f := FileAccess.open(dir.path_join("a.jsonl"), FileAccess.WRITE)
	f.store_line(JSON.stringify(b))
	f.store_line(JSON.stringify(quitter))
	f.close()
	var out := []
	var code := OS.execute("python3", ["-I", ProjectSettings.globalize_path("res://tools/tut_funnel.py"), dir], out)
	var txt := String(out[0]) if out.size() > 0 else ""
	ok(code == 0 and txt.contains("2 records") and txt.contains("match tutorial") and txt.contains(last_id),
			"tools/tut_funnel.py prints the table for a folder")
	var row := ""
	for ln in txt.split("\n"):
		if String(ln).begins_with(last_id):
			row = String(ln)
	var cols := row.split(" ", false)
	ok(cols.size() >= 8 and cols[4] == "1", "the quit shows in the last step's quit column (%s)" % row)
	DirAccess.remove_absolute(dir.path_join("a.jsonl"))
	DirAccess.remove_absolute(dir)
	Feedback.poster = Callable()
