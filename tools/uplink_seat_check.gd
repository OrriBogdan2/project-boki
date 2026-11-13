extends RefCounted
## Part of --extract-check (main.gd _extract_check, section 3d): the Uplink quest seat of Limited Ways
## Out (QuestSeats, docs/decisions/0051). One outpost by the seed, the others dark; LOCKED before 6:00,
## OPEN, IN_USE while a squad charges it, TAKEN when its lift opens: that squad's lift alone, one use,
## then closed. A charge still running at 8:00 is SHUT and the outpost goes dark. Never touches the save.

var ok := true

func say(cond: bool, what: String) -> void:
	print("EXCHECK %s uplink seat: %s" % ["ok  " if cond else "FAIL", what])
	if not cond: ok = false

## fresh(squad) -> Match, run(m, sec, every), done(m): the extract check's own helpers.
func check(main: Node, fresh: Callable, run: Callable, done: Callable) -> bool:
	var m: Match = fresh.call(2)
	var P: Hunter = m.player
	var R: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	var S: QuestSeats = m.exits.seats
	say(S != null, "the mode's exits have the quest seats")
	if S == null:
		done.call(m)
		return false
	var x: Dictionary = m.exits.uplink_x()
	var U: QuestSeat = S.uplink
	var outs: Array = m.exits.of_kind("outpost")
	var S2 := QuestSeats.new(m)
	S2.build()
	var dark := outs.filter(func(o): return o.get("dark", false)).size()
	say(U != null and is_same(S2.uplink.ref, x) and dark == outs.size() - 1,
		"the seed picks %s (again the same), the other %d outpost(s) dark" % [x.get("name", "-"), dark])
	# before 6:00: locked, nobody can start it
	m.time = 30.0
	P.teleport(x["pos"] + Vector3(0.6, 0, 0.6))
	run.call(m, 2.0, func(): P.inp["interact"] = true)
	P.inp["interact"] = false
	say(U.state == QuestSeat.S.LOCKED and String(x["state"]) == "idle" and not m.exits.startable(x),
		"at %.0fs it's LOCKED and won't start" % m.sess_time())
	for d in outs:
		if d.get("dark", false):
			P.teleport(d["pos"] + Vector3(0.6, 0, 0.6))
			run.call(m, 0.1)
			var lab := String(m.exits.interact_for(P).get("label", ""))
			say(not m.exits.startable(d) and lab.contains("dark"), "a dark outpost can't be started: '%s'" % lab)
			break
	# 6:00: open; P's squad starts it
	m.time = U.open_s - m.sess_t0 + 1.0
	run.call(m, 0.2)
	say(U.state == QuestSeat.S.OPEN and m.exits.startable(x), "at 6:01 it's OPEN")
	P.teleport(x["pos"] + Vector3(0.6, 0, 0.6))
	run.call(m, 2.0, func(): P.inp["interact"] = true)
	P.inp["interact"] = false
	say(U.state == QuestSeat.S.IN_USE and U.team == P.team and String(x["state"]) == "charging",
		"P starts it: IN_USE by team %d" % U.team)
	# the charge done: TAKEN; the lift is P's squad's alone
	m.exits._open_lift(x)
	P.teleport(x["pos"] + Vector3(8.0, 0, 0))
	R.teleport(x["pos"])
	run.call(m, 0.5, func(): R.teleport(x["pos"]))
	say(U.state == QuestSeat.S.TAKEN and U.team == P.team and not R.extracted,
		"the lift opens: TAKEN by team %d, the rival on the light doesn't ride" % U.team)
	P.teleport(x["pos"])
	run.call(m, 0.3)
	say(P.extracted and m.result.get("how", "") == "uplink", "P rides it out (how=%s)" % m.result.get("how", ""))
	var lift_t := float(x.get("t", 0.0)) + 0.5      # (the exits alone: with P out the match may be over)
	while lift_t > 0.0:
		m.exits.tick(Match.DT)
		lift_t -= Match.DT
	say(String(x["state"]) == "closed" and not m.exits.startable(x) and not R.extracted,
		"then it's closed for good (%s), the rival still here" % x["state"])
	say(U.refused == 0, "trail %s" % str(U.trail))
	done.call(m)
	await main.get_tree().process_frame
	# a charge still running at 8:00: SHUT, the outpost dark
	m = fresh.call(2)
	P = m.player
	x = m.exits.uplink_x()
	U = m.exits.seats.uplink
	m.time = U.open_s - m.sess_t0 + 1.0
	P.teleport(x["pos"] + Vector3(0.6, 0, 0.6))
	run.call(m, 2.0, func(): P.inp["interact"] = true)
	P.inp["interact"] = false
	m.time = U.shut_s - m.sess_t0 + 0.1
	run.call(m, 0.3)
	var dark_now: bool = String(x["state"]) == "closed" and not m.exits.startable(x)
	say(U.state == QuestSeat.S.SHUT and dark_now and not P.extracted and U.refused == 0,
		"still charging at 8:00: SHUT, the outpost %s; trail %s" % [x["state"], str(U.trail)])
	done.call(m)
	await main.get_tree().process_frame
	return ok
