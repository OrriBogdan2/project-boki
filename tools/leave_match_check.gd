extends RefCounted
## --leave-match-check: leaving a match from the Esc menu does exactly what its warning says (LeaveMatch).
## Per match type, in a fresh save: the dialog text, then LeaveMatch.apply and the results applied to the save.
##   tier 0 and 1 (early): the Boki comes home and loses leave_trust_loss trust, no word of "left behind"
##   tier 2 (the Hollow): the Boki is left behind in the order of docs/decisions/0008 and 0051:
##     1. it GUARDS where you stood (KinLoss), still on your roster while the match runs
##     2. nobody takes it: the end-of-match result is "home" and it finds its own way back (Limited Ways Out)
##     3. a rival scans it: the bond tracks the captor (KinTrack), the result is "rival", and it waits in the
##        Ransom House as captured_by that rival, priced by Ransom.price, and an offer at the floor buys it back
##   Training Area / Arena / tutorial: plain "Leave?", nothing changes
## Every wait is frame-stepped with a hard cap (_until) and a failed step skips what depends on it, so the check
## always reaches its DONE line and quits. Never touches the save file.

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
	for h in m.hunters:
		if h == m.player:
			continue
		h.ctrl = "idle"
		h.max_hp = 1e6
		h.hp = 1e6
		h.teleport(m.player.pos + Vector3(38.0, 0.0, 18.0 + float(m.hunters.find(h))))
		h.vel = Vector3.ZERO
	for i in 30:
		m.step(Match.DT)
	return m

## Steps the match frame by frame until cond is true, at most max_s seconds of match time. Never hangs.
func _until(m: Match, cond: Callable, max_s: float, what: String) -> bool:
	var frames := int(ceil(max_s / Match.DT))
	for i in frames + 1:
		if cond.call():
			return true
		m.step(Match.DT)
	ok(false, "%s: not reached after %d frames (%.1fs)" % [what, frames, max_s])
	return false

## The guarding Kin with this record uid, or null.
func _guard_of(m: Match, uid: String) -> Kin:
	for k in m.kins:
		if is_instance_valid(k) and KinLoss.guarding(k) and String(k.rec.get("uid", "")) == uid:
			return k
	return null

## The first hunter on another team than the player, or null.
func _rival(m: Match) -> Hunter:
	for h in m.hunters:
		if h != m.player and h.team != m.player.team:
			return h
	return null

## What the results screen would write after leaving now (Match._finish without the scene change).
func _leave(m: Match) -> void:
	LeaveMatch.apply(m)
	var runs: Array = []
	for kk in LeaveMatch.brought(m):
		runs.append({"uid": String(kk.rec["uid"]), "events": kk.events.duplicate(true), "trust": kk.trust})
	Game.apply_result({"extracted": false, "why": "left", "tier": m.tier, "lost_kin": m._resolve_lost(),
		"kin_runs": runs, "caught": [], "gems": 0, "seeds": {}})

func _body(main: Node) -> void:
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

	_deep_nobody(main)
	_deep_rival(main)

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

