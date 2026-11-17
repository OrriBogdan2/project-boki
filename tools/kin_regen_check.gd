extends RefCounted
## --kin-regen-check: a Boki mends on its own (KinRegen, content/rules/boki_system.json "regen").
## It starts a match at full health; on you (Return) it wins back 6% of max health a second; out beside
## you it waits 6s without damage, then mends 1.5%/s, and a hit restarts the wait; a downed Boki
## never regenerates. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("KINREGEN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run_for(m: Match, secs: float) -> void:
	for i in int(round(secs / Match.DT)): m.step(Match.DT)

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip"); d["roster"].append(rec); d["active"] = rec["uid"]
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
	for o in m.hunters:
		if o != P: o.teleport(m.world.random_ground() + Vector3(0, 0, 0))
	var k: Kin = P.kin
	ok(k != null, "the player has a Boki")
	if k == null:
		print("KINREGEN DONE, failures: ", bad); main.get_tree().quit(); return
	ok(is_equal_approx(k.hp, k.max_hp) and k.max_hp > 0.0, "a Boki starts the match at full health (%.1f / %.1f)" % [k.hp, k.max_hp])
	var rr := KinRegen.rules()
	# (a) carried: 6% of max a second
	k.stow()
	k.hp = k.max_hp * 0.4
	_run_for(m, 1.0)
	var gain := (k.hp - k.max_hp * 0.4) / k.max_hp
	ok(absf(gain - float(rr["carried_pct_s"])) < 0.012 and k.carried(), "(a) carried: +%.1f%% in 1s (want %.0f%%)" % [gain * 100.0, float(rr["carried_pct_s"]) * 100.0])
	ok(k.mending, "(a) it shows as mending")
	_run_for(m, 20.0)
	ok(is_equal_approx(k.hp, k.max_hp), "(a) carried it mends to full and stops (%.1f / %.1f)" % [k.hp, k.max_hp])
	# (b) out: nothing for 6s after damage, then 1.5%/s
	k.state = "active"; k.cmd = "follow"; k.settle = 1.0; k.target = null; k.fly = {}
	k.pos = P.pos + Vector3(1.5, 0, 0); k.prev = k.pos
	k.hp = k.max_hp * 0.5
	var h0 := k.hp
	_run_for(m, 5.0)
	ok(absf(k.hp - h0) < 0.01, "(b) out: no mending in the first 5s after a loss (%.2f -> %.2f)" % [h0, k.hp])
	_run_for(m, 1.5)
	var h1 := k.hp
	_run_for(m, 2.0)
	var g2 := (k.hp - h1) / k.max_hp / 2.0
	ok(k.hp > h1 + 0.01 and absf(g2 - float(rr["out_pct_s"])) < 0.006, "(b) out: after 6s it mends %.2f%%/s (want %.1f%%)" % [g2 * 100.0, float(rr["out_pct_s"]) * 100.0])
	# a hit restarts the wait
	k.hurt(3.0, foe)
	var h2 := k.hp
	_run_for(m, 3.0)
	ok(absf(k.hp - h2) < 0.01, "(b) a hit restarts the 6s wait (%.2f -> %.2f after 3s)" % [h2, k.hp])
	# (c) downed: no regen at all, even long after the last hit
	_run_for(m, 8.0)
	KinDowned.begin(k, false)
	k.down_t = 1e6; k.down_total = 1e6
	var away := m.world.random_ground()
	while away.distance_to(k.pos) < 15.0: away = m.world.random_ground()
	P.teleport(away)        # (the owner stays away: walking into a downed Boki rescues it)
	_run_for(m, 10.0)
	ok(k.state == "downed" and k.hp == 0.0, "(c) a downed Boki does not regen (%.2f hp after 10s)" % k.hp)
	# and a Boki that comes round starts its wait again
	KinDowned.come_round(k, false)
	var h3 := k.hp
	_run_for(m, 3.0)
	ok(k.hp <= h3 + 0.01, "(c) after coming round it waits again before mending (%.2f -> %.2f)" % [h3, k.hp])
	print("KINREGEN DONE, failures: ", bad)
	main.get_tree().quit()
