extends RefCounted
## --summon-cc-check: crowd control on a summoned Boki (docs/specs/SUMMON_CC.md, content/rules/summon_cc.json).
## Stun, root, slow, Daze, a knock, a pull (Displace.tow) and a tether land on it exactly as on a Hunter;
## Grounded does not (no dash, jump or glide to take); none of them ends a summon; a wisp (not out) takes
## the plain rules. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SUMMONCC %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

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
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var foe: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o != P and o.team != P.team and foe == null: foe = o
	var k: Kin = P.kin
	ok(k != null and foe != null, "a Boki and a rival Hunter")
	if k == null or foe == null:
		print("SUMMONCC DONE, failures: ", bad)
		main.get_tree().quit(1)
		return
	k.state = "active"
	k.cmd = "follow"
	k.settle = 1.0
	k.fly = {}
	k.teleport(P.pos + Vector3(2, 0, 0))
	foe.teleport(k.pos + Vector3(8, 0, 0))
	# (a) summoned: the Hunter's own path, minus Grounded
	k.set_meta("summoned", true)
	ok(SummonCc.summoned(k) and not SummonCc.summoned(P), "(a) a summoned Boki counts, a Hunter does not")
	var hp0 := k.hp
	k.hurt(5.0, foe, {"stun": 1.0, "root": 1.5, "slow": 2.0, "dr": true})
	ok(k.stun_t > 0.9 and k.root_t > 1.4 and k.slow_t > 1.9, "(a) stun, root and slow land")
	ok(k.hp < hp0 and not k.dead and k.state == "active", "(a) a hit does not end it (%s)" % k.state)
	KitStatus.apply(k, "rat", 3.0)
	ok(KitStatus.rattled(k), "(a) Daze lands (a damage window)")
	KitStatus.apply(k, "gnd", 3.0)
	ok(not KitStatus.grounded(k), "(a) Grounded does not")
	k.stun_t = 0.0
	var v0 := k.vel
	k.hurt(1.0, foe, {"kb": Vector2(40, 0)})
	ok(absf(k.vel.x - v0.x) > 1.0, "(a) a knock moves it (%.1f)" % (k.vel.x - v0.x))
	k.vel = Vector3.ZERO
	var x0 := k.pos.x
	m.displace.tow(k, foe, {"mode": "step", "dur": 1.0, "spd": 12.0, "gap": 1.0})
	for i in int(0.5 / Match.DT): m.step(Match.DT)
	ok(absf(k.pos.x - x0) > 0.5, "(a) a pull drags it")
	m.verbs.add_tether(foe, k, {"max": 6.0, "time": 3.0}, 1.0)
	var tethered := false
	for t in m.verbs.tethers:
		if t["b"] == k: tethered = true
	ok(tethered, "(a) a tether attaches")
	# (b) the same Grounded on the Hunter and on a Boki that is only a wisp (no meta): plain rules
	KitStatus.apply(foe, "gnd", 3.0)
	ok(KitStatus.grounded(foe), "(b) a Hunter is still Grounded")
	k.remove_meta("summoned")
	ok(not SummonCc.summoned(k) and not SummonCc.immune(k, "gnd"), "(b) not summoned: no immunity")
	print("SUMMONCC DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
