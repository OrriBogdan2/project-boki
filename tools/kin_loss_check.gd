extends RefCounted
## --kin-loss-check: losing a Boki (docs/decisions/0008, KinLoss / KinTrack). Never touches the save file.
##   1. low tier: the owner dies, the Boki is safe and goes home (away, nothing lost); revived, it walks back out
##   2. high tier: the owner dies, the Boki drops dazed beside the deathbox and guards it; revived + the 3.5s cradle
##      by touch and it is theirs again (carrying it, see 9); its owner and teammates cannot scan it, an enemy can
##   3. an enemy scans it: it is in the captor's box, the bond pull is on for the owner once up (arrow target = captor,
##      the name, a map ping now and every bond_ping_s), the captor is tracked
##   4. the captor knocked, or killed: it drops dazed there, the pull ends, the owner cradles it back
##   5. the match ends with nobody having taken it: "ransom" in the save
##   6. captured and the captor extracted: "captured_by:<name>" in the save, and it cannot be picked for a match
##   7. Net.VERSION is 0.18.0 or later
##  10. second review: a host scan of a client's guard (proxy) takes the real Boki and starts the bond; Shift or F
##      puts the carry down (no dash), no auto pick-up with a foe near or mid-channel; stale/proxy cradle state
##   9. carry while rescuing: the cradle runs while you carry it at 0.9x speed, dash/jump/fire are blocked, shots do not
##      drop it, a stun or a launch does (back down guarding, progress lost), other games get the progress and the pose
##   8. review fixes: a second death before the cradle keeps one lost entry; cradle and scan cannot both win (block
##      reason + the host "catch" handler); bots leave a teammate's guard alone and still scan an enemy's; leaving the
##      match still loses it (Game.apply_result); online, simulated by calling the net handlers: "caught" starts the
##      bond in the captor's and the owner's game, "unbond" ends it, "gdrop" stands the Boki up again in the owner's
##      game under a slot id the owner owns

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
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	var rec2 := Save.new_kin("cindle", "Ash")
	d["roster"].append(rec2)
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": tier, "length": 1e9, "seed": 4243, "no_drop": true,
		"weapon": "rifle", "cls": "medium"})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	var W = m.world
	var hx := int(floor(P.pos.x))
	var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-20, 21):
		for dx in range(-30, 41):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i)
			W.walls.erase(i)
			W.props.erase(i)
			W.bush.erase(i)
	P.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	P.vel = Vector3.ZERO
	F = null
	G = null
	for h in m.hunters:
		if h == P:
			continue
		h.ctrl = "idle"
		h.max_hp = 1e6
		h.hp = 1e6
		h.teleport(Vector3(P.pos.x + 38.0, P.pos.y, P.pos.z + 18.0 + float(m.hunters.find(h))))
		if h.team != P.team and F == null: F = h
		elif h.team == P.team: G = h
	P.kin.stow()
	P.max_hp = 1e6
	P.hp = 1e6
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
	ok(Net.VERSION.naturalnocasecmp_to("0.18.0") >= 0, "Net.VERSION is 0.18.0 (%s)" % Net.VERSION)
	ok(
		int(KinLoss.rules()["loss_min_tier"]) == 2 and not KinLoss.at_risk(1) and KinLoss.at_risk(2),
		"loss_min_tier 2: tiers 0 and 1 are safe, 2 is at risk"
	)

	# 1. low tier
	_fresh(1)
	var k1: Kin = P.kin
	_die()
	ok(
		P.out and k1.state == "away" and not k1.dead and not KinLoss.guarding(k1),
		"1. tier 1: the owner died, their Boki is safe (away, not dropped)"
	)
	ok(m.player_lost.is_empty() and m._resolve_lost().is_empty(), "1. tier 1: nothing is lost at the end of the match")
	Life.bring_back(m, P, P.pos, 0.5, false)
	_run_for(0.2)
	ok(
		k1.state in ["active", "flying_home", "shoulder"] and k1.owner_h == P,
		"1. tier 1: revived, the Boki walks back out at their side (%s)" % k1.state
	)
	_fresh(0)
	_die()
	ok(P.kin.state == "away" and m.player_lost.is_empty(), "1. tier 0: safe too")

	# 2. high tier
	_fresh(2)
	var k: Kin = P.kin
	var bx := _die()
	ok(
		P.out and k.state == "dazed" and KinLoss.guarding(k) and not k.dead,
		"2. tier 2: the owner died, their Boki is dropped dazed (%s)" % k.state
	)
	var bd := Vector2(k.pos.x - bx["pos"].x, k.pos.z - bx["pos"].z).length()
	ok(bd < 3.0 and bd > 0.2, "2. it stands beside the deathbox (%.1f m)" % bd)
	ok(m.player_lost.size() == 1 and m.player_lost[0]["kin"] == k, "2. it is recorded as lost")
	ok(k.visible, "2. it is visible while its owner is out")
	_run_for(2.0)
	ok(k.state == "dazed" and k.pos.distance_to(Vector3(bx["pos"])) < 3.0, "2. it stays put: no teleport, no recovery")
	ok(
		not KinLoss.scannable_by(P, k) and not KinLoss.scannable_by(G, k) and KinLoss.scannable_by(F, k),
		"2. its owner and teammates cannot scan it, an enemy can"
	)
	P.swap_kin(true)
	ok(k.state == "dazed", "2. swapping does not pick it up")
	Life.bring_back(m, P, bx["pos"], 0.5, false)
	_run_for(0.5)
	ok(k.state == "dazed" and P.kin == k, "2. reviving the owner does not call it home by itself (%s)" % k.state)
	_cradle(k)
	ok(
		k.state == "shoulder" and P.kin == k and k.lost_owner == null and m.player_lost.is_empty(),
		"2. revive then the cradle by touch: it is theirs again (%s)" % k.state
	)

	# 3. an enemy scan, the bond pull
	var kc := _capture()
	var rec_uid := String(kc.rec.get("uid", ""))
	ok(
		kc.dead and F.caught.size() == 1 and String(F.caught[0].get("uid", "")) == rec_uid,
		"3. the rival's scan put it in their box"
	)
	ok(KinTrack.tracked(F), "3. the captor is tracked (their HUD shows Tracked)")
	ok(
		KinTrack.pulling(P) and KinTrack.captor_for(m, P.team) == F and m.kin_thief() == F,
		"3. the owner is up: the arrow target is the captor"
	)
	ok(
		KinTrack.name_for(F, P.team) == String(kc.rec.get("name", "")),
		"3. the arrow says whose Boki it is (%s)" % KinTrack.name_for(F, P.team)
	)
	ok(KinTrack.captor_for(m, F.team) == null, "3. the captor's own side feels no pull")
	_run_for(0.3)
	var pinged := m.pings.any(func(pg):
		var near: bool = Vector3(pg["pos"]).distance_to(F.pos) < 1.0
		return int(pg.get("team", -1)) == P.team and near and float(pg["t"]) < 1.0)
	ok(pinged, "3. the captor's exact spot is pinged on the squad's map")
	m.pings.clear()
	_run_for(float(KinLoss.rules()["bond_ping_s"]) - 1.0)
	var captor_pinged := m.pings.any(func(pg):
		var near: bool = Vector3(pg["pos"]).distance_to(F.pos) < 1.5
		return int(pg.get("team", -1)) == P.team and near and float(pg["t"]) < 0.5)
	ok(not captor_pinged, "3. no captor ping between the 15s marks")
	_run_for(1.6)
	ok(
		m.pings.any(func(pg): return int(pg.get("team", -1)) == P.team and float(pg["t"]) < 1.5),
		"3. a new ping every bond_ping_s"
	)
	# a downed owner feels no pull
	P.downed = true
	ok(not KinTrack.pulling(P), "3. the pull is for an owner who is up (a downed one does not see it)")
	P.downed = false

	# 4a. the captor knocked
	m.knock(F, P, {})
	var g2 := _guard()
	ok(
		g2 != null and g2.state == "dazed" and F.caught.is_empty() and not KinTrack.tracked(F),
		"4. the captor is knocked: it drops dazed there, the pull ends"
	)
	ok(g2 != null and g2.pos.distance_to(F.pos) < 3.0, "4. it is on the spot they fell")
	_cradle(g2)
	ok(
		not KinLoss.guarding(g2) and g2.state != "dazed" and P.kin == g2 and m.player_lost.is_empty(),
		"4. the owner cradles it back (%s)" % g2.state
	)

	# 4b. the captor killed
	_capture()
	var nk := F.caught.size()
	m.eliminate(F, P, "shot")
	var fb := Life.box_of(m, F)
	var g3 := _guard()
	ok(
		nk == 1 and g3 != null and F.caught.is_empty() and not fb.is_empty() and (fb["caught"] as Array).is_empty()
			and not KinTrack.tracked(F),
		"4. the captor is killed: it is not in their box, it drops dazed and guarding"
	)
	ok(
		g3 != null and Vector2(g3.pos.x - fb["pos"].x, g3.pos.z - fb["pos"].z).length() < 3.0,
		"4. beside the captor's deathbox"
	)
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
	ok(
		rec5.has("ransom") and int(rec5["ransom"]["match"]) == 7 and int(rec5["ransom"]["t"]) > 0
			and not KinLoss.selectable(rec5),
		"5. the save holds a ransom flag with the match and the time"
	)
	KinLoss.after_match(sv, rec5, "home")
	ok(KinLoss.selectable(rec5) and not rec5.has("ransom"), "5. 'home' clears it")

	# 6. captured and extracted
	var k6 := _capture()
	var rec6: Dictionary = k6.rec
	m._extract(F)
	_run_for(0.2)
	ok(not KinTrack.tracked(F) and KinTrack.captor_for(m, P.team) == null, "6. the captor extracted: the pull stops")
	var res6: Array = m._resolve_lost()
	ok(
		res6.size() == 1 and res6[0]["fate"] == "rival" and res6[0]["holder"] == F.pname,
		"6. at the end it is lost to %s" % F.pname
	)
	var other := Save.new_kin("cindle", "Ash")
	var sv6 := {"matches": 9, "roster": [rec6, other], "active": rec6["uid"], "active2": "none"}
	var oc: String = KinLoss.outcome_of(res6[0]["fate"], res6[0]["holder"])
	KinLoss.after_match(sv6, rec6, oc)
	ok(
		oc == "captured_by:" + F.pname and rec6.get("lost_to", {}).get("by", "") == F.pname and KinLoss.held(rec6),
		"6. flagged lost to that player in the save"
	)
	Save.d = Save.fresh()
	Save.d["roster"] = [rec6, other]
	Save.d["active"] = rec6["uid"]
	ok(Save.active_kin()["uid"] == other["uid"] and Save.second_kin().is_empty(), "6. it cannot be picked for a match")
	KinLoss.clear(rec6)
	ok(KinLoss.selectable(rec6), "6. cleared once resolved")
	_review_fixes()
	_client_captor()
	_review2()
	print("KINLOSS DONE, failures: ", bad)
	main.get_tree().quit()

