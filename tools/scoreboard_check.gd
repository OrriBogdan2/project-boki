extends RefCounted
## --scoreboard-check: the Tab squad board (SquadBoard) in a 30-Hunter match. Ten squads of three
## start with 10 left; the board lists only your squad (you first): a mate's hit plus your knock is
## an assist for them, your finish a kill for you, a death for the mate, the gear you wear and each
## Boki. Rival squads give nothing away (no rows, names or alive state); a squad wipe drops the count
## to 9. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SCOREBOARD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _count(row: Dictionary, p: int) -> int:
	return row["pips"].count(p)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 10, "squad": 3, "tier": 0, "length": 1e9, "seed": 31, "no_drop": true})
	m.set_process(false)
	for h in m.hunters:
		h.lives = 1
	var P: Hunter = m.player
	var s := SquadBoard.snapshot(m)
	ok(m.hunters.size() == 30 and s["left"] == 10, "30 hunters: 10 squads left")
	ok(s["crew"].size() == 3 and s["crew"][0]["me"], "your three hunters are listed, yours first")
	ok(s["crew"].all(func(e): return e["h"].team == P.team), "only your squad has rows")
	ok(not s.has("squads") and not s.has("total"), "rival squads have no rows, names or alive state")
	var foes: Array = m.hunters.filter(func(x): return x.team != P.team)
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	# the mate chips a rival, you knock it: an assist for the mate
	ok(mate.ak != null, "the mate has a kit that sees knocks")
	mate.ak.note_hit(foes[0])
	foes[0].last_hit_by = P
	m.knock(foes[0], P, {})
	mate.ak._tick_knocks()
	m.eliminate(foes[0], P, "finished")
	m.eliminate(mate, foes[1], "finished")
	P.gear[0] = {"id": Gear.ids_for(0)[0], "rar": 2}
	P.dmg_done = 321.0
	s = SquadBoard.snapshot(m)
	var me: Dictionary = s["crew"][0]
	var mrow: Dictionary = s["crew"].filter(func(e): return e["h"] == mate)[0]
	ok(me["k"] == 1 and me["dmg"] == 321, "your row: 1 kill, 321 damage (%d, %d)" % [me["k"], me["dmg"]])
	ok(mrow["a"] == 1 and mrow["d"] == 1, "the mate: 1 assist, 1 death (%d, %d)" % [mrow["a"], mrow["d"]])
	ok(mrow["pip"] == SquadBoard.Pip.OUT and me["pip"] == SquadBoard.Pip.ALIVE, "the mate shows out, you alive")
	ok(me["gear"].size() == Gear.SLOTS.size() and me["gear"][0]["rar"] == 2, "your worn gear is listed with rarity")
	var crew_kin: Array = m.hunters.filter(func(x): return x.team == P.team and x.kin != null)
	var shown: Array = s["crew"].filter(func(e): return not e["boki"].is_empty() and e["boki"]["lvl"] >= 1)
	ok(shown.size() == crew_kin.size(), "a Boki with its level for each hunter that has one (%d)" % shown.size())
	for h in m.hunters.filter(func(x): return x.team == foes[0].team):
		m.eliminate(h, P, "finished")
	s = SquadBoard.snapshot(m)
	ok(s["left"] == 9, "a squad wipe: 9 left (%d)" % s["left"])
	ok(String(s["ways"]) != "" or m.exits.list.is_empty(), "the Ways Out line is filled (%s)" % s["ways"])
	print("SCOREBOARD CHECK DONE, failures: ", bad)
	main.get_tree().quit()
