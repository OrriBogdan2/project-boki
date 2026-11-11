extends RefCounted
## --death-recap-check: the card you get when downed or out (scripts/ui/death_recap.gd). Never touches the save.
##  1. hits are kept per Hunter from CombatBus.hit_landed, grouped by source on one line, biggest first
##  2. a hit by a Hunter's ability reads as that ability's name and credits the Hunter (a Boki's hit credits
##     its owner), whose name is drawn in their squad colour (SideColor)
##  3. hits older than WINDOW_S fall off the card
##  4. downed by a foe: the last hit is the finisher; out: the card is fixed at the moment you went out
##  5. dead with a teammate up: after the short pause the camera follows them, the key cycles through
##     the living ones, a teammate who goes out is skipped, nobody left: no camera
##  6. the card draws without error, with the key's label from Settings.key_cap

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("RECAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(sec: float) -> void:
	for i in int(round(sec / Match.DT)):
		m.step(Match.DT)

func _calm(h: Hunter) -> void:
	h.inv_t = 0.0
	h.armor = 0.0
	h.shield = 0.0
	h.kin_shield = 0.0
	h.hp = h.max_hp

func _press() -> void:
	var ev := InputEventAction.new()
	ev.action = DeathRecap.CYCLE_ACTION
	ev.pressed = true
	m.recap._unhandled_input(ev)

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
		h.lives = 1
	var P: Hunter = m.player
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	var foe: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	foe.arch = "thief"
	foe.pname = "Foe"
	var knife := {"src": "abil", "ab": "utility", "tags": ["utility", "knife"]}
	_calm(P)
	P.hurt(10.0, foe, knife)
	P.hurt(5.0, foe, {"src": "shot"})
	P.hurt(4.0, null, {"src": "fall"})
	var hits := m.recap.recent(P, m.time)
	ok(hits.size() == 3, "three hits kept for the Hunter that took them (%d)" % hits.size())
	var line := DeathRecap.by_source(hits)
	ok(line == "Foe 15, the world 4", "damage grouped by source, biggest first (%s)" % line)
	ok(m.recap.recent(foe, m.time).is_empty(), "a Hunter's history holds only the hits it took")
	var knife_name := String(Arch.def("thief")["e"]["name"])
	ok(hits[0]["how"] == knife_name, "an ability hit reads as its ability (%s)" % hits[0]["how"])
	ok(hits[1]["how"] == "a weapon shot" and hits[2]["how"] == "a fall", "plain hits read in plain words")
	ok(hits[0]["hunter"] == foe and SideColor.of(m, foe) == SideColor.FOE,
		"the killer is the Hunter, drawn in the foe colour")
	_run(DeathRecap.WINDOW_S + 1.0)
	ok(m.recap.recent(P, m.time).is_empty(), "hits older than %d s fall off" % int(DeathRecap.WINDOW_S))
	_calm(P)
	P.hurt(P.max_hp * 2.0, foe, knife)
	ok(P.downed, "a lethal hit with a teammate up downs you")
	var down_hits := m.recap.recent(P, m.time)
	ok(down_hits.back()["hunter"] == foe and down_hits.back()["how"] == knife_name,
		"the card names the Hunter and ability that downed you")
	m.eliminate(P, foe, "finished")
	var died := float(P.get_meta("died_at"))
	ok(m.spectating() == null, "no camera on a teammate in the first moments after you go out")
	_run(DeathRecap.WINDOW_S + 1.0)
	ok(m.recap.recent(P, died).size() == down_hits.size(),
		"out: the card stays fixed at the moment you went out")
	for h in mates: h.ctrl = "idle"
	var cap := Settings.key_cap(DeathRecap.CYCLE_ACTION)
	ok(cap != "?", "the camera key has a label (%s)" % cap)
	ok(m.spectating() == mates[0], "a teammate is watched once you are out")
	_press()
	ok(m.spectating() == mates[1], "the key moves to the next teammate")
	_press()
	ok(m.spectating() == mates[0], "and round again")
	m.eliminate(mates[0], foe, "finished")
	ok(m.spectating() == mates[1], "a teammate who goes out is skipped")
	m.eliminate(mates[1], foe, "finished")
	ok(m.spectating() == null, "nobody left to watch: no camera")
	var cv := Control.new()
	main.add_child(cv)
	var drew := [false]
	cv.draw.connect(func():
		m.recap.draw(cv, Vector2(400, 100), P)
		drew[0] = true)
	cv.queue_redraw()
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(drew[0], "the card draws (down and out)")
	cv.queue_free()
	print("DEATH RECAP CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