func _loot_guard() -> Kin:
	_fresh(2)
	_die()
	return _guard()

## Metres per second over 0.3s of walking right, after half a second to get up to speed.
func _walk_speed() -> float:
	var walk := func():
		P.inp["move"] = Vector2(1, 0)
	for i in int(round(0.5 / Match.DT)):
		walk.call()
		_run_for(Match.DT)
	var p0 := P.pos
	for i in int(round(0.3 / Match.DT)):
		walk.call()
		_run_for(Match.DT)
	P.inp["move"] = Vector2.ZERO
	return Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length() / 0.3

## P to `at`, standing still.
func _put(at: Vector3) -> void:
	P.teleport(at)
	P.vel = Vector3.ZERO

## Carrying the guarding Boki: 0.9x speed, the Boki rides with you, dash/jump/fire are off, shots do not drop it, hard
## crowd control and a launch do (it falls back down still guarding, the progress lost), other players see it.
func _carry_checks() -> void:
	var g := _loot_guard()
	var bx := Life.box_of(m, P)
	Life.bring_back(m, P, bx["pos"], 0.5, false)
	P.hp = P.max_hp
	var origin := g.pos + Vector3(0, 0, 8.0)
	P.teleport(origin)
	P.vel = Vector3.ZERO
	var plain := _walk_speed()
	P.teleport(g.pos + Vector3(0.8, 0, 0))
	P.vel = Vector3.ZERO
	_run_for(0.6)
	ok(
		g.rescue_on and g.state == "dazed" and KinDowned.rescue_pose(P) == "rs_carry",
		"carry: running into the guard picks it up"
	)
	var carried := _walk_speed()
	ok(
		g.rescue_on and plain > 1.0 and absf(carried / plain - 0.9) < 0.03,
		"carry: moves at 0.9x (%.2f vs %.2f m/s)" % [carried, plain]
	)
	ok(
		g.flat_dist(P) < 1.0 and g.rescue_t > 0.5,
		"carry: it rides with you while the progress fills (%.2fm, %.2fs)" % [g.flat_dist(P), g.rescue_t]
	)
	var held := g.rescue_t
	for i in int(round(0.3 / Match.DT)):
		P.inp["fire"] = true
		P.inp["jump"] = true
		P.inp["sec_hold"] = true
		_run_for(Match.DT)
	for key in ["fire", "jump", "sec_hold"]:
		P.inp[key] = false
	ok(
		P.grounded and P.roll_t <= 0.0 and not P.used.has("fire") and g.rescue_on,
		"carry: jump and firing are blocked, not cancelling"
	)
	ok(g.rescue_t > held, "carry: the progress keeps filling (%.2f -> %.2f)" % [held, g.rescue_t])
	var snap := KinNet.kin_extra(g)
	ok(
		float(snap[2]) > 0.0 and String(KinNet.hunter_extra(P)[4]).begins_with("rs_carry"),
		"carry: other games get the progress and the carry pose"
	)
	for i in 6:
		P.hurt(3.0, F, {"src": "shot", "kb": Vector2(2.5, 0.0)})
		_run_for(0.1)
	ok(g.rescue_on, "carry: shots (damage and the small shove) don't drop it")
	P.stun_t = 0.8
	_run_for(0.1)
	ok(
		not g.rescue_on and g.rescue_t == 0.0 and KinLoss.guarding(g),
		"carry: a stun drops it, still guarding, progress lost"
	)
	ok(
		g.flat_dist(P) < 1.0 and Capture.block_reason(F, g) == "",
		"carry: it fell where you stand and an enemy may scan it again"
	)
	P.stun_t = 0.0
	_run_for(1.0)
	P.teleport(g.pos + Vector3(0.5, 0, 0))
	P.vel = Vector3.ZERO
	_run_for(1.0)
	ok(g.rescue_on, "carry: running into it again picks it up")
	# Shift puts it down on purpose: no dash, progress lost, and no automatic pick-up until you step away
	P.inp["dash"] = true
	_run_for(0.05)
	P.inp["dash"] = false
	_run_for(0.1)
	ok(
		not g.rescue_on and g.rescue_t == 0.0 and P.roll_t <= 0.0 and KinLoss.guarding(g),
		"carry: Shift puts it down and is spent on that (no dash)"
	)
	_run_for(1.5)
	ok(not g.rescue_on, "carry: standing on a Boki you put down does not pick it up again")
	_put(g.pos + Vector3(4.0, 0, 0))
	_run_for(0.3)
	_put(g.pos + Vector3(0.5, 0, 0))
	_run_for(0.5)
	ok(g.rescue_on, "carry: stepping away and back picks it up again")
	P.inp["interact"] = true
	_run_for(0.1)
	P.inp["interact"] = false
	_run_for(0.1)
	ok(not g.rescue_on and g.rescue_t == 0.0, "carry: a fresh interact press puts it down too")
	_run_for(1.0)
	P.inp["interact"] = true
	_run_for(0.1)
	P.inp["interact"] = false
	_run_for(0.2)
	ok(g.rescue_on, "carry: interact picks it up even right where you put it down")
	# a foe within 6m: walking into it does not pick it up, interact does
	P.inp["interact"] = true
	_run_for(0.1)
	P.inp["interact"] = false
	_run_for(0.1)
	_put(g.pos + Vector3(4.0, 0, 0))
	_run_for(0.3)
	F.out = false
	F.teleport(g.pos + Vector3(4.0, 0, 3.0))
	_put(g.pos + Vector3(0.5, 0, 0))
	_run_for(0.8)
	ok(not g.rescue_on, "carry: with a foe within 6m, walking into it does not pick it up")
	P.inp["interact"] = true
	_run_for(0.1)
	P.inp["interact"] = false
	_run_for(0.2)
	ok(g.rescue_on, "carry: pressing interact picks it up with a foe near")
	F.teleport(P.pos + Vector3(40.0, 0, 0))
	P.impulse(Vector2(14.0, 0.0), 6.0)
	_run_for(0.1)
	ok(not g.rescue_on and g.rescue_t == 0.0 and KinLoss.guarding(g), "carry: a launch drops it too")
	_run_for(2.0)
	P.teleport(g.pos + Vector3(0.5, 0, 0))
	P.vel = Vector3.ZERO
	_run_for(float(KinDowned.rules()["rescue_s"]) + 1.5)
	ok(not KinLoss.guarding(g) and P.kin == g, "carry: carried the full 3.5s it is theirs again (%s)" % g.state)

