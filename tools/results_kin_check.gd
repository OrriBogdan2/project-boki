extends RefCounted
## --results-kin-check: the Boki row on the results card. A scripted match has the Boki hit a foe, heal
## its hunter and pull the downed hunter up; those counters (HunterFeats, Kin) reach the results row
## as one plain line with a portrait, and the bond gained. Never touches the save file.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RESULTSKIN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _find_row(n: Node) -> Node:
	if n.has_meta("kin_row"):
		return n
	for c in n.get_children():
		var f := _find_row(c)
		if f: return f
	return null

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 1, "length": 1e9, "seed": 4243, "no_drop": true,
			"weapon": "rifle", "cls": "medium"})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var foe: Hunter = null
	for h in m.hunters:
		h.ctrl = "idle"
		if h != P:
			h.teleport(P.pos + Vector3(30.0, 0, 30.0))
			h.max_hp = 1e6
			h.hp = 1e6
			if h.team != P.team and foe == null: foe = h
	var k: Kin = P.kin
	ok(k != null and foe != null, "a Boki and a rival")
	P.max_hp = 1e6
	# the Boki is sent out, hits the rival, heals its hunter
	k.st_throws += 1
	var dealt := roundi(foe.hurt(40.0, k, {"src": "kin"}))
	P.hp = 100.0
	var heal := PartSpec.new()
	heal.kind = "effect"
	heal.type = "heal"
	heal.target = "owner"
	heal.params = {"amount": 25.0, "over": 0.0}
	var cx := KinExec.make_cx(m, k, k, P, P.pos, 1.0, "q", "check")
	KinExec._friend(heal, P, cx, P.pos)
	ok(dealt > 0 and int(P.stats.get("kin_damage", 0)) == dealt, "kin_damage counts the Boki's hit")
	ok(int(P.stats.get("kin_healing", 0)) == 25, "kin_healing counts the health it gave")
	# the hunter goes down; the Boki pulls them up
	m.knock(P, foe, {})
	ok(P.downed, "the hunter is down")
	for i in int(round(30.0 / Match.DT)):
		m.step(Match.DT)
		if not P.downed: break
	ok(not P.downed and int(P.stats.get("kin_saves", 0)) == 1, "the Boki pulled them up")
	# the same counters, as the results screen gets them
	var run_stats := {"hits": k.st_hits, "kos": 0, "throws": k.st_throws, "skills": 0,
			"revives": 1, "caught": 0, "won": 1}
	var r := {"arch": "medium", "extracted": true, "why": "extracted", "knocks": 0, "kills": 0, "gems": 0,
			"seeds": {}, "stats": P.stats.duplicate(), "lvl": 1, "caught": [], "tonics": 0,
			"kin_runs": [{"uid": String(k.rec["uid"]), "events": [], "trust": k.trust, "stats": run_stats}]}
	var s := Game.apply_result(r)
	s["kin_line"] = ResultsKinRow.line(r, s)
	print("RESULTSKIN line: ", s["kin_line"])
	ok(float(s.get("trust_delta", 0.0)) > 0.5, "the bond went up")
	for part in ["Sent out once", "hit for %d damage" % dealt, "healed you for 25", "got you back up once", "bond up"]:
		ok(String(s["kin_line"]).contains(part), "the line says '%s'" % part)
	var row := ResultsKinRow.row(s, main.get_tree())
	var said := (row.get_child(1) as Label).text
	ok(row.get_child_count() == 2 and said == s["kin_line"], "the row is a portrait and the line")
	row.free()
	var screen: Control = load("res://scripts/ui/results.gd").new()
	main.add_child(screen)
	var r2 := r.duplicate(true)
	screen.show_result(r2)
	ok(_find_row(screen) != null, "the results screen shows the Boki row")
	screen.queue_free()
	var idle := ResultsKinRow.line({"stats": {}, "kin_runs": []}, {"trust_delta": 0.0})
	ok(idle == "Stayed close and out of the fight.", "a quiet run says so (%s)" % idle)
	print("RESULTSKIN DONE, failures: ", bad)
	main.get_tree().quit()
