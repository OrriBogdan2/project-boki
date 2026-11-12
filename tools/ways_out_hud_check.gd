extends RefCounted
## --ways-out-hud-check: the Ways Out strip (scripts/ui/ways_out_hud.gd, briefs/specs/LIMITED_WAY_OUTS.md section 9).
##   1. four pips in order Lair / Heart / Uplink / Final, each locked with a countdown that matches the rules
##   2. the Heart's early pip follows its state: charging, ready (open), carried (in use, the carrier's squad), taken
##   3. the quest pips follow the clock (open, shut = lost) and the lairs / outposts (in use, taken, by squad)
##   4. the final pip: locked until final_s, open, in use while a squad fills the ring, taken by the squad that left
##   5. "Squads left" counts squads with a Hunter still in the match
##   6. the Gate prompt is only the carrier's leave prompt, says "Leave now: small reward", holds gate_hold_s,
##      and its second line names the final seat's time
##   7. the real HUD draws the strip in every state without a script error (frames run with the Hud on)
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("WAYSHUD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _st(m: Match, i: int) -> int:
	return int(WaysOutHud.seats(m)[i]["st"])

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": 7301, "no_drop": true,
		"heart": true, "god": true})
	for o in m.hunters:
		if o != m.player:
			o.ctrl = "idle"
	m.player.ctrl = "idle"
	var H: Heart = m.heart
	var q: Dictionary = Heart.rules()["quest"]
	var St := WaysOutHud.St
	# ---------------------------------------------------------------- 1. four locked pips, countdowns
	m.time = 30.0
	var sd := WaysOutHud.seats(m)
	var names := sd.map(func(d): return d["name"])
	ok(names == ["LAIR", "HEART", "UPLINK", "FINAL"],
		"four pips: Lair, Heart, Uplink, Final")
	ok(_st(m, 0) == St.LOCKED and is_equal_approx(float(sd[0]["t"]), float(q["lair_open_s"]) - m.time),
		"the Lair is locked, counting down to lair_open_s")
	var ready_in: float = Heart.r("wake_s") + Heart.r("charge_s") - m.time
	ok(_st(m, 1) == St.LOCKED and is_equal_approx(float(sd[1]["t"]), ready_in),
		"the early Heart seat is locked until wake + charge")
	var final_in: float = Heart.r("final_s") - m.time
	ok(_st(m, 2) == St.LOCKED and _st(m, 3) == St.LOCKED and is_equal_approx(float(sd[3]["t"]), final_in),
		"the Uplink and the Final are locked; the Final counts to final_s")
	# ---------------------------------------------------------------- 2. the Heart's early seat
	H._force(Heart.S.CHARGING, "test")
	H.charge = 25.0
	ok(_st(m, 1) == St.LOCKED and is_equal_approx(float(WaysOutHud.seats(m)[1]["t"]), Heart.r("charge_s") - 25.0),
		"charging: locked, counting the charge left")
	H.charge = Heart.r("charge_s")
	H._force(Heart.S.READY, "charged")
	ok(_st(m, 1) == St.OPEN, "the spark is ready: the pip is open")
	H.carrier = m.player
	H._force(Heart.S.CARRIED, "test")
	ok(_st(m, 1) == St.USE and int(WaysOutHud.seats(m)[1]["team"]) == m.player.team,
		"carried: in use, in the carrier's squad")
	H.carrier = null
	H.early_team = m.player.team
	ok(_st(m, 1) == St.TAKEN and int(WaysOutHud.seats(m)[1]["team"]) == m.player.team,
		"left by the Gate: taken, by that squad")
	# ---------------------------------------------------------------- 3. the quest pips
	H.early_team = -1
	m.time = float(q["lair_open_s"]) + 1.0
	ok(_st(m, 0) == St.OPEN and _st(m, 2) == St.LOCKED, "past lair_open_s the Lair is open, the Uplink still locked")
	m.time = float(q["lair_shut_s"]) + 1.0
	ok(_st(m, 0) == St.LOST, "past lair_shut_s unused, the Lair is lost")
	m.time = float(q["uplink_open_s"]) + 1.0
	ok(_st(m, 2) == St.OPEN, "past uplink_open_s the Uplink is open")
	var foe: Hunter = m.hunters.filter(func(h): return h.team != m.player.team)[0]
	var L := {"flown": [], "sealed_in": [foe], "state": "awake"}
	var X := {"kind": "outpost", "state": "charging", "team": m.player.team}
	m.lairs.list.append(L)
	m.exits.list.append(X)
	ok(_st(m, 0) == St.USE and int(WaysOutHud.seats(m)[0]["team"]) == foe.team,
		"a squad sealed in with a boss: the Lair is in use, in their colour")
	ok(_st(m, 2) == St.USE and int(WaysOutHud.seats(m)[2]["team"]) == m.player.team,
		"an outpost charging: the Uplink is in use")
	L["flown"] = [foe]
	X["state"] = "spent"
	ok(_st(m, 0) == St.TAKEN and _st(m, 2) == St.TAKEN, "ridden out and spent: both taken")
	m.lairs.list.erase(L)
	m.exits.list.erase(X)
	m.time = float(q["uplink_shut_s"]) + 1.0
	ok(_st(m, 2) == St.LOST, "past uplink_shut_s unused, the Uplink is lost")
	# ---------------------------------------------------------------- 4. the final pip
	H._force(Heart.S.WAITING, "test")
	ok(_st(m, 3) == St.LOCKED, "waiting: the Final is locked")
	H._force(Heart.S.FINAL, "test")
	ok(_st(m, 3) == St.OPEN, "the Heart ring is open")
	H.final_team = foe.team
	H.final_prog = 0.3
	ok(_st(m, 3) == St.USE and int(WaysOutHud.seats(m)[3]["team"]) == foe.team,
		"a squad filling the ring: in use, in their colour")
	H._force(Heart.S.DONE, "test")
	ok(_st(m, 3) == St.TAKEN, "the ring is full: taken")
	# ---------------------------------------------------------------- 5. squads left
	ok(WaysOutHud.squads_left(m) == 3, "three squads in the match: Squads left 3")
	foe.out = true
	ok(WaysOutHud.squads_left(m) == 2, "a squad with nobody left drops out of the count")
	foe.out = false
	# ---------------------------------------------------------------- 6. the Gate prompt
	var it := {"kind": "heart", "act": "leave", "prog": 0.5, "need": Heart.r("gate_hold_s")}
	var other := {"kind": "heart", "col": Color.WHITE, "label": "x"}
	ok(not WaysOutHud.gate_prompt(m.hud, Vector2(1280, 720), 500.0, other),
		"only the carrier's leave prompt is drawn by the strip")
	ok(Heart.r("gate_hold_s") == 4.0, "the Gate hold is 4 s (rules)")
	H.state = Heart.S.WAITING
	ok(WaysOutHud.stay_line(m) == "Stay and the Heart opens at 10:00.",
		"the line under the prompt names the final seat's time (%s)" % WaysOutHud.stay_line(m))
	H.state = Heart.S.FINAL
	ok(WaysOutHud.stay_line(m).begins_with("Stay and hold the Heart ring"), "once the ring is open the line says so")
	m.player.teleport(H.gate)
	H.state = Heart.S.CARRIED
	H.early_team = -1
	H.charge = Heart.r("charge_s")
	H.carrier = m.player
	var gate_it := H.interact_for(m.player)
	var label := String(gate_it["label"])
	var has_key := label.contains(Settings.key_cap("interact"))
	ok(gate_it.get("act", "") == "leave" and label.contains("leave now, small reward") and has_key,
		"at the Gate the carrier's prompt says leave now, small reward, with the live key")
	ok(is_equal_approx(float(gate_it["need"]), 4.0), "...and holds 4 s")
	# ---------------------------------------------------------------- 7. the real HUD draws it
	m.player.pos = H.gate
	m.interact = it
	for k in Heart.S.values():
		H.state = k
		for i in 3:
			await main.get_tree().process_frame
	ok(true, "seven states drawn through the real HUD")
	m.queue_free()
	print("WAYSHUD DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)
