extends RefCounted
## --tut-aim-check (TutorialAim): the tutorial's E step never makes you wait on a cooldown. For each starter: an E
## aimed away from the group is a miss (the cooldown is back at once, the miss line shows under the banner, the
## step stays); the third miss pings the ground under the group; an E on the group is the step's move done, and
## the step ends once the group is down. A hero whose E strikes nothing (kin_no_hit) counts any cast.

const STARTERS := ["archer", "juggernaut", "gunslinger"]
const NO_HIT := "tender"
const NEAR := 2.5            # m from the nearest of the group the hunter stands for a try at it
const FAR := 10.0            # m away from it for a try aimed away (out of every E's reach)
const JUDGE_S := 6.0         # s at most a try takes to be judged (an E that stays up waits for its end)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("TUTAIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for hero in STARTERS + [NO_HIT]:
		var m := _start(main, hero)
		if hero == NO_HIT:
			_no_hit(m)
		else:
			_misses_then_hit(m, hero)
		m.queue_free()
		await main.get_tree().process_frame
	print("TUTAIM DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A tutorial run moved on to the E step (its picks made, its camp out).
func _start(main: Node, hero: String) -> Match:
	seed(5)
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0,
		"demo_kin": "cindle", "arch": hero, "cls": Arch.weight(hero)})
	m.set_process(false)
	var tu: Tutorial = m.tut
	tu.ack()          # (no intro card; not tut_test, whose driver would play the step itself)
	m.step(Match.DT)
	m.player.dropping = false         # (landed: the drop is the course's first beat, not this one)
	m.player.gliding = false
	m.player.teleport(tu.stop("land"))
	var at := Tutorial.steps().map(func(s): return s[0]).find(TutorialAim.STEP)
	tu._skip_to(at)
	tu._enter()
	for i in 10:
		m.step(Match.DT)
	return m

## Casts E from NEAR of the group, toward it (`at_group`) or straight away from it; steps until it is judged.
func _cast(m: Match, at_group: bool) -> void:
	var p := m.player
	var tu: Tutorial = m.tut
	var mb := tu.camps.nearest()
	var away := (p.pos - mb.pos) * Vector3(1, 0, 1)
	away = away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)
	p.teleport(mb.pos + away * (NEAR if at_group else FAR))
	p.vel = Vector3.ZERO
	var misses := tu.aim.misses
	p.inp["sig"] = true
	var held := tu.camps.ledger.map(func(e): return (e["mb"] as Mob).pos)      # (the group holds still: judged on aim)
	for i in int(JUDGE_S / Match.DT):
		p.inp["aim"] = mb.pos if at_group else p.pos + away * 6.0
		m.step(Match.DT)
		for j in held.size():
			(tu.camps.ledger[j]["mb"] as Mob).teleport(held[j])
		if tu.aim.hit or tu.aim.misses > misses:
			break

func _misses_then_hit(m: Match, hero: String) -> void:
	var tu: Tutorial = m.tut
	var p := m.player
	ok(tu.id() == "kin" and tu.camps.alive() > 0, "%s: on the E step with its group out" % hero)
	for n in TutorialAim.HELP_AFTER:
		var pings := m.pings.size()
		_cast(m, false)
		var line := tu.scout_hint()
		ok(tu.aim.misses == n + 1 and not tu.aim.hit, "%s: E away from the group is miss %d" % [hero, n + 1])
		var left := float(p.ak.cd["e"])
		ok(left <= 0.0, "%s: miss %d gives E straight back (cd %.2f)" % [hero, n + 1, left])
		ok(line == "Missed - aim at the group", "%s: miss %d says so under the banner ('%s')" % [hero, n + 1, line])
		var pinged := m.pings.size() > pings
		ok(pinged == (n + 1 >= TutorialAim.HELP_AFTER), "%s: miss %d pings the group: %s" % [hero, n + 1, pinged])
		ok(tu.id() == "kin", "%s: the step stays after miss %d" % [hero, n + 1])
	_cast(m, true)
	var done := tu.id() != "kin" or (tu.aim.hit and tu.flag)       # (a hit that downs the group ends the step at once)
	ok(done, "%s: E on the group is the step's move done (misses %d)" % [hero, tu.aim.misses])
	for e in tu.camps.ledger:
		if is_instance_valid(e["mb"]) and not (e["mb"] as Mob).dead:
			(e["mb"] as Mob).hurt(1e6, p, {})
	for i in 60:
		m.step(Match.DT)
	ok(tu.id() != "kin", "%s: with the group down the step is done (now %s)" % [hero, tu.id()])

func _no_hit(m: Match) -> void:
	var tu: Tutorial = m.tut
	_cast(m, false)
	ok(tu.aim.hit and tu.aim.misses == 0, "%s: an E that strikes nothing counts any cast" % NO_HIT)
