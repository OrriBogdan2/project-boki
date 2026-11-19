extends RefCounted
## --tutorial-wisp-check: the tutorial's Boki-wisp beats (TutorialWisp, docs/specs/TUTORIAL_WISP.md). With Boki
## wisps on, the test driver plays the course: the wisp step shows before main's summon and pack steps, the steal
## step after them, and the walking Boki's step (gkey) never does; the course is at most three steps longer than
## without wisps (wisp, summon, pack, steal for gkey);
## the wisp step names the carry power; a downed rival Hunter's Boki wisp is loose, its outline line shows, then the
## grab line, and holding interact steals it; the course finishes and the stolen wisp goes home at match end. With
## wisps off the wisp steps never show. Prints TUTWISP PASS/FAIL lines and the four beats with their text.

const TFC := preload("res://tools/tutorial_fight_check.gd")

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("TUTWISP %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var off := await _play(main, false)
	var on := await _play(main, true)
	var shown_off: Array = off["order"]
	var shown_on: Array = on["order"]
	ok(not shown_off.any(func(s): return s in TutorialWisp.STEPS),
		"wisps off: no wisp step shows (%s)" % ",".join(shown_off))
	ok(not shown_on.has("gkey"), "wisps on: the walking Boki's step never shows")
	var idx: Array = ["wisp", "summon", "pack", "steal"].map(func(s): return shown_on.find(s))
	ok(not idx.has(-1) and idx[0] < idx[1] and idx[1] < idx[2] and idx[2] < idx[3],
		"wisps on: wisp, summon, pack, steal show in that order (%s)" % ",".join(shown_on))
	ok(shown_on.size() <= shown_off.size() + 3,
		"at most three more steps: %d with wisps, %d without" % [shown_on.size(), shown_off.size()])
	print("TUTWISP DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _play(main: Node, wisps: bool) -> Dictionary:
	seed(11)
	Save.d["tutorial"].erase("tut_beat")      # (the run before finished the course: a start would resume past it)
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "tut_test": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0,
		"demo_kin": "cindle", "boki_wisps": wisps})
	m.set_process(false)
	var tu: Tutorial = m.tut
	var p := m.player
	var order: Array = []
	var lines := {}            # step id -> every distinct banner line it showed, in order
	var details := {}
	var steal_t := -1.0
	var fight_t := 0.0         # s in the fight beats (as --tutorial-fight-check counts them, plus summon)
	var dk: Kin = null
	var t := 0.0
	while t < 600.0 and not p.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		var sid := tu.id()
		if sid == "":
			continue
		if order.is_empty() or order[-1] != sid:
			order.append(sid)
		if not lines.has(sid):
			lines[sid] = []
		if tu.text != "" and not (lines[sid] as Array).has(tu.text):
			lines[sid].append(tu.text)
		details[sid] = tu.detail
		if sid in TFC.FIGHT_STEPS or sid == "summon":
			fight_t += Match.DT
		if wisps and sid == "steal":
			dk = tu.wb.dk
			steal_t = tu.t
	var tag := "wisps on" if wisps else "wisps off"
	ok(p.extracted, "%s: the course finishes (%.0f s)" % [tag, t])
	ok(fight_t <= TFC.FIGHT_MAX + 10.0, "%s: the fight beats take at most %.0f s (%.1f)"
		% [tag, TFC.FIGHT_MAX + 10.0, fight_t])
	if wisps:
		_beats(lines, details, steal_t, dk, p)
	if wisps and dk:
		ok(dk.home_h.downed and not dk.home_h.out, "the decoy Hunter stays down to the end")
	m._finish()
	if wisps and dk:
		ok(dk.owner_h == dk.home_h and not KinSteal.stolen(dk), "match end: the stolen wisp went home")
		ok(p.kin and p.kin.owner_h == p and p.kin.rec.get("species", "") == "cindle",
			"match end: your own Boki is still yours")
	m.queue_free()
	await main.get_tree().process_frame
	return {"order": order}

func _beats(lines: Dictionary, details: Dictionary, steal_t: float, dk: Kin, p: Hunter) -> void:
	var w: Array = lines.get("wisp", [])
	var st: Array = lines.get("steal", [])
	var carry := KinText.carry(p.kin.ks)
	print("TUTWISP beat 1 wisp: ", w)
	print("TUTWISP beat 2 carry passive: ", details.get("wisp", ""))
	print("TUTWISP beat 3-4 outline, steal: ", st, " | ", details.get("steal", ""))
	ok(w.size() == 1 and String(w[0]).contains("wisp"), "beat 1: the wisp line (%s)" % str(w))
	ok(carry != "" and String(details.get("wisp", "")).contains(carry),
		"beat 2: the detail names the carry power (%s)" % carry)
	ok(st.size() == 2 and String(st[0]).contains("Round") and String(st[1]).contains(Settings.key_cap("interact")),
		"beats 3-4: outline line, then the grab line with its key (%s)" % str(st))
	ok(dk != null and dk.home_h != p and KinSteal.stolen(dk) and dk.owner_h == p,
		"beat 4: the rival's Boki wisp rides with you")
	ok(steal_t >= 0.0 and steal_t < TutorialWisp.FLOAT_T,
		"beat 4: stolen by holding interact, not the fallback (%.1f s)" % steal_t)