## Second review: the host's proxy copy of a client's guard, stale cradle state, channels that block a pick-up.
func _review2() -> void:
	var g := _loot_guard()
	var owner_h := G
	owner_h.remote = true
	var real: Dictionary = g.rec.duplicate(true)
	# a proxy of a client-owned guard: fabricated record, no identity
	var k := m.give_kin(owner_h, real)
	k.remote = true
	k.rec = {"species": k.species, "level": 1, "name": "x", "traits": {}, "trust": 50.0}
	k.state = "dazed"
	k.dazed_t = 1e9
	k.lost_from = ""
	k.lost_owner = null
	k.teleport(F.pos + Vector3(2.0, 0, 0))
	KinLoss.on_guard_net(m, ["guard", k.nid, owner_h.nid, real])
	ok(
		k.lost_owner == owner_h and k.lost_uid == String(real["uid"])
			and String(k.rec.get("uid", "")) == String(real["uid"]),
		"B1. the guard event gives the host's copy its real identity"
	)
	F.teleport(k.pos + Vector3(1.0, 0, 0))
	m._catch(F, k)
	var got: Dictionary = F.caught[0] if not F.caught.is_empty() else {}
	ok(
		String(got.get("uid", "")) == String(real["uid"]) and got.get("lost_from", "") == owner_h.pname
			and float(got.get("prev_trust", 0.0)) == float(real.get("trust", 50.0)),
		"B1. the host's scan takes the real record as someone's lost Boki (not a wild copy)"
	)
	ok(KinTrack.tracked(F) and KinTrack.captor_for(m, owner_h.team) == F, "B1. and the bond starts for the owner")
	# an event ahead of the copy: kept until the copy is made
	var x := ["guard", "zz9", owner_h.nid, real]
	KinLoss.on_guard_net(m, x)
	var late := m.give_kin(owner_h, real)
	late.nid = "zz9"
	late.rec = {"species": late.species, "level": 1, "name": "x", "traits": {}}
	KinLoss.apply_pending(m, late)
	ok(
		late.lost_owner == owner_h and String(late.rec.get("uid", "")) == String(real["uid"]),
		"B1. an early guard event waits for the copy"
	)
	# M1: a cradle left on the copy by an owner who went away does not block scans for ever
	var pk := m.give_kin(owner_h, real)
	pk.remote = true
	pk.rescue_t = 1.0
	pk.net_t = m.time
	ok(KinLoss.cradled(pk), "M1. a fresh cradle on the copy counts")
	owner_h.out = true
	ok(not KinLoss.cradled(pk), "M1. ...not once its owner is out of the match")
	owner_h.out = false
	pk.net_t = m.time - 5.0
	ok(not KinLoss.cradled(pk), "M1. ...nor when the snapshots stopped")
	# M2: a copy that stands up again can be scanned again
	pk.net_t = m.time
	var it: Array = m._ser(pk)
	it[13] = 0.0
	pk.dead = true
	pk.catch_prog = 5.0
	m._net_apply(pk, it)
	ok(not pk.dead and pk.catch_prog == 0.0, "M2. a copy that comes back to life asks for a fresh scan")
	pk.catch_prog = 5.0
	KinLoss._stand_guard(m, owner_h, pk)
	ok(pk.catch_prog == 0.0, "M2. a new guard starts with no scan asked for")
	# M4: a copy being carried is not pushed round by body separation
	pk.rescue_t = 1.0
	pk.net_t = m.time
	pk.state = "dazed"
	pk.teleport(P.pos + Vector3(0.2, 0, 0))
	var before := pk.pos
	m._separate()
	ok(pk.pos.distance_to(before) < 0.001, "M4. a copy with cradle progress (a carried Boki) is left out of separation")
	pk.rescue_t = 0.0
	owner_h.remote = false
	# M3: no pick-up in the middle of another channel
	var g2 := _loot_guard()
	var bx := Life.box_of(m, P)
	Life.bring_back(m, P, bx["pos"], 0.5, false)
	P.hp = P.max_hp
	P.teleport(g2.pos + Vector3(0.5, 0, 0))
	P.vel = Vector3.ZERO
	for i in int(round(0.5 / Match.DT)):
		P.drink_t = 1.0
		_run_for(Match.DT)
	ok(not g2.rescue_on, "M3. no pick-up while drinking a tonic")
	P.drink_t = 0.0
	for i in int(round(0.5 / Match.DT)):
		P.box_rev_at = m.time
		_run_for(Match.DT)
	ok(not g2.rescue_on, "M3. no pick-up while reviving at a box")
	_run_for(0.5)
	ok(g2.rescue_on, "M3. and it picks up once the channel is over")
	# safe tier: a cradle in progress is cleared when the owner dies
	_fresh(1)
	P.kin.rescue_t = 2.0
	P.kin.rescue_on = true
	_die()
	ok(not P.kin.rescue_on and P.kin.rescue_t == 0.0, "minor. a safe-tier death clears a cradle in progress")

