extends RefCounted
## --hit-marker-check: the hit tick round the reticle (Reticle, fed by CombatBus.hit_landed).
##   1. one landed hit of yours on a rival raises exactly one tick, short
##   2. a zone (damage-over-time) tick, a teammate's hit, your Boki's hit, a hit on your own side and a
##      rival's hit on you raise none
##   3. a hit that knocks a rival Hunter down raises the stronger knock tick, and every tick is gone in 0.12 s
## Never touches the save.

const CAP_S := 0.12     # s: no tick may show longer than this

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HITMARKER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true})
	var P := m.player
	var r: Reticle = m.hud.reticle
	var foe: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	var mate: Hunter = m.hunters.filter(func(h): return h != P and h.team == P.team)[0]
	for h in m.hunters:
		if h != P:
			h.ctrl = "idle"
	# ---------------------------------------------------------------- 1. one hit, one tick
	var n := r.ticks
	CombatBus.hit_landed.emit(P, foe, 10.0, ["primary"])
	ok(r.ticks == n + 1 and r.tick_t > 0.0 and r.tick_t <= CAP_S and not r.tick_knock,
		"a fake hit raises one tick (%d, %.2f s)" % [r.ticks - n, r.tick_t])
	_clear(r)
	foe.hurt(10.0, P, {"src": "shot"})
	ok(r.ticks == n + 2 and not r.tick_knock, "a real shot through Ent.hurt raises one more (%d)" % (r.ticks - n))
	# ---------------------------------------------------------------- 2. none of these
	_clear(r)
	n = r.ticks
	foe.hurt(5.0, P, {"src": "abil", "ab": "utility", "tags": ["zone", "test"]})
	ok(r.ticks == n, "a zone (DoT) tick raises none")
	foe.hurt(10.0, mate, {"src": "shot"})
	ok(r.ticks == n, "a teammate's hit raises none")
	if P.kin:
		CombatBus.hit_landed.emit(P.kin, foe, 10.0, ["kin"])
		ok(r.ticks == n, "your Boki's hit raises none")
	CombatBus.hit_landed.emit(P, mate, 10.0, ["primary"])
	ok(r.ticks == n, "a hit on your own side raises none")
	CombatBus.hit_landed.emit(foe, P, 10.0, ["primary"])
	ok(r.ticks == n and r.tick_t == 0.0, "a hit on you raises none")
	# ---------------------------------------------------------------- 3. the knock, and the cap
	foe.armor = 0.0
	foe.hp = 4.0
	foe.hurt(20.0, P, {"src": "shot"})
	ok(r.ticks == n + 1 and r.tick_knock and r.tick_t <= CAP_S, "a knock raises the strong tick (%.2f s)" % r.tick_t)
	ok(foe.downed, "(the rival is down)")
	r.tick(CAP_S + 0.001)
	ok(r.tick_t == 0.0, "it's gone within %.2f s" % CAP_S)
	print("HITMARKER DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _clear(r: Reticle) -> void:
	r.tick(1.0)
