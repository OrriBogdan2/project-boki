extends RefCounted
## --ways-out-hud-check: the Ways Out strip (scripts/ui/ways_out_hud.gd, briefs/specs/LIMITED_WAY_OUTS.md section 9).
##   1. four pips in order Lair / Heart / Uplink / Final, each locked with a countdown that matches the rules
##   2. the Heart's early pip follows its state: charging, ready (open), carried (in use, the carrier's squad), taken
##   3. the quest pips follow the clock (open, shut = lost) and the QuestSeats (in use, taken, by squad; a won Lair
##      stays taken after its squad has landed, a ridden Uplink after its lift shut)
##   4. the final pip: locked until final_s, open, in use while a squad fills the ring, taken by the squad that left
##   6. the Gate prompt is only the carrier's leave prompt, says "Leave now: small reward", holds gate_hold_s,
##      and its second line names the final seat's time
##   7. the real HUD draws the strip in every state without a script error (frames run with the Hud on)
##   8. the quest tracker (scripts/ui/quest_tracker.gd) under the strip and above the message lane, only while your
##      squad is on a quest seat: the Uplink's charge or the boss's health taken off, the leading rival squad's
##      progress on a quest seat, the distance to the site; hidden with no seat of yours, out, or in the boss fight
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
	ok(_st(m, 0) == St.LOCKED and is_equal_approx(float(sd[0]["t"]), float(q["lair_open_s"]) - m.sess_time()),
		"the Lair is locked, counting down to lair_open_s")
	var ready_in: float = Heart.r("wake_s") + Heart.r("charge_s") - m.sess_time()
	ok(_st(m, 1) == St.LOCKED and is_equal_approx(float(sd[1]["t"]), ready_in),
		"the early Heart seat is locked until wake + charge")
	var final_in: float = Heart.r("final_s") - m.sess_time()
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
	m.time = float(q["lair_open_s"]) + 1.0 - m.sess_t0
	ok(_st(m, 0) == St.OPEN and _st(m, 2) == St.LOCKED, "past lair_open_s the Lair is open, the Uplink still locked")
	m.time = float(q["lair_shut_s"]) + 1.0 - m.sess_t0
	ok(_st(m, 0) == St.LOST, "past lair_shut_s unused, the Lair is lost")
	m.time = float(q["uplink_open_s"]) + 1.0 - m.sess_t0
	ok(_st(m, 2) == St.OPEN, "past uplink_open_s the Uplink is open")
	var foe: Hunter = m.hunters.filter(func(h): return h.team != m.player.team)[0]
	var qs: QuestSeats = m.exits.seats      # (their host moves, from the Sealed Lair and the Uplink's own outpost)
	qs.build()
	var L: Dictionary = qs.lair.ref
	var X: Dictionary = qs.uplink.ref
	m.time = float(q["lair_open_s"]) + 30.0 - m.sess_t0
	qs.tick(0.0)
	L["locked"] = true
	L["sealed_in"] = [foe]
	qs.tick(0.0)
	ok(_st(m, 0) == St.USE and int(WaysOutHud.seats(m)[0]["team"]) == foe.team,
		"a squad sealed in with a boss: the Lair is in use, in their colour")
	L["state"] = "cleared"
	L["won_by"] = foe.team
	L["victory"] = true
	qs.tick(0.0)
	L["sealed_in"] = []
	L["flown"] = []
	ok(_st(m, 0) == St.TAKEN and int(WaysOutHud.seats(m)[0]["team"]) == foe.team,
		"the boss down: the Lair is taken by that squad, and stays taken once they have flown and landed")
	m.time = float(q["uplink_open_s"]) + 1.0 - m.sess_t0
	qs.tick(0.0)
	X["state"] = "charging"
	X["team"] = m.player.team
	qs.tick(0.0)
	ok(_st(m, 2) == St.USE and int(WaysOutHud.seats(m)[2]["team"]) == m.player.team,
		"an outpost charging: the Uplink is in use")
	X["state"] = "open"
	qs.tick(0.0)
	X["state"] = "closed"
	X["taken"] = true
	ok(_st(m, 2) == St.TAKEN, "the lift ridden and shut: the Uplink stays taken")
	qs.uplink._force(QuestSeat.S.OPEN, "test")      # (unused again, for the shut row)
	X["state"] = "idle"
	X["team"] = -1
	X.erase("taken")
	m.time = float(q["uplink_shut_s"]) + 1.0 - m.sess_t0
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
	await _tracker(main, m)
	m.queue_free()
	print("WAYSHUD DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

# ---------------------------------------------------------------- 8. the quest tracker
## The quest tracker's rows, on the real HUD with the match paused (so the host does not move the seats).
func _tracker(main: Node, m: Match) -> void:
	m.set_process(false)
	var P: Hunter = m.player
	var foe: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	var qs: QuestSeats = m.exits.seats
	var x: Dictionary = qs.uplink_x()
	var b: Boss = m.lairs.boss_of(qs.lair.ref) if qs.lair else null
	ok(qs.uplink != null and b != null, "the map has both quest seats and the Sealed Lair has its boss")
	if qs.uplink == null or b == null:
		return
	ok(QuestTracker.WORDS.has(qs.lair.kind) and QuestTracker.WORDS.has(qs.uplink.kind),
		"both quest seats have their plain words")
	m.interact = {}
	var away := m.world.free_spot_near(x["pos"] + Vector3(40, 0, 0), [], 1.0, 0.45, 6.0)
	P.teleport(away)
	qs.lair._force(QuestSeat.S.LOCKED, "check")
	qs.uplink._force(QuestSeat.S.LOCKED, "check")
	var r := await _tracker_rect(main, m)
	ok(QuestTracker.seat_of(m, P.team) == null and not r.has_area(), "no quest seat in use: no tracker")
	x["state"] = "charging"
	x["team"] = P.team
	x["prog"] = 0.4
	qs.uplink._force(QuestSeat.S.IN_USE, "check", P.team)
	var on_it := QuestTracker.seat_of(m, P.team) == qs.uplink
	ok(on_it and is_equal_approx(QuestTracker.progress(m, qs.uplink), 0.4),
		"your squad charging the Uplink: the tracker is the Uplink and reads its charge")
	var far := "%d m" % roundi(P.flat_dist(x["pos"]))
	var nums := QuestTracker.numbers(m, qs.uplink, QuestTracker.rival_seat(m, P.team))
	ok(QuestTracker.rival_seat(m, P.team) == null and nums == "40%  ·  " + far,
		"no rival on a quest seat: no rival bar; the numbers are your charge and the distance (%s)" % nums)
	r = await _tracker_rect(main, m)
	var strip: Rect2 = SafeArea.seen.get("ways_strip", [Rect2()])[0]
	ok(r.has_area() and r.position.y >= strip.end.y and r.end.y <= m.hud.msgs.top,
		"drawn under the strip (%s) and above the message lane (y %d): %s" % [strip, int(m.hud.msgs.top), r])
	b.hp = b.max_hp * 0.7
	qs.lair._force(QuestSeat.S.IN_USE, "check", foe.team)
	nums = QuestTracker.numbers(m, qs.uplink, QuestTracker.rival_seat(m, P.team))
	ok(QuestTracker.rival_seat(m, P.team) == qs.lair and nums == "40%  ·  rival 30%  ·  " + far,
		"a rival sealed in the Sealed Lair: the rival bar is the boss's health taken off (%s)" % nums)
	qs.uplink._force(QuestSeat.S.IN_USE, "check", foe.team)
	r = await _tracker_rect(main, m)
	ok(QuestTracker.seat_of(m, P.team) == null and not r.has_area(), "a rival took the Uplink: no tracker")
	qs.lair._force(QuestSeat.S.IN_USE, "check", P.team)
	r = await _tracker_rect(main, m)
	var boss_k := QuestTracker.progress(m, qs.lair)
	var lair_on := QuestTracker.seat_of(m, P.team) == qs.lair and is_equal_approx(boss_k, 0.3)
	ok(lair_on and r.has_area(), "your squad sealed in the Sealed Lair, you outside: the tracker reads the boss, 30%")
	b.dormant = false
	P.teleport(qs.lair.site())
	r = await _tracker_rect(main, m)
	ok(m.lairs.boss_for(P) == b and not r.has_area(), "inside the fight the boss bar is the objective: no tracker")
	b.dormant = true
	P.teleport(away)
	P.out = true
	r = await _tracker_rect(main, m)
	ok(not r.has_area(), "you are out: no tracker")
	P.out = false
	qs.lair._force(QuestSeat.S.TAKEN, "check", P.team)
	r = await _tracker_rect(main, m)
	ok(QuestTracker.seat_of(m, P.team) == null and not r.has_area(), "the quest finished (taken): no tracker")

## The tracker's rect on the HUD this frame (no area when it is not drawn). SafeArea records the panel pass.
func _tracker_rect(main: Node, m: Match) -> Rect2:
	SafeArea.seen.clear()
	SafeArea.recording = true
	m.hud.panels.queue_redraw()
	for i in 3:
		await main.get_tree().process_frame
	SafeArea.recording = false
	var got: Array = SafeArea.seen.get("quest_tracker", [])
	return got[0] if not got.is_empty() else Rect2()