## An online client is the captor: the host's "caught" event gives them the Boki and the bond, and dying hands it back.
func _client_captor() -> void:
	_fresh(2)
	F.remote = true
	var rec := Save.new_kin("cindle", "Ash")
	var wk := m.spawn_wild(rec, P.pos + Vector3(3, 0, 0), true)
	m._net_ev(["caught", wk.nid, P.nid, rec, F.nid], "")
	ok(
		P.caught.size() == 1 and KinTrack.tracked(P) and not KinTrack.entries(P).is_empty(),
		"1. the captor's own game gets the Boki and the bond from 'caught'"
	)
	m.knock(P, F, {})
	ok(
		P.caught.is_empty() and not KinTrack.tracked(P),
		"1. a client captor knocked: the Boki leaves their box and the bond ends"
	)
	F.remote = false

func _review_fixes() -> void:
	# 5. a second death before the cradle: one lost entry, one guard
	var g := _loot_guard()
	var bx := Life.box_of(m, P)
	Life.bring_back(m, P, bx["pos"], 0.5, false)
	_run_for(0.3)
	m.eliminate(P, F, "shot")
	var guards := m.kins.filter(func(k): return KinLoss.guarding(k) and k.owner_h == P)
	ok(
		m.player_lost.size() == 1 and guards.size() == 1 and guards[0] == g,
		"5. dying again before the cradle: one lost entry, one guard (%d, %d)" % [m.player_lost.size(), guards.size()]
	)

	# 3. cradle against scan
	g = _loot_guard()
	bx = Life.box_of(m, P)
	Life.bring_back(m, P, bx["pos"], 0.5, false)
	P.teleport(g.pos + Vector3(0.8, 0, 0))
	_run_for(1.0)
	ok(g.rescue_t > 0.0 and g.state == "dazed", "3. the owner's cradle is under way (%.2f)" % g.rescue_t)
	ok(
		Capture.block_reason(F, g).contains("picking"),
		"3. an enemy cannot start a scan during it (%s)" % Capture.block_reason(F, g)
	)
	F.teleport(g.pos + Vector3(3.0, 0, 0))
	m._net_ev(["catch", g.nid, F.nid], "")
	ok(not g.dead and F.caught.is_empty(), "3. the host's catch handler refuses it too")
	ok(Capture.block_reason(P, g) != "" and Capture.block_reason(G, g) != "", "3. and the owner's side cannot scan it")
	# a scan under way stops the cradle starting
	g.scan_by = F
	g.scan_at = m.time
	_run_for(0.3)
	ok(not g.rescue_on and g.rescue_t <= 0.001, "3. a scan running drops the carry and the cradle does not restart")
	g.scan_by = null
	m._net_ev(["catch", g.nid, F.nid], "")
	ok(g.dead and F.caught.size() == 1, "3. with nobody cradling, the host's handler lets the scan through")
	_carry_checks()

	# 7. bots
	g = _loot_guard()
	Life.box_of(m, P)["empty"] = true            # (so the bots are not busy looting or reviving at the box)
	Life.box_of(m, P)["soul_until"] = 0.0
	G.ctrl = "bot"
	G.teleport(g.pos + Vector3(6.0, 0, 0))
	_run_for(8.0)
	ok(
		g.state == "dazed" and not g.dead and Capture.state(G).is_empty(),
		"7. a teammate bot does not scan its own side's guard"
	)
	g = _loot_guard()
	Life.box_of(m, P)["empty"] = true
	Life.box_of(m, P)["soul_until"] = 0.0
	F.ctrl = "bot"
	F.teleport(g.pos + Vector3(3.0, 0, 0))
	var t := 0.0
	while t < 40.0 and not g.dead:
		_run_for(0.5)
		t += 0.5
	ok(g.dead and F.caught.size() == 1, "7. an enemy bot still goes and scans it (%.1fs)" % t)

	# 8. leaving the match after the drop: the loss still lands in the save
	g = _loot_guard()
	var res: Array = m._resolve_lost()
	var rec: Dictionary = res[0]["rec"]
	Save.d = Save.fresh()
	var mine := Save.new_kin("zapple", "Pip")
	mine["uid"] = String(rec["uid"])
	Save.d["roster"] = [mine, Save.new_kin("cindle", "Ash")]
	Save.d["active"] = mine["uid"]
	var rr := {"extracted": false, "why": "left", "tier": 2, "lost_kin": res, "kin_runs": [], "caught": [], "gems": 0,
		"seeds": {}}
	Game.apply_result(rr)
	var L := Ransom.find(String(mine["uid"]))
	ok(
		not L.is_empty() and (L["rec"] as Dictionary).has("ransom") and not KinLoss.selectable(L["rec"]),
		"8. quitting after the drop still ransoms it"
	)
	ok(Save.kin(String(mine["uid"])).is_empty(), "8. and it is off the roster")
	res = [{"uid": "x", "fate": "rival", "holder": "Lerna", "rec": mine}]
	var m2 := {"uid": "z", "species": "cindle"}
	KinLoss.after_match(Save.d, m2, KinLoss.outcome_of(res[0]["fate"], res[0]["holder"]))
	ok(m2.get("lost_to", {}).get("by", "") == "Lerna", "8. captured_by on leave too")

	# 1/2/4/6 online, by calling the handlers: the owner's game is `m` (P local), the captor F lives in another game
	g = _loot_guard()
	bx = Life.box_of(m, P)
	Life.bring_back(m, P, bx["pos"], 0.5, false)
	P.hp = P.max_hp
	var grec: Dictionary = g.rec.duplicate(true)
	F.remote = true
	F.teleport(g.pos + Vector3(10.0, 0, 0))
	m._net_ev(["caught", g.nid, F.nid, grec, P.nid], "")
	ok(
		g.dead and KinTrack.tracked(F) and KinTrack.captor_for(m, P.team) == F,
		"1. a remote captor's scan: the 'caught' event starts the bond in the owner's game"
	)
	ok(m.player_lost.size() == 1 and m.player_lost[0]["holder"] == F, "6. and the owner's game records who holds it")
	var res2: Array = m._resolve_lost()
	ok(
		res2.size() == 1 and res2[0]["fate"] == "rival" and res2[0]["holder"] == F.pname,
		"6. so the end of the match says captured_by (not ransom)"
	)
	KinNet.on_event(m, ["kcmd", "unbond", F.nid, 0, 0, 0, String(grec["uid"])])
	ok(not KinTrack.tracked(F), "4. an 'unbond' from the captor's game ends the pull here")
	m._net_ev(["caught", g.nid, F.nid, grec, P.nid], "")
	F.out = true
	ok(KinTrack.captor_for(m, P.team) == null, "4. a captor who left the match is not pointed at")
	F.out = false
	# the captor falls in its own game: every game hears gdrop
	F.caught.append(grec.duplicate(true))
	var at := F.pos
	m._net_ev(["gdrop", P.nid, at.x, at.y, at.z, grec], "")
	ok(
		not g.dead and KinLoss.guarding(g) and g.pos.distance_to(at) < 3.0 and not KinTrack.tracked(F)
			and F.caught.is_empty(),
		"2. 'gdrop': the owner's game stands the same Boki up again where the captor fell, and it leaves their box"
	)
	ok(
		m.player_lost.size() == 1 and m.player_lost[0]["kin"] == g and m.player_lost[0]["holder"] == null,
		"2. and it counts as lost to nobody again"
	)
	ok(
		g.nid == P.nid + "k",
		"2. it keeps the owner's own Boki id (%s), so online the owner's game simulates it" % g.nid
	)
	ok(Net.owner_of("P7k") == "7", "2. (ids shaped P<peer>k belong to that peer)")
	# no original Kin to reuse: the spawn path takes a slot id as well
	g.dead = true
	m.kins.erase(g)
	m.ents_by_id.erase(g.nid)
	g.queue_free()
	KinLoss.on_gdrop(m, P.nid, grec, at)
	var g3 := _guard()
	ok(
		g3 != null and g3.nid == P.nid + "k",
		"2. a freshly made guard also gets a slot id (%s)" % (g3.nid if g3 else "none")
	)
	F.remote = false
