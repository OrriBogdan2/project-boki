extends RefCounted
## --scoreboard-check: the Tab squad board (SquadBoard) fills right in a 30-Hunter match. Ten squads
## of three start with 10 / 10 left; after two knocks the knocked show as downed (still 10 left);
## after a squad is wiped the count drops to 9 and that row is all out. Your squad's block lists
## levels, knocks and Boki, rivals have no names on the board, and the old Tab table is gone.
## Never touches the save.

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
	ok(m.hunters.size() == 30 and s["left"] == 10 and s["total"] == 10, "30 hunters: 10 / 10 squads")
	ok(s["squads"].all(func(q): return _count(q, SquadBoard.Pip.ALIVE) == 3), "every squad shows three alive pips")
	var mine_rows: Array = s["squads"].filter(func(q): return q["mine"])
	ok(mine_rows.size() == 1 and s["crew"].size() == 3, "one row is yours, with your three hunters listed")
	# two knocks: a rival and a mate
	var foes: Array = m.hunters.filter(func(x): return x.team != P.team)
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	P.knocks = 1
	P.lvl = 4
	m.knock(foes[0], P, {})
	m.knock(mate, foes[1], {})
	s = SquadBoard.snapshot(m)
	var foe_row: Dictionary = s["squads"].filter(func(q): return q["team"] == foes[0].team)[0]
	var my_row: Dictionary = s["squads"].filter(func(q): return q["mine"])[0]
	var down := _count(foe_row, SquadBoard.Pip.DOWNED)
	ok(down == 1 and _count(foe_row, SquadBoard.Pip.OUT) == 0, "a knocked rival: one downed pip")
	ok(_count(my_row, SquadBoard.Pip.DOWNED) == 1 and s["left"] == 10, "your mate is downed too; still 10 left")
	var me: Dictionary = s["crew"].filter(func(e): return e["me"])[0]
	ok(me["knocks"] == 2 and me["lvl"] == 4, "your row reads level %d, %d knocks" % [me["lvl"], me["knocks"]])
	var crew_kin: Array = m.hunters.filter(func(x): return x.team == P.team and x.kin != null)
	var shown: Array = s["crew"].filter(func(e): return e["boki"] != "")
	ok(shown.size() == crew_kin.size(), "your squad lists a Boki for each hunter that has one (%d)" % shown.size())
	# a squad wipe: finish the knocked rival's whole squad
	for h in m.hunters.filter(func(x): return x.team == foes[0].team):
		m.eliminate(h, P, "finished")
	s = SquadBoard.snapshot(m)
	foe_row = s["squads"].filter(func(q): return q["team"] == foes[0].team)[0]
	ok(s["left"] == 9 and s["total"] == 10, "a squad wipe: 9 / 10 left (%d / %d)" % [s["left"], s["total"]])
	ok(_count(foe_row, SquadBoard.Pip.OUT) == 3 and not foe_row["alive"], "the wiped squad is three out pips")
	ok(s["squads"].all(func(q): return not q.has("name")), "squad rows carry no names; only yours is listed below")
	ok(String(s["ways"]) != "" or m.exits.list.is_empty(), "the Ways Out line is filled (%s)" % s["ways"])
	ok(FileAccess.get_file_as_string("res://scripts/ui/hud.gd").find("_draw_scores") < 0, "the old Tab table is gone")
	print("SCOREBOARD CHECK DONE, failures: ", bad)
	main.get_tree().quit()
