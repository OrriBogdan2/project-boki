extends RefCounted
## --last-alive-check: the last hunter up in a squad of two or more (LastAlive) gets a glow everyone can
## see, +8% move speed and a slow self-heal; it ends the moment a teammate is revived. Solos never get it,
## and a teammate who extracted is not a dead one. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LASTALIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _start(main: Node, squad: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": squad, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	for o in m.hunters:
		o.ctrl = "idle"
		if o != m.player: o.teleport(m.world.random_ground())
	return m

func _run_for(m: Match, secs: float) -> void:
	for i in int(round(secs / Match.DT)):
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(Match.DT)

func _aura(h: Hunter) -> bool:
	return h.get_node_or_null(LastAlive.NODE) != null

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := _start(main, 2)
	var P: Hunter = m.player
	var mate: Hunter = null
	for o in m.hunters:
		if o != P and o.team == P.team: mate = o
	ok(mate != null, "a squad of two has a teammate")
	_run_for(m, 0.5)
	ok(not LastAlive.active(m, P) and not _aura(P), "both up: no aura")
	mate.downed = true
	mate.down_hp = Data.MATCH["down_hp"]      # (the wisp's bleed-out health, as Match.knock sets it)
	_run_for(m, 0.5)
	ok(LastAlive.active(m, P) and _aura(P), "teammate down: the last one up has the aura")
	ok(not LastAlive.active(m, mate) and not _aura(mate), "the downed one does not")
	var seen := false
	for o in m.hunters:
		if o.team != P.team and LastAlive.active(m, o): seen = true
	ok(not seen, "nobody on a full squad has it")
	ok(absf(P.buff("move_speed") - LastAlive.SPEED) < 0.001, "move speed +%.0f%%" % (P.buff("move_speed") * 100.0))
	P.hp = P.max_hp * 0.5
	P.regen_wait = 3.0
	var h0 := P.hp
	_run_for(m, 1.0)
	ok(P.hp <= h0 + 0.01, "no mending while a hit is fresh")
	P.regen_wait = 0.0
	h0 = P.hp
	_run_for(m, 2.0)
	ok(absf((P.hp - h0) / 2.0 - LastAlive.MEND_PER_S) < 0.2, "mends %.2f hp/s" % ((P.hp - h0) / 2.0))
	m.revive_hunter(mate, P)
	_run_for(m, 0.6)
	ok(not LastAlive.active(m, P) and not _aura(P), "teammate revived: aura gone")
	ok(P.buff("move_speed") == 0.0, "and the speed buff lapses")
	mate.downed = false
	mate.out = true
	_run_for(m, 0.2)
	ok(LastAlive.active(m, P), "teammate dead: still the last one up")
	mate.extracted = true
	_run_for(m, 0.2)
	ok(not LastAlive.active(m, P) and not _aura(P), "teammate extracted: not alone")
	m.queue_free()
	var solo := _start(main, 1)
	_run_for(solo, 0.5)
	var any := false
	for o in solo.hunters:
		if LastAlive.active(solo, o) or _aura(o): any = true
	ok(not any, "solos: no aura for anyone")
	print("LASTALIVE DONE, failures: ", bad)
	main.get_tree().quit()
