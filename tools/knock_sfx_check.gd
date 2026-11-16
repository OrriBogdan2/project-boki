extends RefCounted
## --knock-sfx-check: the squad cues (Juice._squad_cue, Sfx.CUES). Downing a rival Hunter plays
## knock_confirm once and finishing one plays elim_confirm once, for the attacker's squad only: you, or a
## squadmate; a rival downing a rival, a mob dying or a friendly knock play nothing. The cue has its own
## voice, so a flood of footsteps and hits never steals it. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("KNOCKSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _plays(cue: String) -> int:
	return int(Sfx.cue_plays.get(cue, 0))

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
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var mate: Hunter = m.hunters.filter(func(o): return o != P and o.team == P.team)[0]
	var foes: Array = m.hunters.filter(func(o): return o.team != P.team)
	var rival_a: Hunter = foes[0]
	var rival_b: Hunter = foes.filter(func(o): return o.team != rival_a.team)[0]
	var rest: Array = foes.filter(func(o): return o != rival_a and o != rival_b)
	ok(rest.size() >= 2, "a squadmate and rivals from two other teams (%d spare)" % rest.size())
	for o in m.hunters:
		if o != P: o.ctrl = "idle"
	var far := m.world.random_ground()
	for o in m.hunters:
		if o != P: o.teleport(far)
	for c in Sfx.CUES:
		ok(Sfx.has(c), "the %s sound is on file" % c)
	var k0 := _plays("knock_confirm")
	var e0 := _plays("elim_confirm")

	m.knock(rest[0], P, {})
	ok(_plays("knock_confirm") == k0 + 1 and _plays("elim_confirm") == e0, "you down a rival: knock cue once")
	ok(Sfx.cue_voice.stream == Sfx.streams["knock_confirm"], "the cue plays on its own voice")
	k0 += 1

	m.knock(rest[1], mate, {})
	ok(_plays("knock_confirm") == k0 + 1, "a squadmate downs a rival: your squad hears it")
	k0 += 1

	m.knock(rival_b, rival_a, {})
	ok(_plays("knock_confirm") == k0 and _plays("elim_confirm") == e0, "a rival downs another rival: silent")

	m.eliminate(rest[0], P, "shot", true)
	ok(_plays("elim_confirm") == e0 + 1 and _plays("knock_confirm") == k0, "you finish a Hunter: finish cue once")
	var fin: AudioStream = Sfx.streams["elim_confirm"]
	ok(Sfx.cue_voice.stream == fin and fin != Sfx.streams["knock_confirm"], "the finish cue is its own sound")
	e0 += 1

	m.eliminate(rest[1], mate, "shot", true)
	ok(_plays("elim_confirm") == e0 + 1, "a squadmate finishes a Hunter: your squad hears it")
	e0 += 1

	m.eliminate(rival_b, rival_a, "shot", true)
	ok(_plays("elim_confirm") == e0 and _plays("knock_confirm") == k0, "a rival finishes a rival: silent")

	var mob := m.spawn_mob("skitter", P.pos + Vector3(3, 0, 0))
	mob.hurt(mob.max_hp * 10.0, P, {"src": "test"})
	for i in 5: m.step(Match.DT)
	ok(mob.dead and _plays("elim_confirm") == e0 and _plays("knock_confirm") == k0, "a mob dying plays neither cue")

	for i in Sfx.POOL * 2:
		Sfx.play("step_stone", null, 0.0, 0.0)
		Sfx.play("hit", null, 0.0, 0.0)
		Sfx.play("step%d" % (i % 3), null, 0.0, 0.0)
	ok(Sfx.cue_voice.stream == fin and not Sfx.players.has(Sfx.cue_voice), "footsteps and hits leave the cue's voice")
	print("KNOCKSFX DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
