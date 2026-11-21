extends RefCounted
## --scoreboard-check: the Tab board (SquadBoard) in a 30-Hunter match. It shows how many squads are
## left (10, then 9 after a wipe) and only YOUR squad: you first, then your mates, each with alive /
## downed / out, kills / deaths / assists, damage, gear and Boki. Rival squads leave no trace on it
## (no rows, names or alive state), and a knock plus the finish after it count one assist, not two.
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SCOREBOARD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

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
	ok(s.keys().size() == 2 and s["crew"].size() == 3, "the board holds the count and your three hunters only")
	var mine_only: bool = s["crew"].all(func(e): return e["h"].team == P.team)
	ok(s["crew"][0]["me"] and mine_only, "you first, then your mates; no rivals")
	ok(s["crew"].all(func(e): return e["status"] == SquadBoard.Status.ALIVE), "your squad reads alive")
	var foes: Array = m.hunters.filter(func(x): return x.team != P.team)
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	# a rival knocked by you with your mate's help, and your mate knocked by a rival
	DashReset.note(foes[0], mate)
	m.knock(foes[0], P, {})
	m.knock(mate, foes[1], {})
	m.eliminate(foes[0], P, "finished")
	s = SquadBoard.snapshot(m)
	var me: Dictionary = s["crew"][0]
	var mrow: Dictionary = s["crew"].filter(func(e): return e["h"] == mate)[0]
	ok(me["k"] == 1 and me["d"] == 0, "your row: %d kill, %d deaths" % [me["k"], me["d"]])
	ok(mrow["a"] == 1, "your mate's hit gives one assist for the knock and finish together (%d)" % mrow["a"])
	ok(mrow["status"] == SquadBoard.Status.DOWNED, "your knocked mate reads downed")
	ok(s["left"] == 10 and s["crew"].size() == 3, "a rival out: still 10 left, still only your three rows")
	P.gear[2] = {"id": Gear.ids_for(2)[0], "rar": 2}
	var crew_kin: Array = m.hunters.filter(func(x): return x.team == P.team and x.kin != null)
	s = SquadBoard.snapshot(m)
	ok(String(s["crew"][0]["gear"][2].get("id", "")) == Gear.ids_for(2)[0], "your row carries the gear you wear")
	var boki_rows: int = s["crew"].filter(func(e): return not e["boki"].is_empty()).size()
	ok(boki_rows == crew_kin.size(), "a Boki line for each hunter with one")
	ok(P.kin == null or int(s["crew"][0]["boki"]["lvl"]) >= 1, "your Boki's level is on the board")
	for h in m.hunters.filter(func(x): return x.team == foes[1].team):
		m.eliminate(h, P, "finished")
	s = SquadBoard.snapshot(m)
	ok(s["left"] == 9, "a squad wipe: 9 left (%d)" % s["left"])
	ok(s["crew"].all(func(e): return e["h"].team == P.team), "still no rival rows after the wipe")
	print("SCOREBOARD CHECK DONE, failures: ", bad)
	main.get_tree().quit()
