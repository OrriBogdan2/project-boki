extends RefCounted
## --tutorial-clean-check: the tutorial course has nothing random on it. After the build the only chest
## is the one the tutorial places, and no crates, pots, shrines, wild kin or mobs are out; the world
## makes no spots for them. Then a scripted run of the whole course: the scripted chest opens and the
## course never brings any wild kin or extra chest or breakable. And the tutorial's cooldowns run four times
## quicker, while a training match's do not.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TUTCLEAN %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	_built(m)
	var tut_cd := _cd_after(m, 1.0)
	ok(tut_cd < 6.5, "tutorial: a 10 s air-dash cooldown has %.1f s left after 1 s" % tut_cd)
	_run_course(m)
	var real := Match.new()
	main.add_child(real)
	real.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0})
	real.set_process(false)
	var real_cd := _cd_after(real, 1.0)
	ok(real_cd > 8.9, "training: the same cooldown has %.1f s left after 1 s" % real_cd)
	print("TUTCLEAN DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _built(m: Match) -> void:
	var w := m.world
	ok(w.chest_spots.is_empty() and w.break_spots.is_empty() and w.wild_spots.is_empty() and w.shrine_spots.is_empty(),
			"the world makes no chest, breakable, wild or shrine spots")
	ok(m.chests.size() == 1 and m.chests[0].get("tut", false), "one chest, the tutorial's own (%d)" % m.chests.size())
	ok(m.breaks.is_empty(), "no crates, pots or kegs (%d)" % m.breaks.size())
	ok(m.shrines.is_empty(), "no shrines (%d)" % m.shrines.size())
	var wild := m.kins.filter(func(k): return k.is_wild()).size()
	ok(wild == 0, "no wild kin (%d)" % wild)
	ok(m.mobs.is_empty(), "no mobs before the course asks for them (%d)" % m.mobs.size())

## Seconds left on a 10 s air-dash cooldown after `secs` of play.
func _cd_after(m: Match, secs: float) -> float:
	if m.tut:
		m.tut.ack()          # (past the intro card, where the match waits, and the first step's own reset)
		m.step(Match.DT)
	m.player.ex_cd = 10.0
	for i in int(secs / Match.DT):
		m.step(Match.DT)
	return m.player.ex_cd

func _run_course(m: Match) -> void:
	var t := 0.0
	var extra_chests := 0
	var extra_breaks := 0
	var wild := 0
	while t < 600.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		extra_chests = maxi(extra_chests, m.chests.filter(func(c): return not c.get("tut", false)).size())
		extra_breaks = maxi(extra_breaks, m.breaks.size())
		wild = maxi(wild, m.kins.filter(func(k): return k.is_wild()).size())
	ok(m.player.extracted, "the course runs to the exit (%.0fs)" % t)
	ok(m.chests.any(func(c): return c.get("tut", false) and c["open"]), "the scripted chest opened")
	ok(extra_chests == 0 and extra_breaks == 0, "no other chest or breakable ever appeared")
	ok(wild == 0, "no wild kin ever appeared (%d)" % wild)
