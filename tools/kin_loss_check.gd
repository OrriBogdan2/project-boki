extends RefCounted
## --kin-loss-check: losing a Boki (docs/decisions/0008, KinLoss / KinBond). Never touches the save file.
##   1. low tier: the owner dies, the Boki is safe and goes home (away, nothing lost); revived, it walks back out
##   2. high tier: the owner dies, the Boki drops dazed beside the deathbox and guards it; revived + the 3.5s cradle
##      by touch and it is theirs again; its owner and teammates cannot scan it, an enemy can
##   3. an enemy scans it: it is in the captor's box, the bond pull is on for the owner once up (arrow target = captor,
##      the name, a map ping now and every bond_ping_s), the captor is tracked
##   4. the captor knocked, or killed: it drops dazed there, the pull ends, the owner cradles it back
##   5. the match ends with nobody having taken it: "ransom" in the save
##   6. captured and the captor extracted: "captured_by:<name>" in the save, and it cannot be picked for a match
##   7. Net.VERSION is 0.17.0

var bad := 0
var m: Match
var main: Node
var P: Hunter
var F: Hunter
var G: Hunter

func ok(cond: bool, what: String) -> void:
	print("KINLOSS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run_for(secs: float) -> void:
	for i in int(round(secs / Match.DT)):
		for mb in m.mobs.duplicate():
			m.mobs.erase(mb)
			mb.queue_free()
		m.step(Match.DT)

func _fresh(tier: int) -> void:
	if m: m.queue_free()
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip"); d["roster"].append(rec); d["active"] = rec["uid"]
	var rec2 := Save.new_kin("cindle", "Ash"); d["roster"].append(rec2)
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": tier, "length": 1e9, "seed": 4243, "no_drop": true, "weapon": "rifle", "cls": "medium"})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	var W = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-20, 21):
		for dx in range(-30, 41):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	P.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	P.vel = Vector3.ZERO
	F = null; G = null
	for h in m.hunters:
		if h == P:
			continue
		h.ctrl = "idle"
		h.max_hp = 1e6; h.hp = 1e6
		h.teleport(Vector3(P.pos.x + 38.0, P.pos.y, P.pos.z + 18.0 + float(m.hunters.find(h))))
		if h.team != P.team and F == null: F = h
		elif h.team == P.team: G = h
	P.kin.stow()
	P.max_hp = 1e6; P.hp = 1e6
	_run_for(0.3)

func _die() -> Dictionary:
	m.eliminate(P, F, "shot")
	return Life.box_of(m, P)

func _guard() -> Kin:
	for k in m.kins:
		if KinLoss.guarding(k) and k.owner_h == P:
			return k
	return null

func _cradle(k: Kin) -> void:
	P.teleport(k.pos + Vector3(0.8, 0, 0))
	P.vel = Vector3.ZERO
	_run_for(0.3)
	P.teleport(k.pos + Vector3(0.8, 0, 0))
	_run_for(float(KinDowned.rules()["rescue_s"]) + 0.8)

## P (at tier 2) dies with a Boki on them, the rival scans it. Leaves P revived and up.
func _capture() -> Kin:
	_fresh(2)
	var k: Kin = P.kin
	var bx := _die()
	var g := _guard()
	F.teleport(g.pos + Vector3(1.0, 0, 0))
	F.vel = Vector3.ZERO
	_run_for(0.2)
	F.inp["interact"] = true
	_run_for(float(Capture.rules()["hold_s"]) + float(Capture.rules()["scan_s"]) + 0.5)
	F.inp["interact"] = false
	Life.bring_back(m, P, bx["pos"], 0.5, false)
	P.hp = P.max_hp
	return k

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	ok(Net.VERSION == "0.17.0", "Net.VERSION is 0.17.0 (%s)" % Net.VERSION)
	ok(int(KinLoss.rules()["loss_min_tier"]) == 2 and not KinLoss.at_risk(0) and not KinLoss.at_risk(1) and KinLoss.at_risk(2), "loss_min_tier 2: tiers 0 and 1 are safe, 2 is at risk")

	# 1. low tier
	_fresh(1)
	var k1: Kin = P.kin
	_die()
	ok(P.out and k1.state == "away" and not k1.dead and not KinLoss.guarding(k1), "1. tier 1: the owner died, their Boki is safe (away, not dropped)")
	ok(m.player_lost.is_empty() and m._resolve_lost().is_empty(), "1. tier 1: nothing is lost at the end of the match")
	Life.bring_back(m, P, P.pos, 0.5, false)
	_run_for(0.2)
	ok(k1.state in ["active", "flying_home", "shoulder"] and k1.owner_h == P, "1. tier 1: revived, the Boki walks back out at their side (%s)" % k1.state)
	_fresh(0)
	_die()
	ok(P.kin.state == "away" and m.player_lost.is_empty(), "1. tier 0: safe too")

	# 2. high tier
	_fresh(2)
	var k: Kin = P.kin
	var bx := _die()
	ok(P.out and k.state == "dazed" and KinLoss.guarding(k) and not k.dead, "2. tier 2: the owner died, their Boki is dropped dazed (%s)" % k.state)
	var bd := Vector2(k.pos.x - bx["pos"].x, k.pos.z - bx["pos"].z).length()
	ok(bd < 3.0 and bd > 0.2, "2. it stands beside the deathbox (%.1f m)" % bd)
	ok(m.player_lost.size() == 1 and m.player_lost[0]["kin"] == k, "2. it is recorded as lost")
	ok(k.visible, "2. it is visible while its owner is out")
	_run_for(2.0)
	ok(k.state == "dazed" and k.pos.distance_to(Vector3(bx["pos"])) < 3.0, "2. it stays put: no teleport, no recovery")
	ok(not KinLoss.scannable_by(P, k) and not KinLoss.scannable_by(G, k) and KinLoss.scannable_by(F, k), "2. its owner and teammates cannot scan it, an enemy can")
	P.swap_kin(true)
	ok(k.state == "dazed", "2. swapping does not pick it up")
	Life.bring_back(m, P, bx["pos"], 0.5, false)
	_run_for(0.5)
	ok(k.state == "dazed" and P.kin == k, "2. reviving the owner does not call it home by itself (%s)" % k.state)
	_cradle(k)
	ok(k.state == "shoulder" and P.kin == k and k.lost_owner == null and m.player_lost.is_empty(), "2. revive then the cradle by touch: it is theirs again (%s)" % k.state)

	# 3. an enemy scan, the bond pull
	var kc := _capture()
	var rec_uid := String(kc.rec.get("uid", ""))
	ok(kc.dead and F.caught.size() == 1 and String(F.caught[0].get("uid", "")) == rec_uid, "3. the rival's scan put it in their box")
	ok(KinBond.tracked(F), "3. the captor is tracked (their HUD shows Tracked)")
	ok(KinBond.pulling(P) and KinBond.captor_for(m, P.team) == F and m.kin_thief() == F, "3. the owner is up: the arrow target is the captor")
	ok(KinBond.name_for(F, P.team) == String(kc.rec.get("name", "")), "3. the arrow says whose Boki it is (%s)" % KinBond.name_for(F, P.team))
	ok(KinBond.captor_for(m, F.team) == null, "3. the captor's own side feels no pull")
	_run_for(0.3)
	var pinged := m.pings.any(func(pg): return int(pg.get("team", -1)) == P.team and Vector3(pg["pos"]).distance_to(F.pos) < 1.0 and float(pg["t"]) < 1.0)
	ok(pinged, "3. the captor's exact spot is pinged on the squad's map")
	m.pings.clear()
	_run_for(float(KinLoss.rules()["bond_ping_s"]) - 1.0)
	ok(not m.pings.any(func(pg): return int(pg.get("team", -1)) == P.team and float(pg["t"]) < 0.5), "3. no ping between the 15s marks")
	_run_for(1.6)
	ok(m.pings.any(func(pg): return int(pg.get("team", -1)) == P.team and float(pg["t"]) < 1.5), "3. a new ping every bond_ping_s")
	# a downed owner feels no pull
	P.downed = true
	ok(not KinBond.pulling(P), "3. the pull is for an owner who is up (a downed one does not see it)")
	P.downed = false

	# 4a. the captor knocked
	m.knock(F, P, {})
	var g2 := _guard()
	ok(g2 != null and g2 != kc and g2.state == "dazed" and F.caught.is_empty() and not KinBond.tracked(F), "4. the captor is knocked: it drops dazed there, the pull ends")
	ok(g2 != null and g2.pos.distance_to(F.pos) < 3.0, "4. it is on the spot they fell")
	_cradle(g2)
	ok(not KinLoss.guarding(g2) and g2.state != "dazed" and P.kin == g2 and m.player_lost.is_empty(), "4. the owner cradles it back (%s)" % g2.state)

	# 4b. the captor killed
	_capture()
	var nk := F.caught.size()
	m.eliminate(F, P, "shot")
	var fb := Life.box_of(m, F)
	var g3 := _guard()
	ok(nk == 1 and g3 != null and F.caught.is_empty() and not fb.is_empty() and (fb["caught"] as Array).is_empty() and not KinBond.tracked(F), "4. the captor is killed: it is not in their box, it drops dazed and guarding")
	ok(g3 != null and Vector2(g3.pos.x - fb["pos"].x, g3.pos.z - fb["pos"].z).length() < 3.0, "4. beside the captor's deathbox")
	_cradle(g3)
	ok(not KinLoss.guarding(g3) and g3.state != "dazed" and P.kin == g3, "4. and the owner reclaims it by cradle")

	# 5. nobody takes it
	_fresh(2)
	var rec5: Dictionary = P.kin.rec
	_die()
	_run_for(1.0)
	var res: Array = m._resolve_lost()
	ok(res.size() == 1 and res[0]["fate"] == "ransom", "5. the match ends with nobody having taken it: ransom")
	var sv := {"matches": 7, "roster": [rec5]}
	KinLoss.after_match(sv, rec5, KinLoss.outcome_of(res[0]["fate"], res[0]["holder"]))
	ok(rec5.has("ransom") and int(rec5["ransom"]["match"]) == 7 and int(rec5["ransom"]["t"]) > 0 and not KinLoss.selectable(rec5), "5. the save holds a ransom flag with the match and the time")
	KinLoss.after_match(sv, rec5, "home")
	ok(KinLoss.selectable(rec5) and not rec5.has("ransom"), "5. 'home' clears it")

	# 6. captured and extracted
	var k6 := _capture()
	var rec6: Dictionary = k6.rec
	m._extract(F)
	_run_for(0.2)
	ok(not KinBond.tracked(F) and KinBond.captor_for(m, P.team) == null, "6. the captor extracted: the pull stops")
	var res6: Array = m._resolve_lost()
	ok(res6.size() == 1 and res6[0]["fate"] == "rival" and res6[0]["holder"] == F.pname, "6. at the end it is lost to %s" % F.pname)
	var other := Save.new_kin("cindle", "Ash")
	var sv6 := {"matches": 9, "roster": [rec6, other], "active": rec6["uid"], "active2": "none"}
	var oc: String = KinLoss.outcome_of(res6[0]["fate"], res6[0]["holder"])
	KinLoss.after_match(sv6, rec6, oc)
	ok(oc == "captured_by:" + F.pname and rec6.get("lost_to", {}).get("by", "") == F.pname and KinLoss.held(rec6), "6. flagged lost to that player in the save")
	Save.d = Save.fresh()
	Save.d["roster"] = [rec6, other]
	Save.d["active"] = rec6["uid"]
	ok(Save.active_kin()["uid"] == other["uid"] and Save.second_kin().is_empty(), "6. it cannot be picked for a match")
	KinLoss.clear(rec6)
	ok(KinLoss.selectable(rec6), "6. cleared once resolved")
	print("KINLOSS DONE, failures: ", bad)
	main.get_tree().quit()
