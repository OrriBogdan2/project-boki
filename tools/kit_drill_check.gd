extends RefCounted
## --kit-drill-check: the first-time kit drill (KitDrill). Every Hunter gets a line, key and call-out per slot
## from its own JSON, the slice Hunters their own text and the rest a generic one; a recast reads "<KEY> AGAIN"
## and a hold says so; the steps advance on the player's presses; in the Training Area the banner shows once
## and a skip or a finished drill is saved so it never returns.

var bad := 0
const OPTS := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"training": true, "practice": true}

func ok(cond: bool, what: String) -> void:
	print("KITDRILL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var tree := main.get_tree()
	_text()
	_steps()
	await _area(main, tree, false)
	await _area(main, tree, true)
	print("KITDRILL %s" % ("FAIL %d" % bad if bad > 0 else "OK"))
	tree.quit(1 if bad > 0 else 0)

func _text() -> void:
	for id in Arch.ids():
		var plan := KitDrill.steps(id)
		var every := plan.size() == KitDrill.SLOTS.size()
		for st in plan:
			every = every and String(st["line"]).length() > 3 and String(st["key"]) != "?"
		ok(every, "%s: a line and a key for every slot" % id)
		if id in KitDrill.SLICE:
			for st in plan:
				print("KITDRILL   [%s] %s  %s" % [st["key"], st["line"], KitDrill.callout(st, 0)])
	ok(KitDrill.how("juggernaut", "e") == "again", "juggernaut E is a recast (its chain: press E again)")
	ok(KitDrill.how("gunslinger", "dash") == "hold", "gunslinger dash has a hold")
	ok(KitDrill.how("gunslinger", "lmb") == "", "LMB is a plain press")
	var jug: Dictionary = KitDrill.steps("juggernaut")[2]
	ok(KitDrill.callout(jug, 1) == "%s AGAIN" % jug["key"], "after the first press the call-out is '<KEY> AGAIN'")
	ok(not KitDrill.line("juggernaut", "e").begins_with("Try "), "a slice Hunter's line is its own text")
	ok(KitDrill.line("tender", "e").begins_with("Try "), "a Hunter outside the slice gets the generic line")

func _steps() -> void:
	var k := KitDrill.new()
	k.m = Match.new()
	k.start("juggernaut")
	k.on_press("secondary")
	ok(k.step == 0, "the wrong key does not advance")
	k.start("juggernaut")
	for st in k.plan:
		var n := 2 if st["how"] == "again" else 1
		for i in n:
			ok(k.step < k.plan.size() and k.plan[k.step]["slot"] == st["slot"], "step %s is open" % st["slot"])
			if st["how"] == "hold":
				k.on_held(st["action"], KitDrill.HOLD_S)
			else:
				k.on_press(st["action"])
			if i == 0 and n == 2:
				var open: bool = k.presses == 1 and k.plan[k.step]["slot"] == st["slot"]
				ok(open, "%s: the first press of a recast does not finish it" % st["slot"])
	ok(k.step == k.plan.size() and k.done_t >= 0.0, "the last step ends the drill")
	k.m.free()
	k.free()

func _area(main: Node, tree: SceneTree, skip: bool) -> void:
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["cls"] = "medium"
	d["arch"] = "gunslinger"
	d["classes"] = ClassUnlock.legacy()
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	await m.start(OPTS.duplicate())
	m.set_process(false)
	for i in 3: await tree.process_frame
	var kd := Practice.of(m).get_node_or_null(KitDrill.NAME) as KitDrill
	var tag := "skip" if skip else "finish"
	ok(kd != null and kd.plan.size() == KitDrill.SLOTS.size(), "%s: the first visit gets the drill" % tag)
	if kd != null:
		if skip:
			kd.finish()
		else:
			for st in kd.plan:
				if st["how"] == "hold": kd.on_held(st["action"], KitDrill.HOLD_S)
				else:
					kd.on_press(st["action"])
					kd.on_press(st["action"])
		ok(bool(Save.d["tutorial"].get(KitDrill.SAVE_KEY, false)), "%s: the save key is set" % tag)
	m.queue_free()
	await tree.process_frame
	var again := Match.new()
	main.add_child(again)
	await again.start(OPTS.duplicate())
	again.set_process(false)
	ok(Practice.of(again).get_node_or_null(KitDrill.NAME) == null, "%s: never shown again" % tag)
	again.queue_free()
