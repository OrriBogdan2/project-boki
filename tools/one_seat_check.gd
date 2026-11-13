extends RefCounted
## Part of --extract-check (main.gd _extract_check, section 3e): a squad uses one seat (OneSeat, docs/decisions/0051).
## A seat takes only the members standing in it; each other member gets Heart.r("late_s") to reach it, then
## goes home without their loot; and a squad that used a seat can start no other. Never touches the save.

var ok := true


func say(cond: bool, what: String) -> void:
	print("EXCHECK %s one seat: %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		ok = false


## Squad of three: P and one mate at the Heart Gate, the third far away with some loot. The Gate fires.
func _gate_taken(m: Match) -> Hunter:
	var P: Hunter = m.player
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	var far: Hunter = mates[1]
	P.teleport(m.heart.gate + Vector3(1.0, 0, 0))
	mates[0].teleport(m.heart.gate + Vector3(-1.0, 0, 0))
	far.teleport(_far_ground(m))
	far.gems = 30
	far.seeds = {"sunroot": 2}
	m.heart._take(Heart.HOW_EARLY, P.team)
	return far


## A spot on solid ground 40 m from the Gate (the island's edge moves with the map; the void would kill them).
func _far_ground(m: Match) -> Vector3:
	for d in [Vector3(0, 0, 40.0), Vector3(0, 0, -40.0), Vector3(40.0, 0, 0), Vector3(-40.0, 0, 0)]:
		var q: Vector3 = m.heart.gate + d
		if m.world.ground_at(q.x, q.z) > World.VOID:
			return q
	return m.heart.gate + Vector3(0, 0, 40.0)


## fresh(squad) -> Match, run(m, sec, every), done(m): the extract check's own helpers.
func check(main: Node, fresh: Callable, run: Callable, done: Callable) -> bool:
	var late_s := Heart.r("late_s")
	say(late_s == 20.0, "content/rules/heart.json late_s is %.0f s" % late_s)
	var m: Match = fresh.call(3)
	var P: Hunter = m.player
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var far := _gate_taken(m)
	var O: OneSeat = m.exits.one_seat
	say(P.extracted and mate.extracted and not far.extracted, "the Gate takes the two at it, not the third 40 m away")
	say(O.late.has(far) and not O.late.has(P) and O.spent(far), "the one left behind is on the clock, the squad spent")
	# no second seat: the spark is theirs to take no more, and neither is an uplink
	m.heart._force(Heart.S.READY, "check")
	m.heart.carrier = null
	m.heart.spark_pos = far.pos
	far.inp["interact"] = true
	say(m.heart.interact_for(far).is_empty(), "next to a charged Heartspark, the one left behind is offered nothing")
	m.heart._pick(far)
	say(m.heart.carrier == null, "and the Heartspark does not take them as its carrier")
	far.inp["interact"] = false
	var x: Dictionary = m.exits.uplink_x()
	m.time = m.exits.seats.uplink.open_s - m.sess_t0 + 1.0
	far.teleport(x["pos"] + Vector3(0.6, 0, 0.6))
	m.exits.act(x, "start", far)
	say(
		String(x["state"]) == "idle" and String(m.exits.interact_for(far).get("label", "")).contains("already used"),
		"nor can they start the Uplink: '%s'" % m.exits.interact_for(far).get("label", "")
	)
	done.call(m)
	await main.get_tree().process_frame
	# they run for it: in the Gate before the time is up, they leave by it with the seat's reward
	m = fresh.call(3)
	far = _gate_taken(m)
	run.call(m, late_s - 3.0)
	say(not far.out and m.exits.one_seat.late.has(far), "%.0f s in, still on the clock" % (late_s - 3.0))
	far.teleport(m.heart.gate + Vector3(0, 0, 2.0))
	run.call(m, 0.2)
	say(far.extracted and far.gems >= 30, "inside the Gate in time, they leave by it with their loot")
	done.call(m)
	await main.get_tree().process_frame
	# they do not: home without the loot, out of the squad's fight, the Boki not lost
	m = fresh.call(3)
	far = _gate_taken(m)
	run.call(m, late_s - 1.0)
	say(not far.out, "%.0f s in, one second left" % (late_s - 1.0))
	run.call(m, 2.0)
	var sent: bool = far.out and far.gone and not far.extracted and not m.exits.one_seat.late.has(far)
	say(sent and far.gems == 0 and far.seeds.is_empty(), "time up: sent home with no gems or seeds")
	say(m.player_lost.is_empty(), "their Boki is not on the lost list")
	done.call(m)
	await main.get_tree().process_frame
	# the Uplink: its lift stays open for the late member
	m = fresh.call(3)
	P = m.player
	mate = m.hunters.filter(func(h): return h.team == P.team and h != P)[0]
	far = m.hunters.filter(func(h): return h.team == P.team and h != P and h != mate)[0]
	x = m.exits.uplink_x()
	m.time = m.exits.seats.uplink.open_s - m.sess_t0 + 1.0
	P.teleport(x["pos"] + Vector3(0.6, 0, 0.6))
	run.call(m, 2.0, func(): P.inp["interact"] = true)
	P.inp["interact"] = false
	far.teleport(x["pos"] + Vector3(30.0, 0, 0))
	m.exits._open_lift(x)
	P.teleport(x["pos"])
	run.call(m, 0.5)
	say(P.extracted and m.exits.one_seat.late.has(far), "P rides the Uplink; the third is on the clock")
	run.call(m, late_s - 3.0)
	say(String(x["state"]) == "open", "the lift is still open %.0f s later, not %.0f" % [late_s - 2.5, Exits.LIFT_T])
	far.teleport(x["pos"])
	run.call(m, 0.3)
	say(far.extracted and m.exits.seats.uplink.refused == 0, "they step in and ride it out")
	done.call(m)
	await main.get_tree().process_frame
	# the Sealed Lair: the winners fly out, the third gets the same clock and leaves by the lair's updraft in time
	m = fresh.call(3)
	P = m.player
	var lair_mates: Array = m.hunters.filter(func(h): return h.team == P.team and h != P)
	far = lair_mates[1]
	run.call(m, 0.1)
	var K: QuestSeat = m.exits.seats.lair
	say(K != null, "the match has a Sealed Lair seat (%d lairs)" % m.lairs.list.size())
	if K == null:
		done.call(m)
		return ok
	var L: Dictionary = K.ref
	K.state = QuestSeat.S.TAKEN
	K.team = P.team
	K.out = true
	P.teleport(L["up"])
	lair_mates[0].teleport(L["up"])
	far.teleport(L["up"] + Vector3(40.0, 0, 0))
	m.exits.seats._apply(K)
	say(
		P.extracted and lair_mates[0].extracted and not far.extracted and m.exits.one_seat.late.has(far),
		"the Lair takes the two in it; the third is on the clock"
	)
	far.teleport(L["up"])
	run.call(m, 0.3)
	var used := String(m.exits.one_seat.used.get(P.team, ""))
	say(far.extracted and used == QuestSeats.HOW_LAIR, "they reach the updraft in time and leave by it")
	done.call(m)
	await main.get_tree().process_frame
	return ok
