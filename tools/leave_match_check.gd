extends RefCounted
## --leave-match-check: leaving a match from the Esc menu does exactly what its warning says (LeaveMatch).
## Per match type, in a fresh save: the dialog text, then LeaveMatch.apply and the results applied to the save.
##   tier 0 and 1 (early): the Boki comes home and loses leave_trust_loss trust, no word of "left behind"
##   tier 2 (the Hollow): the Boki is left behind, ransomed, off the roster
##   Training Area / Arena / tutorial: plain "Leave?", nothing changes
## Never touches the save file.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LEAVEMATCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## A match on a fresh save: Pip comes along, Ash stays home (a lone Boki is handed back on credit).
func _start(main: Node, extra: Dictionary) -> Match:
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["roster"].append(Save.new_kin("cindle", "Ash"))
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 1, "squad": 1, "length": 1e9, "seed": 4243, "no_drop": true, "weapon": "rifle",
		"cls": "medium"}
	o.merge(extra, true)
	m.start(o)
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for i in 30:
		m.step(Match.DT)
	return m

## What the results screen would write after leaving now (Match._finish without the scene change).
func _leave(m: Match) -> void:
	LeaveMatch.apply(m)
	var runs: Array = []
	for kk in LeaveMatch.brought(m):
		runs.append({"uid": String(kk.rec["uid"]), "events": kk.events.duplicate(true), "trust": kk.trust})
	Game.apply_result({"extracted": false, "why": "left", "tier": m.tier, "lost_kin": m._resolve_lost(),
		"kin_runs": runs, "caught": [], "gems": 0, "seeds": {}})

func run(main: Node) -> void:
	Save.no_write = true
	var cut := float(KinLoss.rules()["leave_trust_loss"])
	ok(cut > 0.0, "leave_trust_loss is set in boki_system.json (%.1f)" % cut)
	ok(not KinLoss.at_risk(1) and KinLoss.at_risk(2), "early = tiers below loss_min_tier (0, 1); Hollow (2) is deep")
	var wp := LeaveMatch.warning(LeaveMatch.Kind.PRACTICE, true)
	ok(wp["head"] == "Leave?" and not "Boki" in String(wp["body"]), "practice: plain 'Leave?', no word about Boki")
	var we := LeaveMatch.warning(LeaveMatch.Kind.EARLY, true)
	ok("lose trust" in String(we["body"]) and not "left behind" in String(we["body"]),
		"early: says they lose trust, not left behind")
	var wd := LeaveMatch.warning(LeaveMatch.Kind.DEEP, true)
	ok("left behind" in String(wd["body"]), "deep: says left behind")
	ok(not "Boki" in String(LeaveMatch.warning(LeaveMatch.Kind.DEEP, false)["body"]),
		"no Boki brought: the warning leaves them out")

	for t in [0, 1]:
		var m := _start(main, {"tier": t})
		ok(LeaveMatch.kind(m) == LeaveMatch.Kind.EARLY, "tier %d is an early match" % t)
		var rec: Dictionary = Save.active_kin()
		var before := float(rec["trust"])
		_leave(m)
		var after: Dictionary = Save.kin(String(rec["uid"]))
		ok(not after.is_empty() and Ransom.find(String(rec["uid"])).is_empty() and not KinLoss.held(after),
			"tier %d: the Boki is home, not left behind" % t)
		ok(float(after["trust"]) <= before - cut, "tier %d: trust %.0f -> %.0f (drop of at least %.0f)" % [
			t, before, float(after["trust"]), cut])
		ok((after["memory"] as Array).any(func(e): return e["kind"] == "left"),
			"tier %d: the kin card remembers it" % t)
		m.queue_free()

	var mh := _start(main, {"tier": 2})
	var rh: Dictionary = Save.active_kin()
	var hb := float(rh["trust"])
	ok(LeaveMatch.kind(mh) == LeaveMatch.Kind.DEEP, "tier 2 is a deep match")
	_leave(mh)
	ok(Save.kin(String(rh["uid"])).is_empty() and not Ransom.find(String(rh["uid"])).is_empty(),
		"tier 2: the Boki is left behind (off the roster, waiting at the Ransom House)")
	var held_trust := float(Ransom.find(String(rh["uid"]))["rec"]["trust"])
	ok(held_trust >= hb - 1.0, "tier 2: no trust penalty on top (only being left)")
	mh.queue_free()

	var plain: Array = [{"tier": 0, "training": true, "arena": true}, {"tier": 0, "training": true, "practice": true},
		{"tier": 0, "tutorial": true}]
	for o in plain:
		var mp := _start(main, o)
		var rp: Dictionary = Save.active_kin()
		var tb := float(rp["trust"])
		ok(LeaveMatch.kind(mp) == LeaveMatch.Kind.PRACTICE, "%s: plain Leave?" % [str(o.keys())])
		LeaveMatch.apply(mp)
		ok(float(rp["trust"]) == tb and Ransom.find(String(rp["uid"])).is_empty() and Save.kin(String(rp["uid"])) == rp,
			"%s: leaving changes nothing" % [str(o.keys())])
		mp.queue_free()
	print("LEAVEMATCH DONE, failures: ", bad)
	main.get_tree().quit()
