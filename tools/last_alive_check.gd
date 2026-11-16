extends RefCounted
## --last-alive-check: the last hunter up in a squad of two or more (LastAlive) gets a glow everyone can
## see, +8% move speed and a slow self-heal; it ends the moment a teammate is revived. Solos never get it,
## and a teammate who extracted is not a dead one. Its sounds are yours alone: a start sting, a heartbeat bed
## on the Music bus and a release on the revive, once each. Never touches the save.

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

func _heard(sname: String) -> int:
	return int(LastAlive.heard.get(sname, 0))

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
	LastAlive.heard = {}
	_run_for(m, 0.5)
	ok(not LastAlive.active(m, P) and not _aura(P), "both up: no aura")
	var foe: Hunter = null
	for o in m.hunters:
		if o.team != P.team and foe == null: foe = o
	foe.downed = true
	foe.down_hp = Data.MATCH["down_hp"]
	_run_for(m, 0.3)
	var foe_last := false
	for o in m.hunters:
		if o.team == foe.team and LastAlive.active(m, o): foe_last = true
	ok(foe_last and LastAlive.heard.is_empty(), "another squad's last one up: you hear nothing %s" % LastAlive.heard)
	foe.downed = false
	mate.downed = true
	mate.down_hp = Data.MATCH["down_hp"]      # (the wisp's bleed-out health, as Match.knock sets it)
	_run_for(m, 0.5)
	ok(LastAlive.active(m, P) and _aura(P), "teammate down: the last one up has the aura")
	ok(not LastAlive.active(m, mate) and not _aura(mate), "the downed one does not")
	var seen := false
	for o in m.hunters:
		if o.team != P.team and LastAlive.active(m, o): seen = true
	ok(not seen, "nobody on a full squad has it")
	ok(_heard("last_alive_start") == 1 and _heard(LastAlive.BED_KEY) == 1, "the start sting and the bed, once each")
	var bed: Dictionary = Sfx.loops.get(LastAlive.BED_KEY, {})
	var on_music := not bed.is_empty() and (bed["p"] as AudioStreamPlayer).bus == &"Music"
	ok(on_music, "the bed plays on the Music bus (ducks with the score)")
	ok(_heard("last_alive_end") == 0, "no release while it lasts")
	ok(absf(P.buff("move_speed") - LastAlive.SPEED) < 0.001, "move speed +%.0f%%" % (P.buff("move_speed") * 100.0))
	P.hp = P.max_hp * 0.5
	P.combat_at = m.time      # just hit (InCombat)
	var h0 := P.hp
	_run_for(m, 1.0)
	ok(P.hp <= h0 + 0.01, "no mending while a hit is fresh")
	P.combat_at = -99.0
	h0 = P.hp
	_run_for(m, 2.0)
	ok(absf((P.hp - h0) / 2.0 - LastAlive.MEND_PER_S) < 0.2, "mends %.2f hp/s" % ((P.hp - h0) / 2.0))
	m.revive_hunter(mate, P)
	_run_for(m, 0.6)
	ok(not LastAlive.active(m, P) and not _aura(P), "teammate revived: aura gone")
	ok(P.buff("move_speed") == 0.0, "and the speed buff lapses")
	var bed_on := Sfx.loop_on(LastAlive.BED_KEY)
	ok(_heard("last_alive_end") == 1 and not bed_on, "the revive: one release cue, the bed stops")
	ok(_heard("last_alive_start") == 1 and _heard(LastAlive.BED_KEY) == 1, "start and bed still once each")
	mate.downed = false
	mate.out = true
	_run_for(m, 0.2)
	ok(LastAlive.active(m, P), "teammate dead: still the last one up")
	mate.extracted = true
	_run_for(m, 0.2)
	ok(not LastAlive.active(m, P) and not _aura(P), "teammate extracted: not alone")
	ok(_heard("last_alive_end") == 1, "an extract is not a revive: no release cue")
	m.queue_free()
	var solo := _start(main, 1)
	_run_for(solo, 0.5)
	var any := false
	for o in solo.hunters:
		if LastAlive.active(solo, o) or _aura(o): any = true
	ok(not any, "solos: no aura for anyone")
	solo.queue_free()
	_trio(main)
	print("LASTALIVE DONE, failures: ", bad)
	main.get_tree().quit()

## A squad of three: the aura waits for BOTH teammates (KNOCKED or DEAD in the squad frames), and it
## lives on the hunter only, as a mixed rim that still shows on snow.
func _trio(main: Node) -> void:
	var m := _start(main, 3)
	var me: Hunter = m.player
	var mates := m.hunters.filter(func(o: Hunter) -> bool: return o != me and o.team == me.team)
	ok(mates.size() == 2, "a squad of three has two teammates")
	mates[0].downed = true
	_run_for(m, 0.3)
	ok(not _aura(me), "one of two knocked: no aura yet")
	mates[1].out = true
	_run_for(m, 0.3)
	ok(_aura(me), "one KNOCKED, one DEAD: the aura is on")
	ok(m.find_children(LastAlive.NODE, "", true, false).size() == 1, "on that hunter only")
	var rim := me.get_node(LastAlive.NODE).get_child(0) as MeshInstance3D
	var code := (rim.material_override as ShaderMaterial).shader.code
	ok("blend_mix" in code and not "blend_add" in code, "the rim is mixed, not added (reads on snow)")
	m.queue_free()