func run(main: Node) -> void:
	Save.no_write = true
	_body(main)          # (a script error in there returns here, so the check still ends)
	print("LEAVEMATCH DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Deep match, step 1 and 2: the Boki guards, nobody takes it, and at the end it finds its own way home (0051).
func _deep_nobody(main: Node) -> void:
	var m := _start(main, {"tier": 2, "teams": 2})
	var rec: Dictionary = Save.active_kin()
	var uid := String(rec.get("uid", ""))
	var tb := float(rec.get("trust", 0.0))
	ok(LeaveMatch.kind(m) == LeaveMatch.Kind.DEEP, "tier 2 is a deep match")
	var stood := m.player.pos
	LeaveMatch.apply(m)
	m.player.teleport(stood + Vector3(60.0, 0.0, 0.0))       # (the player is gone: it must not cradle its own guard)
	m.player.vel = Vector3.ZERO
	var g := _guard_of(m, uid)
	ok(g != null, "tier 2, step 1: leaving drops the Boki to guard (KinLoss.guarding)")
	if g == null:
		m.queue_free()
		return
	var r := float(KinLoss.rules()["guard_r"])
	ok(Vector2(g.pos.x - stood.x, g.pos.z - stood.z).length() <= r + 1.0,
		"tier 2, step 1: it guards where you stood (%.1f m, guard_r %.1f)" % [
			Vector2(g.pos.x - stood.x, g.pos.z - stood.z).length(), r])
	ok(not Save.kin(uid).is_empty() and Ransom.find(uid).is_empty(),
		"tier 2, step 1: while it guards it is still yours (on the roster, not at the Ransom House)")
	var lost: Array = m.player_lost.filter(func(L): return String(L["uid"]) == uid)
	ok(lost.size() == 1, "tier 2, step 1: the match lists it as left behind")
	var t0 := m.time
	_until(m, func(): return m.time - t0 >= 2.0 or _guard_of(m, uid) == null, 3.0, "tier 2: 2s of guarding")
	ok(_guard_of(m, uid) != null, "tier 2, step 1: still guarding 2s on (it waits as long as it takes)")
	var res: Array = m._resolve_lost().filter(func(L): return String(L["uid"]) == uid)
	ok(res.size() == 1 and String(res[0]["fate"]) == "home",
		"tier 2, step 2: nobody took it, the end-of-match result is home (%s)" % [
			str(res.map(func(L): return L["fate"]))])
	_leave(m)
	var after: Dictionary = Save.kin(uid)
	ok(not after.is_empty() and Ransom.find(uid).is_empty() and not KinLoss.held(after),
		"tier 2, step 2: it found its own way home (Limited Ways Out), not at the Ransom House")
	ok(not after.is_empty() and (after["memory"] as Array).any(func(e): return e["kind"] == "found_home"),
		"tier 2, step 2: the kin card says it found its own way home")
	ok(not after.is_empty() and float(after["trust"]) >= tb - 1.0, "tier 2: no leave trust penalty on top")
	m.queue_free()

## Deep match, step 3: a rival scans the guard; the bond tracks them; the result is theirs; the Ransom House
## lists it captured_by them at Ransom.price, and an offer at the floor brings it back.
func _deep_rival(main: Node) -> void:
	var m := _start(main, {"tier": 2, "teams": 2})
	var rec: Dictionary = Save.active_kin()
	var uid := String(rec.get("uid", ""))
	var F := _rival(m)
	ok(F != null, "tier 2: there is a rival hunter in the match")
	if F == null:
		m.queue_free()
		return
	var stood := m.player.pos
	LeaveMatch.apply(m)
	m.player.teleport(stood + Vector3(60.0, 0.0, 0.0))
	m.player.vel = Vector3.ZERO
	var g := _guard_of(m, uid)
	ok(g != null, "tier 2 rival, step 1: the Boki guards first")
	if g == null:
		m.queue_free()
		return
	F.teleport(g.pos + Vector3(1.0, 0.0, 0.0))
	F.vel = Vector3.ZERO
	m.step(Match.DT)
	F.inp["interact"] = true
	var scan_s := float(Capture.rules()["hold_s"]) + float(Capture.rules()["scan_s"])
	var took := _until(m, func(): return F.caught.any(func(c): return String(c.get("uid", "")) == uid),
		scan_s + 3.0, "tier 2 rival: the rival's scan of the guard")
	F.inp["interact"] = false
	if not took:
		m.queue_free()
		return
	ok(_guard_of(m, uid) == null, "tier 2 rival, step 3: scanned, it no longer guards")
	ok(KinTrack.tracked(F) and KinTrack.captor_for(m, m.player.team) == F,
		"tier 2 rival, step 3: the bond tracks the captor (%s)" % F.pname)
	ok(not Save.kin(uid).is_empty() and Ransom.find(uid).is_empty(),
		"tier 2 rival: until the match ends it is still on your roster")
	var res: Array = m._resolve_lost().filter(func(L): return String(L["uid"]) == uid)
	ok(res.size() == 1 and String(res[0]["fate"]) == "rival" and String(res[0]["holder"]) == F.pname,
		"tier 2 rival, step 3: the end-of-match result is rival, held by %s (%s)" % [F.pname, str(res)])
	if res.size() != 1 or String(res[0]["fate"]) != "rival":
		m.queue_free()
		return
	# soulbound kin (trust 90+) may slip a rival; this one is a fresh Boki
	ok(float(Save.kin(uid)["trust"]) < 90.0, "tier 2 rival: a fresh Boki, not soulbound (no coin flip home)")
	_leave(m)
	var L := Ransom.find(uid)
	ok(Save.kin(uid).is_empty() and not L.is_empty(), "tier 2 rival: off the roster and into the Ransom House list")
	if L.is_empty():
		m.queue_free()
		return
	ok(String(L["where"]) == "rival" and String(L["holder"]) == F.pname and int(L["tier"]) == 2,
		"tier 2 rival: the entry is held by %s, tier 2 (%s, %s)" % [F.pname, L["where"], L["holder"]])
	var stamp: Dictionary = L["rec"].get("lost_to", {})
	ok(String(stamp.get("by", "")) == F.pname, "tier 2 rival: the record is captured_by %s" % F.pname)
	var want := {"rec": L["rec"], "where": "rival", "holder": F.pname, "tier": 2}
	Ransom.price(want)
	ok(int(L["ask"]) == int(want["ask"]) and int(L["floor"]) == int(want["floor"]) and int(L["ask"]) > 0,
		"tier 2 rival: the offer is Ransom.price for that rival (ask %d, floor %d)" % [int(L["ask"]), int(L["floor"])])
	Save.d["gems"] = int(L["ask"]) + 10
	var o := Ransom.offer(L, int(L["floor"]))
	var back: Dictionary = Save.kin(uid)
	ok(String(o.get("result", "")) == "accept" and not back.is_empty() and not KinLoss.held(back)
		and Ransom.find(uid).is_empty(),
		"tier 2 rival: an offer at the floor buys it back (%s)" % String(o.get("result", "")))
	m.queue_free()
