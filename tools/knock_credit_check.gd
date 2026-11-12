extends RefCounted
## --knock-credit-check: one rule for who is credited with a knock (KnockCredit). The last hit is the knocker;
## a rival hunter who damaged the victim inside ASSIST_WINDOW is an assister, outside it is nobody; a burn is
## credited to whoever lit it and counts as damage; a Boki's blow is its owner's; a hit on a wisp earns nothing.
## A kit hears it as ArchKit.credited: the knocker's knocks and knocks_seen go up, an assister's knocks_seen only.

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("KNOCKCREDIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(sec: float) -> void:
	var until := m.time + sec      # (match time: a hit's hitstop holds it still)
	while m.time < until:
		m.step(Match.DT)

## The victim back on its feet, full health and unprotected, with no history.
func _stand(v: Hunter) -> void:
	Life.bring_back(m, v, v.pos, 1.0, false)
	v.inv_t = 0.0
	v.armor = 0.0
	v.shield = 0.0
	v.kin_shield = 0.0
	v.burn_t = 0.0
	v.hp = v.max_hp
	KnockCredit.of(m).hits.clear()

func _hit(by: Ent, v: Hunter, dmg: float, o := {"src": "shot"}) -> void:
	v.hurt(dmg, by, o)

## The numbers that tell who was credited: [knocks, knocks_seen] for each hunter given.
func _seen(hs: Array) -> Array:
	return hs.map(func(x): return [x.knocks, x.ak.knocks_seen])

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var mine: Array = m.hunters.filter(func(x): return x.team == 0)
	var A: Hunter = mine[0]
	var B: Hunter = mine[1]
	var V: Hunter = m.hunters.filter(func(x): return x.team != 0)[0]
	var home := A.pos
	for h in m.hunters:
		if h != A and h != B and h != V: h.teleport(home + Vector3(60, 0, 0))
	B.teleport(home + Vector3(2, 0, 0))
	V.teleport(home + Vector3(0, 0, 4))
	var w := float(KnockCredit.ASSIST_WINDOW)

	var s0 := _seen([A, B])
	_stand(V)
	V.hp = 5.0
	_hit(A, V, 20.0)
	var s1 := _seen([A, B])
	ok(V.downed and s1[0][0] == s0[0][0] + 1 and s1[0][1] == s0[0][1] + 1,
			"last hit: the one who dealt it is the knocker")
	ok(s1[1][1] == s0[1][1] and m.feed.back()["text"].contains("knocked"),
			"last hit: a teammate who did nothing gets no credit")

	_hit(B, V, 20.0)
	_run(0.3)
	ok(_seen([A, B]) == s1, "a hit on a wisp is no knock and no assist")

	_stand(V)
	_hit(B, V, 20.0)
	_run(w - 1.0)
	V.hp = 5.0
	_hit(A, V, 20.0)
	var s2 := _seen([A, B])
	ok(V.downed and s2[0][0] == s1[0][0] + 1 and s2[1][0] == s1[1][0] and s2[1][1] == s1[1][1] + 1,
			"assist inside the window: B hit it %.0fs before A knocked it (A knocker, B assister)" % (w - 1.0))

	_stand(V)
	_hit(B, V, 20.0)
	m.time += w + 0.5      # (not stepped: B's kit keeps hurting V by itself, which counts as damage)
	V.hp = 5.0
	_hit(A, V, 20.0)
	var s3 := _seen([A, B])
	ok(V.downed and s3[0][0] == s2[0][0] + 1 and s3[1] == s2[1],
			"assist outside the window: a hit %.1fs before earns nothing" % (w + 0.5))

	_stand(V)
	_hit(A, V, 1.0, {"src": "abil", "burn": 60.0, "burn_for": 3.0})
	_hit(B, V, 20.0)
	V.hp = 2.0
	_run(0.5)
	var s4 := _seen([A, B])
	ok(V.downed and s4[0][0] == s3[0][0] + 1 and s4[1][0] == s3[1][0] and s4[1][1] == s3[1][1] + 1,
			"a DoT finish: the burn's owner is the knocker even after a teammate's later hit, who is the assister")

	_stand(V)
	var rec := Save.new_kin("cindle", "", 1)
	var boki := Kin.new()
	boki.init_kin(m, "kc_boki", "cindle", rec, A)
	m.add_child(boki)
	m.kins.append(boki)
	A.kin = boki
	boki.state = "away"      # (stays out of the fight: the hits below are scripted)

	V.hp = 5.0
	_hit(boki, V, 20.0, {"src": "kin"})
	var s5 := _seen([A, B])
	ok(V.downed and s5[0][0] == s4[0][0] + 1 and s5[0][1] == s4[0][1] + 1 and s5[1] == s4[1],
			"a Boki finish: its owner is the knocker")

	_stand(V)
	var s6 := _seen([A, B])
	_hit(boki, V, 20.0, {"src": "kin"})
	_run(1.0)
	V.hp = 5.0
	_hit(B, V, 20.0)
	var s7 := _seen([A, B])
	ok(V.downed and s7[1][0] == s6[1][0] + 1 and s7[0][0] == s6[0][0] and s7[0][1] == s6[0][1] + 1,
			"a teammate finishing a Boki's target: the finisher is the knocker, the Boki's owner an assister")
	print("KNOCK CREDIT CHECK DONE, failures: ", bad)
	main.get_tree().quit()
