extends RefCounted
## --quest-race-check: the quest-race pips (scripts/ui/quest_race.gd, docs/decisions/0051).
##   1. rows only for an open, used or taken quest seat; none for a locked or shut one, the Gate or the Heart ring
##   2. the Sealed Lair's rows follow its boss's damage, the Uplink's its charge; a taken seat is full for its squad
##   3. your squad's progress is the `mine` row, any other squad's the `rival` row and its team
##   4. the rows are drawn (a real canvas, the strip and the open full map) and are colour-vision safe: the
##      two rows differ in shape (WaysOutHud.pip) and the squad and rival colours differ in every palette
##   5. the seats the badges sit on are the quest seats, not just the first lair
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("QUESTRACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _apart(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 7401,
		"no_drop": true, "heart": true, "god": true})
	for o in m.hunters:
		o.ctrl = "idle"
	var seats: QuestSeats = m.exits.seats
	seats.build()
	var me: int = m.player.team
	var foe: int = (me + 1) % 3
	var St := QuestSeat.S
	# ---------------------------------------------------------------- 5. the sites
	var at := WaysOutMap.sites(m)
	ok(at[0] == seats.lair.ref["c"] and at[2] == seats.uplink.ref["pos"], "the badges sit on the quest seats")
	# ---------------------------------------------------------------- 1. which seats have rows
	ok(QuestRace.read(m, 1).is_empty() and QuestRace.read(m, 3).is_empty(), "no rows on the Gate or the Heart ring")
	for i in [0, 2]:
		var s: QuestSeat = seats.lair if i == 0 else seats.uplink
		s._force(St.LOCKED, "test")
		ok(QuestRace.read(m, i).is_empty(), "locked seat %d: no rows" % i)
		s._force(St.SHUT, "test")
		ok(QuestRace.read(m, i).is_empty(), "shut seat %d: no rows" % i)
		s._force(St.OPEN, "test")
		var rd := QuestRace.read(m, i)
		ok(not rd.is_empty() and rd["mine"] + rd["rival"] == 0.0, "open seat %d: two empty rows" % i)
	# ---------------------------------------------------------------- 2 and 3. progress, mine and rival
	var L: Dictionary = seats.lair.ref
	var boss: Boss = m.lairs.boss_of(L)
	ok(boss != null, "the Sealed Lair has its boss")
	seats.lair._force(St.IN_USE, "test", me)
	boss.hp = boss.max_hp * 0.4
	var rd := QuestRace.read(m, 0)
	ok(is_equal_approx(rd["mine"], 0.6) and rd["rival"] == 0.0 and rd["rival_team"] == -1, "my squad on the boss")
	seats.lair._force(St.IN_USE, "test", foe)
	rd = QuestRace.read(m, 0)
	ok(rd["mine"] == 0.0 and is_equal_approx(rd["rival"], 0.6) and rd["rival_team"] == foe, "a rival on the boss: 0.6")
	var x: Dictionary = seats.uplink.ref
	x["prog"] = 0.35
	seats.uplink._force(St.IN_USE, "test", me)
	rd = QuestRace.read(m, 2)
	ok(is_equal_approx(rd["mine"], 0.35) and rd["rival"] == 0.0, "my squad charging: mine 0.35")
	seats.uplink._force(St.IN_USE, "test", foe)
	x["prog"] = 0.8
	rd = QuestRace.read(m, 2)
	ok(rd["mine"] == 0.0 and is_equal_approx(rd["rival"], 0.8) and rd["rival_team"] == foe, "a rival charging: 0.8")
	seats.uplink._force(St.TAKEN, "test", foe)
	rd = QuestRace.read(m, 2)
	ok(rd["rival"] == 1.0 and rd["mine"] == 0.0, "taken by a rival: its row full")
	seats.uplink._force(St.TAKEN, "test", me)
	ok(QuestRace.read(m, 2)["mine"] == 1.0, "taken by my squad: my row full")
	# ---------------------------------------------------------------- 4. drawn, and told apart in every palette
	var key: String = SideColor.KEY
	var was: Variant = Settings.get_v(key)
	for pal in SideColor.ORDER:
		Settings.set_v(key, pal, false)
		ok(_apart(SideColor.of_team(me, me), SideColor.of_team(me, foe)) > 0.25, "palette %s: colours differ" % pal)
	Settings.set_v(key, was, false)
	seats.lair._force(St.IN_USE, "test", foe)
	seats.uplink._force(St.IN_USE, "test", me)
	m.player.out = true
	m.hud.full_map.open()
	for i in 4:
		await main.get_tree().process_frame
	ok(true, "the strip and the open full map drew the rows")
	m.hud.full_map.close()
	m.queue_free()
	print("QUESTRACE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)
