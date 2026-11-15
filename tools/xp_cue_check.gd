extends RefCounted
## --xp-cue-check: the monster-kill cues (KillCues, hooked into Match.on_mob_dead). One soft tick per kill
## share for the local hunter (the killer, or a squadmate within SHARE_RADIUS), nothing on plain hits or
## for a squadmate out of range; the steal sting only on a contested last hit (another squad did more
## damage), in two variants (you stole it, you were robbed), heard by those two squads only; the files
## exist and the sounds are in the UI set. Never touches the save.

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("XPCUE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _heard(n: String) -> int:
	return (Sfx.recent.get(n, []) as Array).size()

## Exactly this many ticks, win stings and lost stings were heard since the last _kill.
func _cues(tick: int, won: int, lost: int, what: String) -> void:
	var got := [_heard("xp_tick"), _heard("steal_won"), _heard("steal_lost")]
	ok(got == [tick, won, lost], "%s (tick, won, lost: %s)" % [what, str(got)])

func _clear_heard() -> void:
	for n in ["xp_tick", "steal_won", "steal_lost"]:
		Sfx.recent.erase(n)
		Sfx.last_played.erase(n)

## A fresh skitter at `at`, health exactly the sum of the hits: each (hunter, damage) pair hits it in order.
func _kill(at: Vector3, hits: Array) -> void:
	_clear_heard()
	var mob := m.spawn_mob("skitter", at)
	var total := 0.0
	for h in hits: total += float(h[1])
	mob.max_hp = total
	mob.hp = total
	for h in hits:
		mob.hurt(float(h[1]), h[0], {})
	_drop(mob)

func _drop(mob: Mob) -> void:
	m.mobs.erase(mob)
	mob.queue_free()

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var mates: Array = m.hunters.filter(func(o): return o != P and o.team == P.team)
	var foes: Array = m.hunters.filter(func(o): return o.team != P.team)
	var team_b: int = foes[0].team
	var rival: Hunter = foes[0]
	var third: Hunter = foes.filter(func(o): return o.team != team_b)[0]
	ok(mates.size() == 1 and foes.size() >= 4, "a mate and two rival squads (%d, %d)" % [mates.size(), foes.size()])
	var far := m.world.random_ground()
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			o.teleport(far)
	var at := P.pos + Vector3(4, 0, 0)
	var mate: Hunter = mates[0]

	# (a) a plain solo kill: one tick, no sting
	_kill(at, [[P, 40.0]])
	_cues(1, 0, 0, "(a) a solo kill: one tick, no sting")

	# (b) hits that do not kill play nothing (no tick per DoT or hit)
	_clear_heard()
	var mob := m.spawn_mob("skitter", at)
	mob.max_hp = 1000.0
	mob.hp = 1000.0
	for i in 5: mob.hurt(10.0, P, {})
	_cues(0, 0, 0, "(b) five hits, no kill: silent")
	ok(mob.damage_by.get(P.team, 0.0) == 50.0, "(b) the squad's damage is tallied (%s)" % str(mob.damage_by))
	_drop(mob)

	# (c) a squadmate in range takes the last hit: you get the tick
	mate.teleport(at + Vector3(0, 0, 5))
	_kill(at, [[mate, 40.0]])
	_cues(1, 0, 0, "(c) a squadmate's kill within range: one tick for you")

	# (d) a squadmate out of range: nothing plays for you
	mate.teleport(at + Vector3(KillCues.SHARE_RADIUS + 10.0, 0, 0))
	P.teleport(at + Vector3(-KillCues.SHARE_RADIUS - 10.0, 0, 0))
	_kill(at, [[mate, 40.0]])
	_cues(0, 0, 0, "(d) a squadmate's kill, you outside the share radius: nothing")
	_kill(at, [[rival, 50.0], [mate, 10.0]])
	_cues(0, 0, 0, "(d) ... not even the steal sting")
	P.teleport(at + Vector3(-3, 0, 0))
	mate.teleport(far)

	# (e) a steal: a rival did the most damage, you took the last hit
	_kill(at, [[rival, 70.0], [P, 30.0]])
	_cues(1, 1, 0, "(e) you stole it: one tick and the steal_won sting")

	# (f) you did the most damage and the last hit: no sting
	_kill(at, [[rival, 20.0], [P, 60.0], [P, 20.0]])
	_cues(1, 0, 0, "(f) you did most of it and finished it: a tick, no sting")

	# (g) robbed: you did the most, a rival took the last hit: the steal_lost sting, no tick
	_kill(at, [[P, 70.0], [rival, 30.0]])
	_cues(0, 0, 1, "(g) you were robbed: steal_lost, no tick (kill XP is theirs)")

	# (h) robbed while you stand outside the share radius: silent
	P.teleport(at + Vector3(-KillCues.SHARE_RADIUS - 10.0, 0, 0))
	_kill(at, [[P, 70.0], [rival, 30.0]])
	_cues(0, 0, 0, "(h) robbed from beyond the share radius: nothing")
	P.teleport(at + Vector3(-3, 0, 0))

	# (i) a third squad hears nothing of a steal between two others
	_kill(at, [[third, 70.0], [rival, 30.0]])
	_cues(0, 0, 0, "(i) a steal between two other squads: nothing for you")

	# (j) a client has no damage tally: it is told the top team by the "mobdead" event
	_clear_heard()
	mob = m.spawn_mob("skitter", at)
	KillCues.on_kill(m, mob, P, team_b)
	_cues(1, 1, 0, "(j) top team from the event: the same tick and steal_won")
	_drop(mob)

	# (k) the sounds exist and are in the UI set
	var ui = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/ui.json"))
	for n in ["xp_tick", "steal_won", "steal_lost"]:
		var there: bool = FileAccess.file_exists("res://audio/%s.wav" % n) and ui["sounds"].has(n)
		ok(there, "(k) %s: file and UI set entry" % n)

	m.queue_free()
	print("XPCUE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
